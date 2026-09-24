import '../contracts/image_text_extractor.dart';
import '../models/text_extraction.dart';

/// Development stub. No on-device Arabic OCR engine is wired up in this
/// milestone. Google ML Kit Text Recognition v2 must not be assumed to
/// support Arabic, and a Tesseract-based candidate needs evaluation on real
/// printed Arabic before it can replace this stub (see
/// README_AI_INTAKE.md, "On-device processing"). The picked/captured image
/// itself is real; only OCR is not implemented yet.
class StubImageTextExtractor implements ImageTextExtractor {
  @override
  bool get isAvailable => false;

  @override
  Future<TextExtraction> extract(
    String imagePath, {
    void Function(double? progress)? onProgress,
  }) async {
    onProgress?.call(null);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return TextExtraction.stub(
      'لم يتم دمج التعرف الضوئي على الحروف العربية (OCR) في هذه المرحلة بعد. '
      'يمكنك كتابة النص يدويًا للمتابعة ومعاينة باقي الخطوات.',
    );
  }
}
