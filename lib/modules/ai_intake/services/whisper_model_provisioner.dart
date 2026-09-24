import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../contracts/speech_model_provisioner.dart';
import '../models/model_setup_progress.dart';
import 'whisper_model_spec.dart';

enum _FileOutcome { ok, offline, insufficientStorage, failed, cancelled }

/// Downloads, verifies, and installs the on-device Whisper model described
/// by [WhisperModelSpec] the first time it's needed, then reuses it on every
/// later launch. No developer/manual step is required — this is exactly
/// what makes a fresh install able to transcribe Arabic speech on its own.
///
/// Design points that matter for reliability:
///  - Each file is downloaded to a `.part` sibling and only renamed into
///    place after its SHA-256 matches the pinned value in [WhisperModelSpec]
///    — a corrupt or truncated download can never be mistaken for a good one.
///  - An interrupted download resumes from the `.part` file's current length
///    via an HTTP `Range` request; if the server doesn't honor the range, the
///    partial file is discarded and that one file restarts cleanly (the
///    other, already-verified files are left alone).
///  - Readiness after the first successful install is a single manifest
///    read plus a cheap file-size check — no network call, no re-hashing —
///    so normal launches pay no cost.
///  - A `FileSystemException` that looks like "out of space" is reported as
///    [ModelSetupStatus.insufficientStorage] rather than a generic failure.
class WhisperModelProvisioner implements SpeechModelProvisioner {
  WhisperModelProvisioner({
    http.Client? httpClient,
    Directory? modelDirectoryOverride,
    List<WhisperModelFile>? filesOverride,
  })  : _client = httpClient ?? http.Client(),
        _modelDirectoryOverride = modelDirectoryOverride,
        _files = filesOverride ?? WhisperModelSpec.files;

  final http.Client _client;
  final Directory? _modelDirectoryOverride;

  /// Real production code always uses `WhisperModelSpec.files`. Tests inject
  /// a couple of tiny fake files here so download/resume/integrity/manifest
  /// logic can be verified without moving ~100MB over the network.
  final List<WhisperModelFile> _files;
  int get _totalBytes => _files.fold(0, (sum, f) => sum + f.sizeBytes);

  final StreamController<ModelSetupProgress> _controller = StreamController.broadcast();
  ModelSetupProgress _lastProgress = ModelSetupProgress.notStartedValue;
  bool _cancelRequested = false;
  Future<bool>? _inFlight;

  @override
  ModelSetupProgress get currentProgress => _lastProgress;

  @override
  Stream<ModelSetupProgress> get progressStream => _controller.stream;

  @override
  int get estimatedTotalBytes => _totalBytes;

  @override
  Future<bool> ensureReady() {
    // Coalesce concurrent callers (e.g. a retry tap while a prior call is
    // still unwinding) onto the same attempt instead of racing two
    // downloads into the same directory.
    final existing = _inFlight;
    if (existing != null) return existing;
    final attempt = _runEnsureReady();
    _inFlight = attempt;
    attempt.whenComplete(() => _inFlight = null);
    return attempt;
  }

  Future<bool> _runEnsureReady() async {
    _cancelRequested = false;
    final dir = await WhisperModelSpec.resolveModelDirectory(override: _modelDirectoryOverride);

    if (await _isManifestValid(dir)) {
      _emit(ModelSetupStatus.ready, receivedBytes: _totalBytes);
      return true;
    }

    try {
      await dir.create(recursive: true);
    } on FileSystemException catch (e) {
      _emit(_isOutOfSpace(e) ? ModelSetupStatus.insufficientStorage : ModelSetupStatus.failed);
      return false;
    }

    var bytesBefore = 0;
    for (final spec in _files) {
      _emit(ModelSetupStatus.downloading, receivedBytes: bytesBefore);
      final outcome = await _ensureFile(spec, dir, bytesBefore);
      if (outcome == _FileOutcome.cancelled) return false;
      if (outcome != _FileOutcome.ok) {
        _emit(switch (outcome) {
          _FileOutcome.offline => ModelSetupStatus.offline,
          _FileOutcome.insufficientStorage => ModelSetupStatus.insufficientStorage,
          _ => ModelSetupStatus.failed,
        });
        return false;
      }
      bytesBefore += spec.sizeBytes;
    }

    await _writeManifest(dir);
    _emit(ModelSetupStatus.ready, receivedBytes: _totalBytes);
    return true;
  }

