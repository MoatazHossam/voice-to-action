import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'whisper_model_spec.dart' show WhisperModelFile;

/// Single source of truth for the on-device Arabic (+ English) Tesseract
/// trained-data files this app downloads on first use. Shared by
/// `TesseractModelProvisioner` (fetches/verifies/installs) and
/// `TesseractArabicOcrExtractor` (reads once installed).
///
/// Source: a pinned, immutable commit of the official
/// `tesseract-ocr/tessdata_fast` repository (Apache-2.0) — the "fast"
/// (integer, non-LSTM-best) variant, chosen for its much smaller size,
/// appropriate for a phone. Pinning to a commit SHA means the bytes served
/// at each URL cannot change later; the SHA-256 values below are this
/// session's own verification (see ARCHITECTURE.md, "On-device Arabic OCR").
///
/// The installation directory is **not** an arbitrary choice: it must match
/// exactly what `flutter_tesseract_ocr` itself resolves internally
/// (`getApplicationDocumentsDirectory()` + `/tessdata`), so the plugin finds
/// files we place there without ever touching its own bundled-asset
/// fallback path.
abstract final class TesseractModelSpec {
  static const String manifestFileName = '.ocr_model_manifest.json';

  static const String _commitSha = '87416418657359cb625c412a48b6e1d6d41c29bd';
  static const String _baseUrl =
      'https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/$_commitSha';

  static const String arabicFileName = 'ara.traineddata';
  static const String englishFileName = 'eng.traineddata';

  /// Reuses the same file-descriptor shape as the Whisper model spec — both
  /// just need {fileName, sha256, sizeBytes, downloadUrl}.
  static const List<WhisperModelFile> files = [
    WhisperModelFile(
      fileName: arabicFileName,
      sha256: 'e3206d3dc87fd50c24a0fb9f01838615911d25168f4e64415244b67d2bb3e729',
      sizeBytes: 1432056,
      downloadUrl: '$_baseUrl/$arabicFileName',
    ),
    WhisperModelFile(
      fileName: englishFileName,
      sha256: '7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2',
      sizeBytes: 4113088,
      downloadUrl: '$_baseUrl/$englishFileName',
    ),
  ];

  static int get totalBytes => files.fold(0, (sum, f) => sum + f.sizeBytes);

  /// Must match `flutter_tesseract_ocr`'s own hardcoded
  /// `getApplicationDocumentsDirectory()/tessdata` exactly.
  static Future<Directory> resolveModelDirectory({Directory? override}) async {
    if (override != null) return override;
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/tessdata');
  }
}
