import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';

import 'contracts/action_detector.dart';
import 'contracts/action_draft_handler.dart';
import 'contracts/arabic_text_reviewer.dart';
import 'contracts/audio_playback.dart';
import 'contracts/audio_recorder.dart';
import 'contracts/image_capture.dart';
import 'contracts/image_text_extractor.dart';
import 'contracts/permission_gate.dart';
import 'contracts/speech_transcriber.dart';
import 'models/action_suggestion.dart';
import 'models/ai_action_draft.dart';
import 'models/ai_intake_input.dart';
import 'models/ai_intake_step.dart';
import 'models/text_correction.dart';
import 'models/text_extraction.dart';

/// Owns all state and transitions for one ai_intake session. Only depends on
/// contracts (interfaces) — never on a concrete recorder/transcriber/OCR/
/// reviewer/detector/permission/capture implementation, and never on
/// anything outside this module. This is what makes state transitions unit-
/// testable with fakes instead of real platform plugins.
class AiIntakeController extends GetxController {
  AiIntakeController({
    required AudioRecorder recorder,
    required AudioPlayback playback,
    required SpeechTranscriber transcriber,
    required ImageTextExtractor imageTextExtractor,
    required ArabicTextReviewer textReviewer,
    required ActionDetector actionDetector,
    required ActionDraftHandler actionDraftHandler,
    required PermissionGate permissionGate,
    required ImageCapture imageCapture,
  })  : _recorder = recorder,
        _playback = playback,
        _transcriber = transcriber,
        _imageTextExtractor = imageTextExtractor,
        _textReviewer = textReviewer,
        _actionDetector = actionDetector,
        _actionDraftHandler = actionDraftHandler,
        _permissionGate = permissionGate,
        _imageCapture = imageCapture;

  final AudioRecorder _recorder;
  final AudioPlayback _playback;
  final SpeechTranscriber _transcriber;
  final ImageTextExtractor _imageTextExtractor;
  final ArabicTextReviewer _textReviewer;
  final ActionDetector _actionDetector;
  final ActionDraftHandler _actionDraftHandler;
  final PermissionGate _permissionGate;
  final ImageCapture _imageCapture;

  StreamSubscription<double>? _amplitudeSub;
  StreamSubscription<Duration>? _elapsedSub;
  AiIntakeInput? _capturedInput;
  String? _lastExtractionBaseText;

  /// Bumped whenever a session is reset or in-flight processing is
  /// cancelled, so a transcribe/OCR future that finishes late (after the
  /// user left the screen or started a new recording) can detect it is
  /// stale and must not mutate state.
  int _generation = 0;

  /// The source type of whatever is currently under review, so the shared
  /// review screen can show source-correct wording (recording vs. image).
  /// Not an Rx field on purpose: it only ever changes alongside `extraction`,
  /// which is what UI code should already be observing.
  AiIntakeSourceType? get lastSourceType => _capturedInput?.sourceType;

  final Rx<AiIntakeStep> step = AiIntakeStep.voiceIdle.obs;
  final RxString errorMessage = ''.obs;

  // Recording state
  final RxDouble amplitude = 0.0.obs;
  final Rx<Duration> elapsed = Duration.zero.obs;
  final RxnString recordedPath = RxnString();
  final RxBool isPlayingClip = false.obs;

  // Image state
  final RxnString imagePath = RxnString();

  // Shared processing/review state
  final RxBool isProcessing = false.obs;
  final RxnDouble processingProgress = RxnDouble(); // null == indeterminate
  final Rx<TextExtraction?> extraction = Rx<TextExtraction?>(null);
  final RxString reviewedText = ''.obs;
  final RxList<TextCorrection> corrections = <TextCorrection>[].obs;
  final RxList<ActionSuggestion> suggestions = <ActionSuggestion>[].obs;
  final RxSet<String> selectedSuggestionIds = <String>{}.obs;

  bool get canAnalyze => reviewedText.value.trim().isNotEmpty;

  // ---- Entry points -------------------------------------------------

  void enterVoiceFlow() {
    _resetSession();
    step.value = AiIntakeStep.voiceIdle;
  }

  void enterImageFlow() {
    _resetSession();
    step.value = AiIntakeStep.imageIdle;
  }

  // ---- Voice journey --------------------------------------------------

