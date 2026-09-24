import '../models/text_extraction.dart';

/// Runs Arabic OCR on a captured/selected image. Same honesty contract as
/// [SpeechTranscriber]: `isAvailable == false` must yield a
/// [TextExtraction.stub], never fabricated text presented as recognized.
abstract class ImageTextExtractor {
  bool get isAvailable;

  Future<TextExtraction> extract(
    String imagePath, {
    void Function(double? progress)? onProgress,
  });
}
