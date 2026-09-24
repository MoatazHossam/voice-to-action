import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voice_to_action/modules/ai_intake/models/model_setup_progress.dart';
import 'package:voice_to_action/modules/ai_intake/services/tesseract_model_provisioner.dart';
import 'package:voice_to_action/modules/ai_intake/services/tesseract_model_spec.dart';
import 'package:voice_to_action/modules/ai_intake/services/whisper_model_spec.dart' show WhisperModelFile;

Uint8List _bytesOf(String s) => Uint8List.fromList(utf8.encode(s));
String _hashOf(Uint8List bytes) => sha256.convert(bytes).toString();

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tesseract_provisioner_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  final fileAContent = _bytesOf('A' * 1000);
  final fileBContent = _bytesOf('B' * 500);
  late List<WhisperModelFile> files;

  setUp(() {
    files = [
      WhisperModelFile(
        fileName: 'a.bin',
        sha256: _hashOf(fileAContent),
        sizeBytes: fileAContent.length,
        downloadUrl: 'https://example.invalid/a.bin',
      ),
      WhisperModelFile(
        fileName: 'b.bin',
        sha256: _hashOf(fileBContent),
        sizeBytes: fileBContent.length,
        downloadUrl: 'https://example.invalid/b.bin',
      ),
    ];
  });

  test('downloads, verifies, and installs all files, then reports ready', () async {
    final client = MockClient((request) async {
      final body = request.url.path.endsWith('a.bin') ? fileAContent : fileBContent;
      return http.Response.bytes(body, 200);
    });
    final provisioner = TesseractModelProvisioner(
      httpClient: client,
      modelDirectoryOverride: tempDir,
      filesOverride: files,
    );

    final ready = await provisioner.ensureReady();

    expect(ready, isTrue);
    expect(provisioner.currentProgress.status, ModelSetupStatus.ready);
    expect(File('${tempDir.path}/a.bin').readAsBytesSync(), fileAContent);
    expect(File('${tempDir.path}/b.bin').readAsBytesSync(), fileBContent);
    expect(File('${tempDir.path}/${TesseractModelSpec.manifestFileName}').existsSync(), isTrue);
    provisioner.dispose();
  });

  test('a second call reuses the installed model with no network activity', () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      final body = request.url.path.endsWith('a.bin') ? fileAContent : fileBContent;
      return http.Response.bytes(body, 200);
    });
    final provisioner = TesseractModelProvisioner(
      httpClient: client,
      modelDirectoryOverride: tempDir,
      filesOverride: files,
    );
    expect(await provisioner.ensureReady(), isTrue);
    expect(requestCount, 2);

    final secondProvisioner = TesseractModelProvisioner(
      httpClient: client,
      modelDirectoryOverride: tempDir,
      filesOverride: files,
    );
    expect(await secondProvisioner.ensureReady(), isTrue);
    expect(requestCount, 2, reason: 'a valid manifest must short-circuit before any HTTP call');

    provisioner.dispose();
    secondProvisioner.dispose();
  });

  test('a corrupted response (same length, wrong bytes) fails integrity verification', () async {
    // Same length as fileAContent so this exercises the hash-mismatch path
    // specifically, not the truncated-download/size-mismatch path.
    final wrongButSameLength = Uint8List.fromList(List.filled(fileAContent.length, 0x58));
    final client = MockClient((request) async {
      if (request.url.path.endsWith('a.bin')) {
        return http.Response.bytes(wrongButSameLength, 200);
      }
      return http.Response.bytes(fileBContent, 200);
    });
    final provisioner = TesseractModelProvisioner(
      httpClient: client,
      modelDirectoryOverride: tempDir,
      filesOverride: files,
    );

    final ready = await provisioner.ensureReady();

    expect(ready, isFalse);
    expect(provisioner.currentProgress.status, ModelSetupStatus.failed);
    expect(File('${tempDir.path}/a.bin').existsSync(), isFalse);
    expect(File('${tempDir.path}/${TesseractModelSpec.manifestFileName}').existsSync(), isFalse);
    provisioner.dispose();
  });

  test('retrying after an integrity failure can still succeed once the source is good', () async {
    final wrongButSameLength = Uint8List.fromList(List.filled(fileAContent.length, 0x59));
    var shouldCorrupt = true;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('a.bin')) {
        return http.Response.bytes(shouldCorrupt ? wrongButSameLength : fileAContent, 200);
      }
      return http.Response.bytes(fileBContent, 200);
    });
    final provisioner = TesseractModelProvisioner(
      httpClient: client,
      modelDirectoryOverride: tempDir,
      filesOverride: files,
    );

    expect(await provisioner.ensureReady(), isFalse);
    shouldCorrupt = false;
    expect(await provisioner.ensureReady(), isTrue);
    expect(provisioner.currentProgress.status, ModelSetupStatus.ready);
    provisioner.dispose();
  });

  test('a network failure is reported as offline, not a generic failure', () async {
    final client = MockClient((request) async => throw const SocketException('no route to host'));
    final provisioner = TesseractModelProvisioner(
      httpClient: client,
      modelDirectoryOverride: tempDir,
      filesOverride: files,
    );

    final ready = await provisioner.ensureReady();

    expect(ready, isFalse);
    expect(provisioner.currentProgress.status, ModelSetupStatus.offline);
    provisioner.dispose();
  });

  test('an HTTP error status is a generic failure, not "offline"', () async {
    final client = MockClient((request) async => http.Response('server error', 500));
    final provisioner = TesseractModelProvisioner(
      httpClient: client,
      modelDirectoryOverride: tempDir,
      filesOverride: files,
    );

    final ready = await provisioner.ensureReady();

    expect(ready, isFalse);
    expect(provisioner.currentProgress.status, ModelSetupStatus.failed);
    provisioner.dispose();
  });

  test('an interrupted download resumes from where it left off via a Range request', () async {
    final partial = fileAContent.sublist(0, 400);
    await File('${tempDir.path}/a.bin.part').writeAsBytes(partial);

    String? observedRangeHeader;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('a.bin')) {
        observedRangeHeader = request.headers['Range'];
        final remaining = fileAContent.sublist(400);
        return http.Response.bytes(remaining, 206);
      }
      return http.Response.bytes(fileBContent, 200);
    });
    final provisioner = TesseractModelProvisioner(
      httpClient: client,
      modelDirectoryOverride: tempDir,
      filesOverride: files,
    );

    final ready = await provisioner.ensureReady();

    expect(observedRangeHeader, 'bytes=400-');
    expect(ready, isTrue);
    expect(File('${tempDir.path}/a.bin').readAsBytesSync(), fileAContent);
    provisioner.dispose();
  });

  test('progress reports the known total size immediately and advances as bytes arrive', () async {
    final client = MockClient((request) async {
      final body = request.url.path.endsWith('a.bin') ? fileAContent : fileBContent;
      return http.Response.bytes(body, 200);
    });
    final provisioner = TesseractModelProvisioner(
      httpClient: client,
      modelDirectoryOverride: tempDir,
      filesOverride: files,
    );
    expect(provisioner.estimatedTotalBytes, fileAContent.length + fileBContent.length);

    final seenTotals = <int?>{};
    final sub = provisioner.progressStream.listen((p) => seenTotals.add(p.totalBytes));
    await provisioner.ensureReady();
    await sub.cancel();

    expect(seenTotals, {fileAContent.length + fileBContent.length});
    provisioner.dispose();
  });

  test('a failure while writing the manifest is reported, never left stuck mid-setup', () async {
    // Regression test: an exception at the very last step (finalizing the
    // manifest after every file already downloaded and verified) used to
    // escape ensureReady() uncaught, leaving the caller's await unresolved
    // and the UI stuck on "downloading 100%" forever.
    final client = MockClient((request) async {
      final body = request.url.path.endsWith('a.bin') ? fileAContent : fileBContent;
      return http.Response.bytes(body, 200);
    });
    // Force the manifest write to fail: pre-create its temp-file path AS A
    // DIRECTORY, so File.writeAsString() throws FileSystemException.
    await Directory('${tempDir.path}/${TesseractModelSpec.manifestFileName}.tmp').create(recursive: true);

    final provisioner = TesseractModelProvisioner(
      httpClient: client,
      modelDirectoryOverride: tempDir,
      filesOverride: files,
    );

    final ready = await provisioner.ensureReady().timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail('ensureReady() must never hang/never leave its Future unresolved'),
        );

    expect(ready, isFalse);
    expect(provisioner.currentProgress.status, isNot(ModelSetupStatus.downloading),
        reason: 'must reach a terminal status, not stay stuck mid-download');
    expect(provisioner.currentProgress.isTerminalFailure, isTrue);
    provisioner.dispose();
  });
}