  Future<void> beginRecording() async {
    errorMessage.value = '';
    final granted = _recorder.isRecording ? true : await _permissionGate.requestMicrophone();
    if (!granted) {
      step.value = AiIntakeStep.permissionDenied;
      return;
    }
    try {
      await _recorder.start();
      _amplitudeSub?.cancel();
      _amplitudeSub = _recorder.amplitudeStream.listen((v) => amplitude.value = v);
      _elapsedSub?.cancel();
      _elapsedSub = _recorder.elapsedStream.listen((d) => elapsed.value = d);
      step.value = AiIntakeStep.recording;
    } catch (e) {
      errorMessage.value = 'تعذّر بدء التسجيل: $e';
      step.value = AiIntakeStep.failure;
    }
  }

  Future<void> stopRecording() async {
    final path = await _recorder.stop();
    _amplitudeSub?.cancel();
    _elapsedSub?.cancel();
    if (path == null) {
      errorMessage.value = 'التسجيل قصير جدًا أو غير صالح. حاول مرة أخرى.';
      step.value = AiIntakeStep.voiceIdle;
      return;
    }
    recordedPath.value = path;
    _capturedInput = AiIntakeInput(
      sourceType: AiIntakeSourceType.audio,
      localPath: path,
      capturedAt: DateTime.now(),
      captureMetadata: {'durationMs': elapsed.value.inMilliseconds},
    );
    step.value = AiIntakeStep.recordingPreview;
  }

  Future<void> cancelRecording() async {
    await _recorder.cancel();
    _amplitudeSub?.cancel();
    _elapsedSub?.cancel();
    amplitude.value = 0;
    elapsed.value = Duration.zero;
    step.value = AiIntakeStep.voiceIdle;
  }

  Future<void> toggleClipPlayback() async {
    final path = recordedPath.value;
    if (path == null) return;
    if (isPlayingClip.value) {
      await _playback.pause();
      isPlayingClip.value = false;
    } else {
      await _playback.load(path);
      await _playback.play();
      isPlayingClip.value = true;
    }
  }

  Future<void> discardClipAndRetry() async {
    _deleteFileIfExists(recordedPath.value);
    recordedPath.value = null;
    isPlayingClip.value = false;
    amplitude.value = 0;
    elapsed.value = Duration.zero;
    step.value = AiIntakeStep.voiceIdle;
  }

  Future<void> confirmClipProceedToTranscription() async {
    final input = _capturedInput;
    if (input == null) return;
    final generation = _generation;
    step.value = AiIntakeStep.transcribing;
    isProcessing.value = true;
    processingProgress.value = null;
    try {
      final result = await _transcriber.transcribe(
        input.localPath,
        onProgress: (p) {
          if (generation == _generation) processingProgress.value = p;
        },
      );
      if (generation != _generation) return; // cancelled, or superseded by a new session
      _applyExtraction(result);
    } catch (e) {
      if (generation != _generation) return;
      isProcessing.value = false;
      processingProgress.value = null;
      errorMessage.value = 'تعذّر تحويل التسجيل إلى نص. حاول مرة أخرى.';
      step.value = AiIntakeStep.failure;
    }
  }

  /// Cancels an in-flight transcription/OCR call from the user's
  /// perspective: any result it eventually produces is discarded (see
  /// `_generation`), and the UI returns to the pre-processing preview so the
  /// user can retry or go back. The underlying native call may still finish
  /// in the background — this is a best-effort cancellation, not a native
  /// interrupt, and is documented as such in ARCHITECTURE.md.
  void cancelProcessing() {
    if (!isProcessing.value) return;
    _generation++;
    isProcessing.value = false;
    processingProgress.value = null;
    switch (_capturedInput?.sourceType) {
      case AiIntakeSourceType.audio:
        step.value = AiIntakeStep.recordingPreview;
      case AiIntakeSourceType.image:
        step.value = AiIntakeStep.imagePreview;
      case null:
        step.value = AiIntakeStep.voiceIdle;
    }
  }

  // ---- Image journey ----------------------------------------------------

  Future<void> pickImage({required bool fromCamera}) async {
    errorMessage.value = '';
    final granted = fromCamera ? await _permissionGate.requestCamera() : true;
    if (fromCamera && !granted) {
      step.value = AiIntakeStep.permissionDenied;
      return;
    }
    final input = fromCamera
        ? await _imageCapture.pickFromCamera()
        : await _imageCapture.pickFromGallery();
    if (input == null) return; // user cancelled the picker
    _capturedInput = input;
    imagePath.value = input.localPath;
    step.value = AiIntakeStep.imagePreview;
  }