  Future<_FileOutcome> _ensureFile(WhisperModelFile spec, Directory dir, int bytesBefore) async {
    final finalFile = File('${dir.path}/${spec.fileName}');
    final partFile = File('${dir.path}/${spec.fileName}.part');

    if (await finalFile.exists() &&
        await finalFile.length() == spec.sizeBytes &&
        await _matchesHash(finalFile, spec.sha256)) {
      return _FileOutcome.ok;
    }

    var startAt = 0;
    if (await partFile.exists()) {
      startAt = await partFile.length();
      if (startAt > spec.sizeBytes) {
        await partFile.delete();
        startAt = 0;
      }
    }

    final request = http.Request('GET', Uri.parse(spec.downloadUrl));
    if (startAt > 0) request.headers['Range'] = 'bytes=$startAt-';

    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      return _FileOutcome.offline;
    } on SocketException {
      return _FileOutcome.offline;
    } on http.ClientException {
      return _FileOutcome.offline;
    }

    if (response.statusCode != 200 && response.statusCode != 206) {
      return _FileOutcome.failed;
    }

    final resumed = response.statusCode == 206;
    if (!resumed && startAt > 0) {
      // Server ignored our Range header; it's sending the whole file from
      // byte 0, so the existing partial bytes must not be kept.
      startAt = 0;
      if (await partFile.exists()) await partFile.delete();
    }

    IOSink? sink;
    try {
      sink = partFile.openWrite(mode: resumed ? FileMode.append : FileMode.write);
      var received = startAt;
      await for (final chunk in response.stream) {
        if (_cancelRequested) {
          await sink.flush();
          await sink.close();
          return _FileOutcome.cancelled;
        }
        sink.add(chunk);
        received += chunk.length;
        _emit(ModelSetupStatus.downloading, receivedBytes: bytesBefore + received);
      }
      await sink.flush();
      await sink.close();
      sink = null;
    } on FileSystemException catch (e) {
      await sink?.close();
      return _isOutOfSpace(e) ? _FileOutcome.insufficientStorage : _FileOutcome.failed;
    } on SocketException {
      await sink?.close();
      return _FileOutcome.offline;
    } catch (_) {
      await sink?.close();
      return _FileOutcome.failed;
    }

    if (!await partFile.exists() || await partFile.length() != spec.sizeBytes) {
      return _FileOutcome.offline; // connection dropped mid-stream without throwing
    }

    if (!await _matchesHash(partFile, spec.sha256)) {
      await partFile.delete();
      return _FileOutcome.failed;
    }

    await partFile.rename(finalFile.path);
    return _FileOutcome.ok;
  }

  Future<bool> _isManifestValid(Directory dir) async {
    final manifestFile = File('${dir.path}/${WhisperModelSpec.manifestFileName}');
    if (!await manifestFile.exists()) return false;
    try {
      final data = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final recorded = (data['files'] as Map<String, dynamic>?) ?? const {};
      for (final spec in _files) {
        final entry = recorded[spec.fileName] as Map<String, dynamic>?;
        if (entry == null || entry['sha256'] != spec.sha256 || entry['size'] != spec.sizeBytes) {
          return false;
        }
        final file = File('${dir.path}/${spec.fileName}');
        if (!await file.exists() || await file.length() != spec.sizeBytes) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeManifest(Directory dir) async {
    final data = {
      'files': {
        for (final spec in _files) spec.fileName: {'sha256': spec.sha256, 'size': spec.sizeBytes},
      },
    };
    final manifestFile = File('${dir.path}/${WhisperModelSpec.manifestFileName}');
    final tempFile = File('${manifestFile.path}.tmp');
    await tempFile.writeAsString(jsonEncode(data));
    await tempFile.rename(manifestFile.path);
  }

  Future<bool> _matchesHash(File file, String expectedSha256) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == expectedSha256;
  }

  bool _isOutOfSpace(FileSystemException e) {
    final code = e.osError?.errorCode;
    final message = (e.osError?.message ?? e.message).toLowerCase();
    return code == 28 /* ENOSPC */ ||
        code == 112 /* Windows ERROR_DISK_FULL */ ||
        message.contains('no space left') ||
        message.contains('not enough space') ||
        message.contains('disk full');
  }

  void _emit(ModelSetupStatus status, {int receivedBytes = 0}) {
    final progress = ModelSetupProgress(
      status: status,
      receivedBytes: receivedBytes,
      totalBytes: _totalBytes,
    );
    _lastProgress = progress;
    if (!_controller.isClosed) _controller.add(progress);
  }

  @override
  void cancel() => _cancelRequested = true;

  @override
  void dispose() {
    _cancelRequested = true;
    _controller.close();
    _client.close();
  }
}
