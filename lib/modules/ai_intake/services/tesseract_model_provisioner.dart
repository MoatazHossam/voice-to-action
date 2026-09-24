import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../contracts/image_model_provisioner.dart';
import '../models/model_setup_progress.dart';
import 'tesseract_model_spec.dart';
import 'whisper_model_spec.dart' show WhisperModelFile;

enum _FileOutcome { ok, offline, insufficientStorage, failed, cancelled }

/// Downloads, verifies, and installs the on-device Arabic (+ English)
/// Tesseract trained-data files the first time OCR is needed, then reuses
/// them on every later launch. No developer/manual step is required.
///
/// This mirrors `WhisperModelProvisioner`'s design point-for-point (see that
/// class for the full rationale): per-file `.part` staging with SHA-256
/// verification before a rename into place, HTTP-Range resume of an
/// interrupted download, a manifest-gated zero-network fast path on later
/// launches, and offline/insufficient-storage/generic failure
/// classification. The two are intentionally not merged into one shared
/// engine in this milestone — this file exists on its own, at the cost of
/// some duplication, so that touching OCR setup carries zero risk of
/// regressing the already-verified speech setup (see ARCHITECTURE.md).
///
/// Unlike the Whisper case, **the entire attempt is wrapped in a top-level
/// try/catch** that guarantees `ensureReady()` never throws — including a
/// failure while writing the manifest itself. (This was a real bug found in
/// `WhisperModelProvisioner`: an exception at that exact point used to
/// escape uncaught, leaving the UI stuck showing "downloading 100%"
/// forever. Both provisioners now have this fix — see
/// `whisper_model_provisioner.dart` and ARCHITECTURE.md.)
class TesseractModelProvisioner implements ImageModelProvisioner {
  TesseractModelProvisioner({
    http.Client? httpClient,
    Directory? modelDirectoryOverride,
    List<WhisperModelFile>? filesOverride,
  })  : _client = httpClient ?? http.Client(),
        _modelDirectoryOverride = modelDirectoryOverride,
        _files = filesOverride ?? TesseractModelSpec.files;

  final http.Client _client;
  final Directory? _modelDirectoryOverride;

  /// Real production code always uses `TesseractModelSpec.files`. Tests
  /// inject tiny fake files so download/resume/integrity/manifest logic can
  /// be verified without moving real trained-data over the network.
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
    final existing = _inFlight;
    if (existing != null) return existing;
    final attempt = _runEnsureReady();
    _inFlight = attempt;
    attempt.whenComplete(() => _inFlight = null);
    return attempt;
  }

  Future<bool> _runEnsureReady() async {
    _cancelRequested = false;
    try {
      final dir = await TesseractModelSpec.resolveModelDirectory(override: _modelDirectoryOverride);

      if (await _isManifestValid(dir)) {
        _emit(ModelSetupStatus.ready, receivedBytes: _totalBytes);
        return true;
      }

      await dir.create(recursive: true);

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
    } on FileSystemException catch (e) {
      // Covers dir.create() and _writeManifest() failing (e.g. the device
      // ran out of space on the very last write) — this must never escape
      // as an uncaught exception; see class doc.
      _emit(_isOutOfSpace(e) ? ModelSetupStatus.insufficientStorage : ModelSetupStatus.failed);
      return false;
    } catch (_) {
      _emit(ModelSetupStatus.failed);
      return false;
    }
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
      return _FileOutcome.offline;
    }

    if (!await _matchesHash(partFile, spec.sha256)) {
      await partFile.delete();
      return _FileOutcome.failed;
    }

    await partFile.rename(finalFile.path);
    return _FileOutcome.ok;
  }

  Future<bool> _isManifestValid(Directory dir) async {
    final manifestFile = File('${dir.path}/${TesseractModelSpec.manifestFileName}');
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
    final manifestFile = File('${dir.path}/${TesseractModelSpec.manifestFileName}');
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