  Future<void> confirmImageProceedToOcr() async {
    final input = _capturedInput;
    if (input == null) return;
    final generation = _generation;
    step.value = AiIntakeStep.extractingText;
    isProcessing.value = true;
    processingProgress.value = null;
    try {
      final result = await _imageTextExtractor.extract(
        input.localPath,
        onProgress: (p) {
          if (generation == _generation) processingProgress.value = p;
        },
      );
      if (generation != _generation) return;
      _applyExtraction(result);
    } catch (e) {
      if (generation != _generation) return;
      isProcessing.value = false;
      processingProgress.value = null;
      errorMessage.value = 'تعذّر استخراج النص من الصورة. حاول مرة أخرى.';
      step.value = AiIntakeStep.failure;
    }
  }

  void retakeImage() {
    imagePath.value = null;
    step.value = AiIntakeStep.imageIdle;
  }

  // ---- Shared review ------------------------------------------------

  void _applyExtraction(TextExtraction result) {
    extraction.value = result;
    reviewedText.value = result.originalText;
    _lastExtractionBaseText = result.originalText;
    corrections.clear();
    suggestions.clear();
    selectedSuggestionIds.clear();
    isProcessing.value = false;
    processingProgress.value = null;
    step.value = AiIntakeStep.review;
  }

  /// Free-form edits invalidate any suggestions/corrections computed against
  /// the previous text — otherwise a draft could carry `extractedFields`
  /// that no longer match what the user actually approved. Toggling an
  /// individual correction's accepted state does not go through this method
  /// (see `setCorrectionAccepted`), so accepting a correction does not wipe
  /// the very suggestion list currently under review.
  void updateReviewedText(String text) {
    if (text == reviewedText.value) return;
    reviewedText.value = text;
    if (corrections.isNotEmpty || suggestions.isNotEmpty || selectedSuggestionIds.isNotEmpty) {
      corrections.clear();
      suggestions.clear();
      selectedSuggestionIds.clear();
    }
  }

  /// Runs the (real, rule-based) reviewer and detector against the current
  /// reviewed text. Explicit and user-triggered rather than run on every
  /// keystroke, so it is always clear this is a deliberate local analysis
  /// step, not a live AI stream.
  void analyzeReviewedText() {
    _lastExtractionBaseText = reviewedText.value;
    corrections.assignAll(_textReviewer.suggestCorrections(reviewedText.value));
    suggestions.assignAll(_actionDetector.detect(reviewedText.value));
    selectedSuggestionIds.clear();
  }

  void setCorrectionAccepted(String id, bool accepted) {
    final idx = corrections.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    corrections[idx] = corrections[idx].copyWith(accepted: accepted);
    final base = _lastExtractionBaseText ?? reviewedText.value;
    reviewedText.value = _textReviewer.applyAccepted(base, corrections);
  }

  void toggleSuggestionSelected(String id) {
    if (selectedSuggestionIds.contains(id)) {
      selectedSuggestionIds.remove(id);
    } else {
      selectedSuggestionIds.add(id);
    }
  }

  /// Builds one [AiActionDraft] per selected suggestion and hands each to
  /// the host-facing `ActionDraftHandler`. Never executes anything itself.
  void confirmSelectedDrafts() {
    final input = _capturedInput;
    if (input == null || selectedSuggestionIds.isEmpty) return;
    final accepted = corrections.where((c) => c.accepted).toList();
    for (final suggestion in suggestions) {
      if (!selectedSuggestionIds.contains(suggestion.id)) continue;
      final draft = AiActionDraft(
        type: suggestion.type,
        sourceType: input.sourceType,
        originalText: extraction.value?.originalText ?? '',
        reviewedText: reviewedText.value,
        acceptedCorrections: accepted,
        extractedFields: suggestion.extractedFields,
        unresolvedFields: suggestion.missingRequiredFields,
        createdAt: DateTime.now(),
      );
      _actionDraftHandler.onActionDraft(draft);
    }
  }

  void _resetSession() {
    _generation++; // invalidate any transcription/OCR still in flight from a prior session
    _deleteFileIfExists(recordedPath.value);
    _capturedInput = null;
    recordedPath.value = null;
    imagePath.value = null;
    extraction.value = null;
    reviewedText.value = '';
    corrections.clear();
    suggestions.clear();
    selectedSuggestionIds.clear();
    errorMessage.value = '';
    amplitude.value = 0;
    elapsed.value = Duration.zero;
    isProcessing.value = false;
    processingProgress.value = null;
  }

  void _deleteFileIfExists(String? path) {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Best-effort cleanup only; nothing else to do if this fails.
    }
  }

  @override
  void onClose() {
    _generation++;
    _amplitudeSub?.cancel();
    _elapsedSub?.cancel();
    _deleteFileIfExists(recordedPath.value);
    _recorder.dispose();
    _playback.dispose();
    _transcriber.dispose();
    _imageTextExtractor.dispose();
    super.onClose();
  }
}
