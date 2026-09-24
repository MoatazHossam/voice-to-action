import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One file the on-device Whisper model needs, with everything required to
/// fetch and verify it without trusting the network response's own claims.
class WhisperModelFile {
  const WhisperModelFile({
    required this.fileName,
    required this.sha256,
    required this.sizeBytes,
    required this.downloadUrl,
  });

  final String fileName;
  final String sha256;
  final int sizeBytes;
  final String downloadUrl;
}

/// Single source of truth for the multilingual Arabic-capable Whisper
/// (tiny) model this app downloads on first use. Shared by
/// `WhisperModelProvisioner` (fetches/verifies/installs the files) and
/// `SherpaWhisperArabicTranscriber` (reads them once installed) so the two
/// can never disagree on where the model lives or what it's made of.
///
/// Source: a pinned, immutable commit of the sherpa-onnx project's own
/// Hugging Face mirror of its GitHub-released "sherpa-onnx-whisper-tiny"
/// asset (Apache-2.0 runtime, MIT-licensed Whisper weights). Pinning to a
/// commit SHA — rather than a mutable branch — means the bytes served at
/// this URL cannot change later; the SHA-256 below is this session's own
/// verification that those bytes match the canonical GitHub release
/// (see ARCHITECTURE.md, "On-device Arabic speech-to-text").
abstract final class WhisperModelSpec {
  static const String modelDirName = 'ai_intake_whisper_tiny_ar';
  static const String manifestFileName = '.model_manifest.json';

  static const String _commitSha = '65176e2deb88badc814a94058666cadccc29b61c';
  static const String _baseUrl =
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/$_commitSha';

  static const String encoderFileName = 'tiny-encoder.int8.onnx';
  static const String decoderFileName = 'tiny-decoder.int8.onnx';
  static const String tokensFileName = 'tiny-tokens.txt';

  static const List<WhisperModelFile> files = [
    WhisperModelFile(
      fileName: encoderFileName,
      sha256: 'd24fb083ae3b1041fc24e97971d60e280c9342201fbb67b0ab428a8b4a51a434',
      sizeBytes: 12937772,
      downloadUrl: '$_baseUrl/$encoderFileName',
    ),
    WhisperModelFile(
      fileName: decoderFileName,
      sha256: 'd2fece8dd42771f1df975c6c0445770d0c292bf7547c2cae04a6c0cc57540925',
      sizeBytes: 89855401,
      downloadUrl: '$_baseUrl/$decoderFileName',
    ),
    WhisperModelFile(
      fileName: tokensFileName,
      sha256: 'b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126',
      sizeBytes: 816730,
      downloadUrl: '$_baseUrl/$tokensFileName',
    ),
  ];

  static int get totalBytes => files.fold(0, (sum, f) => sum + f.sizeBytes);

  static Future<Directory> resolveModelDirectory({Directory? override}) async {
    if (override != null) return override;
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/$modelDirName');
  }
}
