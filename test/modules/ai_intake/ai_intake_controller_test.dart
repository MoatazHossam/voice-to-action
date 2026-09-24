import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_to_action/modules/ai_intake/ai_intake_controller.dart';
import 'package:voice_to_action/modules/ai_intake/models/action_suggestion.dart';
import 'package:voice_to_action/modules/ai_intake/models/ai_intake_input.dart';
import 'package:voice_to_action/modules/ai_intake/models/ai_intake_step.dart';
import 'package:voice_to_action/modules/ai_intake/models/model_setup_progress.dart';
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
  late FakeSpeechModelProvisioner modelProvisioner;
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
    modelProvisioner = FakeSpeechModelProvisioner(); // ready by default
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
      speechModelProvisioner: modelProvisioner,
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

  group('failure, cancellation, and resource cleanup', () {
    test('a transcription exception moves to failure and clears processing state', () async {
      transcriber.shouldThrow = true;
      controller.enterVoiceFlow();
      await controller.beginRecording();
      await controller.stopRecording();
      await controller.confirmClipProceedToTranscription();

      expect(controller.step.value, AiIntakeStep.failure);
      expect(controller.isProcessing.value, isFalse);
      expect(controller.errorMessage.value, isNotEmpty);
    });

    test('cancelProcessing discards a late transcription result and returns to preview', () async {
      transcriber.delay = const Duration(milliseconds: 50);
      controller.enterVoiceFlow();
      await controller.beginRecording();
      await controller.stopRecording();

      final future = controller.confirmClipProceedToTranscription();
      // Give the future a moment to actually start awaiting inside the fake.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      controller.cancelProcessing();
      expect(controller.step.value, AiIntakeStep.recordingPreview);
      expect(controller.isProcessing.value, isFalse);

      await future; // let the stale transcription complete in the background
      expect(controller.step.value, AiIntakeStep.recordingPreview,
          reason: 'a result that arrives after cancellation must not overwrite state');
      expect(controller.extraction.value, isNull);
    });

    test('starting a new session invalidates a still-pending transcription from the old one', () async {
      transcriber.delay = const Duration(milliseconds: 50);
      controller.enterVoiceFlow();
      await controller.beginRecording();
      await controller.stopRecording();
      final staleFuture = controller.confirmClipProceedToTranscription();

      await Future<void>.delayed(const Duration(milliseconds: 5));
      controller.enterVoiceFlow(); // user backs out and starts over

      await staleFuture;
      expect(controller.step.value, AiIntakeStep.voiceIdle,
          reason: 'the stale result must not push the new session into review');
    });

    test('editing reviewed text after analysis clears suggestions and corrections', () async {
      controller.enterVoiceFlow();
      await controller.beginRecording();
      await controller.stopRecording();
      transcriber.nextResult = const TextExtraction(
        originalText: 'اجتماع غداً',
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
          evidenceText: 'اجتماع غداً',
          extractedFields: {'date': 'غداً'},
          missingRequiredFields: [],
        ),
      ];
      controller.analyzeReviewedText();
      controller.toggleSuggestionSelected('meeting-0');
      expect(controller.suggestions, isNotEmpty);
      expect(controller.selectedSuggestionIds, isNotEmpty);

      controller.updateReviewedText('نص جديد كتبه المستخدم');

      expect(controller.suggestions, isEmpty);
      expect(controller.selectedSuggestionIds, isEmpty);
      expect(controller.corrections, isEmpty);
    });

    test('discarding a recorded clip deletes its temp file', () async {
      final tempFile = await File(
        '${Directory.systemTemp.path}/ai_intake_test_${DateTime.now().microsecondsSinceEpoch}.wav',
      ).create();
      recorder.nextStopPath = tempFile.path;

      controller.enterVoiceFlow();
      await controller.beginRecording();
      await controller.stopRecording();
      expect(tempFile.existsSync(), isTrue);

      await controller.discardClipAndRetry();
      expect(tempFile.existsSync(), isFalse);
    });

    test('onClose disposes every native adapter, including the transcriber and OCR extractor', () {
      controller.onClose();
      expect(transcriber.disposed, isTrue);
      expect(imageTextExtractor.disposed, isTrue);
    });
  });

  group('app-managed speech model setup', () {
    Future<void> recordAClip() async {
      controller.enterVoiceFlow();
      await controller.beginRecording();
      await controller.stopRecording();
    }

    test('a fresh install downloads the model before transcribing, then proceeds to review', () async {
      modelProvisioner = FakeSpeechModelProvisioner(startReady: false);
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
        speechModelProvisioner: modelProvisioner,
      );
      await recordAClip();

      await controller.confirmClipProceedToTranscription();

      expect(modelProvisioner.ensureReadyCallCount, 1);
      expect(controller.step.value, AiIntakeStep.review);
    });

    test('an offline download failure keeps the user on the model-setup screen, not review', () async {
      modelProvisioner = FakeSpeechModelProvisioner(startReady: false)
        ..nextEnsureReadyResult = false
        ..nextEnsureReadyFinalStatus = ModelSetupStatus.offline;
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
        speechModelProvisioner: modelProvisioner,
      );
      await recordAClip();

      await controller.confirmClipProceedToTranscription();

      expect(controller.step.value, AiIntakeStep.preparingModel);
      expect(controller.modelSetup.value.status, ModelSetupStatus.offline);
    });

    test('an insufficient-storage failure is reported distinctly from a generic failure', () async {
      modelProvisioner = FakeSpeechModelProvisioner(startReady: false)
        ..nextEnsureReadyResult = false
        ..nextEnsureReadyFinalStatus = ModelSetupStatus.insufficientStorage;
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
        speechModelProvisioner: modelProvisioner,
      );
      await recordAClip();

      await controller.confirmClipProceedToTranscription();

      expect(controller.step.value, AiIntakeStep.preparingModel);
      expect(controller.modelSetup.value.status, ModelSetupStatus.insufficientStorage);
    });

    test('retrying after a failure calls ensureReady again and can succeed', () async {
      modelProvisioner = FakeSpeechModelProvisioner(startReady: false)
        ..nextEnsureReadyResult = false
        ..nextEnsureReadyFinalStatus = ModelSetupStatus.failed;
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
        speechModelProvisioner: modelProvisioner,
      );
      await recordAClip();
      await controller.confirmClipProceedToTranscription();
      expect(controller.step.value, AiIntakeStep.preparingModel);

      // Fix the simulated condition (e.g. network back) and retry.
      modelProvisioner.nextEnsureReadyResult = true;
      await controller.confirmClipProceedToTranscription();

      expect(modelProvisioner.ensureReadyCallCount, 2);
      expect(controller.step.value, AiIntakeStep.review);
    });

    test('cancelling mid-download returns to the recording preview and discards the stale result', () async {
      modelProvisioner = FakeSpeechModelProvisioner(startReady: false)..delay = const Duration(milliseconds: 50);
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
        speechModelProvisioner: modelProvisioner,
      );
      await recordAClip();

      final future = controller.confirmClipProceedToTranscription();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(controller.step.value, AiIntakeStep.preparingModel);

      controller.cancelProcessing();
      expect(controller.step.value, AiIntakeStep.recordingPreview);
      expect(modelProvisioner.cancelled, isTrue);

      await future;
      expect(controller.step.value, AiIntakeStep.recordingPreview,
          reason: 'a model-ready result that arrives after cancellation must not resurrect the flow');
      expect(controller.extraction.value, isNull);
    });

    test('the provisioner is disposed when the controller closes', () {
      controller.onClose();
      expect(modelProvisioner.disposed, isTrue);
    });
  });
}
