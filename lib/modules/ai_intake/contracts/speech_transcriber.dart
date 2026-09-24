import '../models/text_extraction.dart';

/// Converts a recorded audio file into Arabic text. `isAvailable` must
/// reflect real capability on the current device/build — a POC stub that
/// cannot actually transcribe must report `false` and its `transcribe`
/// result must be a [TextExtraction.stub], never invented text.
abstract class SpeechTranscriber {
  bool get isAvailable;

  /// `onProgress` receives a value in 0.0–1.0, or null when the underlying
  /// engine cannot report a measured percentage (indeterminate progress).
  Future<TextExtraction> transcribe(
    String audioPath, {
    void Function(double? progress)? onProgress,
  });

  /// Releases any loaded native model/session. Safe to call even if nothing
  /// was ever loaded (e.g. the stub implementation, or a real engine whose
  /// model files were never found).
  void dispose();
}
