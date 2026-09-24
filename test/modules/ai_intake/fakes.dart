import 'package:voice_to_action/modules/ai_intake/contracts/action_detector.dart';
import 'package:voice_to_action/modules/ai_intake/contracts/action_draft_handler.dart';
import 'package:voice_to_action/modules/ai_intake/contracts/arabic_text_reviewer.dart';
import 'package:voice_to_action/modules/ai_intake/contracts/audio_playback.dart';
import 'package:voice_to_action/modules/ai_intake/contracts/audio_recorder.dart';
import 'package:voice_to_action/modules/ai_intake/contracts/image_capture.dart';
import 'package:voice_to_action/modules/ai_intake/contracts/image_text_extractor.dart';
import 'package:voice_to_action/modules/ai_intake/contracts/permission_gate.dart';
import 'package:voice_to_action/modules/ai_intake/contracts/speech_transcriber.dart';
import 'package:voice_to_action/modules/ai_intake/models/action_suggestion.dart';
import 'package:voice_to_action/modules/ai_intake/models/ai_action_draft.dart';
import 'package:voice_to_action/modules/ai_intake/models/ai_intake_input.dart';
import 'package:voice_to_action/modules/ai_intake/models/text_correction.dart';
import 'package:voice_to_action/modules/ai_intake/models/text_extraction.dart';

/// Test doubles for every ai_intake contract. Having these at all is only
/// possible because AiIntakeController depends solely on interfaces (see
/// its class doc) — none of these touch a real platform plugin.
class FakePermissionGate implements PermissionGate {
  bool microphoneGranted = true;
  bool cameraGranted = true;

  @override
  Future<bool> hasMicrophone() async => microphoneGranted;
  @override
  Future<bool> requestMicrophone() async => microphoneGranted;
  @override
  Future<bool> hasCamera() async => cameraGranted;
  @override
  Future<bool> requestCamera() async => cameraGranted;
}

class FakeAudioRecorder implements AudioRecorder {
  bool _isRecording = false;
  String? nextStopPath = '/tmp/fake.m4a';

  @override
  bool get isRecording => _isRecording;
  @override
  Stream<double> get amplitudeStream => const Stream.empty();
  @override
  Stream<Duration> get elapsedStream => const Stream.empty();
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start() async => _isRecording = true;
  @override
  Future<String?> stop() async {
    _isRecording = false;
    return nextStopPath;
  }

  @override
  Future<void> cancel() async => _isRecording = false;
  @override
  void dispose() {}
}

class FakeAudioPlayback implements AudioPlayback {
  bool _isPlaying = false;
  @override
  bool get isPlaying => _isPlaying;
  @override
  Stream<bool> get isPlayingStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Future<Duration?> load(String localPath) async => Duration.zero;
  @override
  Future<void> play() async => _isPlaying = true;
  @override
  Future<void> pause() async => _isPlaying = false;
  @override
  Future<void> stop() async => _isPlaying = false;
  @override
  void dispose() {}
}

class FakeSpeechTranscriber implements SpeechTranscriber {
  TextExtraction? nextResult;
  bool shouldThrow = false;
  bool disposed = false;
  Duration delay = Duration.zero;
  @override
  bool get isAvailable => false;
  @override
  Future<TextExtraction> transcribe(String audioPath, {void Function(double?)? onProgress}) async {
    onProgress?.call(null);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (shouldThrow) throw StateError('fake transcription failure');
    return nextResult ?? TextExtraction.stub('stub: not implemented');
  }

  @override
  void dispose() => disposed = true;
}

class FakeImageTextExtractor implements ImageTextExtractor {
  TextExtraction? nextResult;
  bool disposed = false;
  @override
  void dispose() => disposed = true;
  @override
  bool get isAvailable => false;
  @override
  Future<TextExtraction> extract(String imagePath, {void Function(double?)? onProgress}) async {
    onProgress?.call(null);
    return nextResult ?? TextExtraction.stub('stub: not implemented');
  }
}

class FakeImageCapture implements ImageCapture {
  AiIntakeInput? nextCameraResult;
  AiIntakeInput? nextGalleryResult;
  @override
  Future<AiIntakeInput?> pickFromCamera() async => nextCameraResult;
  @override
  Future<AiIntakeInput?> pickFromGallery() async => nextGalleryResult;
}

/// A no-op reviewer: controller tests exercise state transitions, not
/// correction/detection logic, which are covered by their own unit tests.
class NoOpArabicTextReviewer implements ArabicTextReviewer {
  @override
  List<TextCorrection> suggestCorrections(String text) => const [];
  @override
  String applyAccepted(String baseText, List<TextCorrection> corrections) => baseText;
}

class FakeActionDetector implements ActionDetector {
  List<ActionSuggestion> nextResult = const [];
  @override
  List<ActionSuggestion> detect(String text) => nextResult;
}

class RecordingActionDraftHandler implements ActionDraftHandler {
  final List<AiActionDraft> receivedDrafts = [];
  @override
  void onActionDraft(AiActionDraft draft) => receivedDrafts.add(draft);
}
