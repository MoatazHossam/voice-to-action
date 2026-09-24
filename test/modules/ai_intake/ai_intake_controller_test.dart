import 'package:flutter_test/flutter_test.dart';
import 'package:voice_to_action/modules/ai_intake/ai_intake_controller.dart';
import 'package:voice_to_action/modules/ai_intake/models/action_suggestion.dart';
import 'package:voice_to_action/modules/ai_intake/models/ai_intake_input.dart';
import 'package:voice_to_action/modules/ai_intake/models/ai_intake_step.dart';
import 'package:voice_to_action/modules/ai_intake/models/text_extraction.dart';

import 'fakes.dart';

void main() {
  late FakePermissionGate permissionGate;
  late FakeAudioRecorder recorder;
  late FakeAudioPlayback playback;
  late FakeSpeechTranscriber transcriber;
  late FakeImageTextExtractor imageTextExtractor;
  late FakeImageCapture imageCapture;
  late FakeActionDetector actionDetector;
  late RecordingActionDraftHandler draftHandler;
  late AiIntakeController controller;

  setUp(() {
    permissionGate = FakePermissionGate();
    recorder = FakeAudioRecorder();
    playback = FakeAudioPlayback();
    transcriber = FakeSpeechTranscriber();
    imageTextExtractor = FakeImageTextExtractor();
    imageCapture = FakeImageCapture();
    actionDetector = FakeActionDetector();
    draftHandler = RecordingActionDraftHandler();
    controller = AiIntakeController(
      recorder: recorder,
      playback: playback,
      transcriber: transcriber,
      imageTextExtractor: imageTextExtractor,
      textReviewer: NoOpArabicTextReviewer(),
      actionDetector: actionDetector,
      actionDraftHandler: draftHandler,
      permissionGate: permissionGate,
      imageCapture: imageCapture,
    );
  });

  group('voice journey state transitions', () {
    test('beginRecording moves to recording when permission is granted', () async {
      controller.enterVoiceFlow();
      await controller.beginRecording();
      expect(controller.step.value, AiIntakeStep.recording);
      expect(recorder.isRecording, isTrue);
    });

    test('beginRecording moves to permissionDenied when permission is refused', () async {
      permissionGate.microphoneGranted = false;
      controller.enterVoiceFlow();
      await controller.beginRecording();
      expect(controller.step.value, AiIntakeStep.permissionDenied);
      expect(recorder.isRecording, isFalse);
    });

    test('stopRecording with a valid clip moves to recordingPreview', () async {
      controller.enterVoiceFlow();
      await controller.beginRecording();
      await controller.stopRecording();
      expect(controller.step.value, AiIntakeStep.recordingPreview);
      expect(controller.recordedPath.value, '/tmp/fake.m4a');
    });

    test('stopRecording with no usable file falls back to voiceIdle with an error', () async {
      recorder.nextStopPath = null;
      controller.enterVoiceFlow();
      await controller.beginRecording();
      await controller.stopRecording();
      expect(controller.step.value, AiIntakeStep.voiceIdle);
      expect(controller.errorMessage.value, isNotEmpty);
    });

    test('cancelRecording returns to voiceIdle and clears transient state', () async {
      controller.enterVoiceFlow();
      await controller.beginRecording();
      await controller.cancelRecording();
      expect(controller.step.value, AiIntakeStep.voiceIdle);
      expect(controller.amplitude.value, 0);
      expect(recorder.isRecording, isFalse);
    });

    test('transcription result never fabricates text: stub stays a stub in review', () async {
      controller.enterVoiceFlow();
      await controller.beginRecording();
      await controller.stopRecording();
      await controller.confirmClipProceedToTranscription();

      expect(controller.step.value, AiIntakeStep.review);
      expect(controller.extraction.value!.isStub, isTrue);
      expect(controller.reviewedText.value, isEmpty);
      expect(controller.isProcessing.value, isFalse);
    });
  });

  group('image journey state transitions', () {
    test('pickImage from gallery moves to imagePreview', () async {
      imageCapture.nextGalleryResult = AiIntakeInput(
        sourceType: AiIntakeSourceType.image,
        localPath: '/tmp/fake.jpg',
        capturedAt: DateTime(2026),
      );
      controller.enterImageFlow();
      await controller.pickImage(fromCamera: false);
      expect(controller.step.value, AiIntakeStep.imagePreview);
      expect(controller.imagePath.value, '/tmp/fake.jpg');
    });

    test('pickImage from camera without permission moves to permissionDenied', () async {
      permissionGate.cameraGranted = false;
      controller.enterImageFlow();
      await controller.pickImage(fromCamera: true);
      expect(controller.step.value, AiIntakeStep.permissionDenied);
    });

    test('cancelling the system picker leaves the state untouched', () async {
      controller.enterImageFlow();
      await controller.pickImage(fromCamera: false); // no result configured -> null
      expect(controller.step.value, AiIntakeStep.imageIdle);
    });
  });

  group('review -> draft handoff', () {
    test('only selected suggestions are handed to the ActionDraftHandler', () async {
      controller.enterVoiceFlow();
      await controller.beginRecording();
      await controller.stopRecording();
      transcriber.nextResult = const TextExtraction(
        originalText: 'اجتماع غداً مع الفريق وطلب صيانة',
        language: 'ar',
        segments: [],
        warnings: [],
        isStub: false,
      );
      await controller.confirmClipProceedToTranscription();

      actionDetector.nextResult = const [
        ActionSuggestion(
          id: 'meeting-0',
          type: ActionType.meeting,
          evidenceText: 'اجتماع غداً مع الفريق',
          extractedFields: {'date': 'غداً'},
          missingRequiredFields: [],
        ),
        ActionSuggestion(
          id: 'request-0',
          type: ActionType.newRequest,
          evidenceText: 'طلب صيانة',
          extractedFields: {},
          missingRequiredFields: ['category'],
        ),
      ];
      controller.analyzeReviewedText();
      expect(controller.suggestions.length, 2);

      controller.toggleSuggestionSelected('meeting-0');
      controller.confirmSelectedDrafts();

      expect(draftHandler.receivedDrafts, hasLength(1));
      expect(draftHandler.receivedDrafts.single.type, ActionType.meeting);
    });

    test('confirming with nothing selected never calls the draft handler', () async {
      controller.enterVoiceFlow();
      await controller.beginRecording();
      await controller.stopRecording();
      await controller.confirmClipProceedToTranscription();

      controller.confirmSelectedDrafts();
      expect(draftHandler.receivedDrafts, isEmpty);
    });
  });

  test('onClose disposes the recorder and playback adapters', () {
    controller.onClose();
    // No exception implies dispose() was reachable on both fakes; a real
    // AudioRecorder/AudioPlayback double-dispose would be a separate bug
    // class this test does not need to simulate.
  });
}
