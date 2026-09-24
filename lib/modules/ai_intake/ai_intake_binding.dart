import 'package:get/get.dart';

import 'ai_intake_controller.dart';
import 'contracts/action_draft_handler.dart';
import 'services/device_audio_recorder.dart';
import 'services/image_capture_service.dart';
import 'services/local_audio_playback.dart';
import 'services/permission_service.dart';
import 'services/rule_based_action_detector.dart';
import 'services/rule_based_arabic_text_reviewer.dart';
import 'services/sherpa_whisper_arabic_transcriber.dart';
import 'services/stub_image_text_extractor.dart';
import 'services/whisper_model_provisioner.dart';

/// Wires the portable ai_intake feature to concrete on-device adapters.
///
/// The only thing this binding takes from outside the module is an
/// [ActionDraftHandler] — that is the sole seam through which a host app
/// customizes behavior. Everything else instantiated here (recorder,
/// playback, real on-device Whisper transcriber, stub OCR, rule-based
/// reviewer/detector, permission/image-capture services) lives inside
/// modules/ai_intake and has no knowledge of the demo shell.
///
/// `WhisperModelProvisioner` downloads, verifies, and installs the Arabic
/// speech model on first use and reuses it afterward — no manual/developer
/// setup step. `SherpaWhisperArabicTranscriber` only reads the model once
/// it's ready; if it's somehow still missing, it degrades to an honest stub
/// on its own (see that class) — this binding does not need to branch on
/// either case.
///
/// To embed this feature in another app: copy modules/ai_intake, keep this
/// binding (or replace individual services with better on-device adapters
/// behind the same contracts), and supply your own `ActionDraftHandler`
/// that routes drafts into your real forms instead of `action_preview`.
class AiIntakeBinding extends Bindings {
  AiIntakeBinding({required ActionDraftHandler Function() actionDraftHandler})
      : _actionDraftHandlerFactory = actionDraftHandler;

  final ActionDraftHandler Function() _actionDraftHandlerFactory;

  @override
  void dependencies() {
    Get.lazyPut<AiIntakeController>(
      () => AiIntakeController(
        recorder: DeviceAudioRecorder(),
        playback: LocalAudioPlayback(),
        transcriber: SherpaWhisperArabicTranscriber(),
        imageTextExtractor: StubImageTextExtractor(),
        textReviewer: RuleBasedArabicTextReviewer(),
        actionDetector: RuleBasedActionDetector(),
        actionDraftHandler: _actionDraftHandlerFactory(),
        permissionGate: PermissionService(),
        imageCapture: ImageCaptureService(),
        speechModelProvisioner: WhisperModelProvisioner(),
      ),
      fenix: true,
    );
  }
}
