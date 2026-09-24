/// One block of recognized text in reading order (relevant for OCR, where an
/// image may contain multiple text regions).
class TextSegment {
  const TextSegment({required this.text, required this.order});

  final String text;
  final int order;
}

/// The result of converting audio or an image into text. This model must be
/// honest about capability: a stub/unavailable adapter returns
/// [TextExtraction.stub] with `isStub: true` and a human-readable warning —
/// it must never fabricate text and present it as a real transcription or
/// OCR result.
class TextExtraction {
  const TextExtraction({
    required this.originalText,
    required this.language,
    required this.segments,
    required this.warnings,
    required this.isStub,
  });

  factory TextExtraction.stub(String warning) => TextExtraction(
        originalText: '',
        language: 'ar',
        segments: const [],
        warnings: [warning],
        isStub: true,
      );

  final String originalText;
  final String language;
  final List<TextSegment> segments;

  /// Honesty channel: capability warnings such as "stub: Arabic STT is not
  /// integrated in this milestone", low-confidence notices, or truncation
  /// notes. Always surfaced in the review UI, never hidden.
  final List<String> warnings;

  /// True when this extraction did not come from a working recognizer and
  /// [originalText] is a placeholder (empty by convention). The review
  /// screen must render a visible stub banner whenever this is true.
  final bool isStub;
}
