import '../contracts/speech_transcriber.dart';
import '../models/text_extraction.dart';

/// Development stub. No on-device Arabic speech-to-text engine is wired up
/// in this milestone — this class must never return invented text. The
/// recorded clip is real (see `DeviceAudioRecorder`); only the conversion
/// to text is not implemented yet.
///
/// Next milestone: evaluate a small multilingual local Whisper build against
/// Egyptian/Gulf/mixed Arabic samples on target phones (see
/// README_AI_INTAKE.md, "On-device processing").
class StubSpeechTranscriber implements SpeechTranscriber {
  @override
  bool get isAvailable => false;

  @override
  Future<TextExtraction> transcribe(
    String audioPath, {
    void Function(double? progress)? onProgress,
  }) async {
    onProgress?.call(null); // indeterminate: no real engine is running
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return TextExtraction.stub(
      'لم يتم دمج تحويل الصوت إلى نص عربي في هذه المرحلة بعد. '
      'يمكنك كتابة النص يدويًا للمتابعة ومعاينة باقي الخطوات.',
    );
  }
}
