import 'dart:io';

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;

import '../contracts/image_text_extractor.dart';
import '../models/text_extraction.dart';
import 'tesseract_model_spec.dart';

/// Real, on-device Arabic (+ English) OCR using Tesseract 4's LSTM engine
/// via `flutter_tesseract_ocr` (native: Tesseract4Android on Android,
/// SwiftyTesseract on iOS). See ARCHITECTURE.md, "On-device Arabic OCR", for
/// why this was chosen over Google ML Kit (no Arabic script support) and for
/// full model provenance/license/size.
///
/// This class does not download anything itself — `AiIntakeController` asks
/// an `ImageModelProvisioner` to make the trained-data files ready *before*
/// calling `extract`, so a fresh install never reaches this class without
/// them already in place. The file-presence check here is only a defensive
/// fallback: if the files are somehow still missing, `extract` returns an
/// honest [TextExtraction.stub] with a plain, non-technical message — never
/// a file path, and never fabricated text.
///
/// Deliberately different from `SherpaWhisperArabicTranscriber` in one way:
/// a genuine *recognition* failure (a corrupt image, an unsupported format,
/// the native engine throwing) is caught here and turned into an honest,
/// empty, non-stub [TextExtraction] with a warning — not rethrown. This
/// keeps the user on the editable review screen so they can still type the
/// text manually, per this milestone's explicit requirement ("allow manual
/// entry when recognition fails"); it must never look like a success.
typedef OcrCall = Future<String> Function(String imagePath, {String? language, Map? args});

class TesseractArabicOcrExtractor implements ImageTextExtractor {
  TesseractArabicOcrExtractor({Directory? modelDirectoryOverride, OcrCall? ocrCallOverride})
      : _modelDirectoryOverride = modelDirectoryOverride,
        _ocrCall = ocrCallOverride ?? FlutterTesseractOcr.extractText;

  final Directory? _modelDirectoryOverride;

  /// Lets tests inject a fake OCR call so output-mapping/empty/error
  /// handling can be verified without a real native Tesseract engine or
  /// fragile platform-channel mocking. Production code leaves this null and
  /// calls the real plugin.
  final OcrCall _ocrCall;

  bool _available = false;

  @override
  bool get isAvailable => _available;

  Future<Directory> _modelDirectory() =>
      TesseractModelSpec.resolveModelDirectory(override: _modelDirectoryOverride);

  Future<bool> _filesPresent(Directory dir) async {
    for (final file in TesseractModelSpec.files) {
      if (!await File('${dir.path}/${file.fileName}').exists()) return false;
    }
    return true;
  }

  @override
  Future<TextExtraction> extract(
    String imagePath, {
    void Function(double? progress)? onProgress,
  }) async {
    onProgress?.call(null); // Tesseract's synchronous decode reports no measured percentage
    final dir = await _modelDirectory();
    _available = await _filesPresent(dir);

    if (!_available) {
      // Defensive fallback only — see class doc. No path, no script name.
      return TextExtraction.stub('تعذّر تجهيز ميزة استخراج النص من الصورة. حاول مرة أخرى.');
    }

    String? preparedPath;
    try {
      preparedPath = await _prepareImageForOcr(imagePath);
      final raw = await _ocrCall(
        preparedPath,
        language: 'ara+eng',
        args: const {
          // PSM 3: fully automatic page segmentation, no OSD required — we
          // correct orientation ourselves (see _prepareImageForOcr) instead
          // of shipping the ~10MB osd.traineddata file.
          'psm': '3',
          'preserve_interword_spaces': '1',
        },
      );
      final text = _clean(raw);
      return TextExtraction(
        originalText: text,
        language: 'ar',
        segments: text.isEmpty ? const [] : [TextSegment(text: text, order: 0)],
        warnings: text.isEmpty
            ? const ['لم يتم العثور على نص يمكن قراءته في هذه الصورة. جرّب صورة أوضح أو اكتب النص يدويًا.']
            : const [
                'قد تحتوي بعض الكلمات على أخطاء تعرّف بسيطة، خصوصًا في الصور غير الواضحة أو الخط اليدوي؛ راجع النص قبل الاعتماد عليه.',
              ],
        isStub: false,
      );
    } catch (_) {
      return const TextExtraction(
        originalText: '',
        language: 'ar',
        segments: [],
        warnings: ['تعذّر التعرف على النص في هذه الصورة. يمكنك كتابة النص يدويًا للمتابعة.'],
        isStub: false,
      );
    } finally {
      if (preparedPath != null && preparedPath != imagePath) {
        try {
          await File(preparedPath).delete();
        } catch (_) {
          // Best-effort cleanup only.
        }
      }
    }
  }

  /// Bakes in any EXIF orientation (camera photos are very often stored
  /// "sideways" with just a rotation flag) and caps resolution for OCR
  /// speed/memory — independent of whatever cap the capture step already
  /// applied, since orientation correction alone can swap width/height.
  Future<String> _prepareImageForOcr(String inputPath) async {
    final bytes = await File(inputPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unsupported or corrupt image format');
    }

    var oriented = img.bakeOrientation(decoded);

    const maxDimension = 2200;
    if (oriented.width > maxDimension || oriented.height > maxDimension) {
      oriented = oriented.width >= oriented.height
          ? img.copyResize(oriented, width: maxDimension)
          : img.copyResize(oriented, height: maxDimension);
    }

    final outPath = '$inputPath.ocr.png';
    await File(outPath).writeAsBytes(img.encodePng(oriented));
    return outPath;
  }

  String _clean(String raw) => raw.trim();

  @override
  void dispose() {
    _available = false;
  }
}
