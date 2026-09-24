AI Intake Flutter POC

This is a new standalone Flutter proof of concept, built to validate a reusable AI intake control. It is not part of the existing chat app or any existing request/meeting/email/task system. Build the reusable feature in its own module, then provide a small demo app around it. The feature should be portable into other Flutter projects later without copying the demo shell.

Design reference: AI Voice to Text in Figma. Use the supplied screenshot if Figma is inaccessible. The screenshot depicts recording idle/active/progress/result and image selection/progress/result. Adapt the result screen to four actions.

Goal

Record Arabic speech or capture/select an image.

Convert audio to Arabic text or run Arabic OCR on the image on the phone, where technically feasible.

Show original text and proposed Arabic spelling/grammar corrections; let the user edit and approve changes.

Detect any applicable action types: new request, meeting, email, task. One input can contain multiple actions.

Create a reviewed action draft for each selected suggestion. The demo app previews these drafts; it does not submit real requests, schedule meetings, send emails, or create tasks.

The POC must label real on-device processing and development stubs honestly. Do not show a mock as working AI.

Frameworks and engineering conventions

Concern

Decision

UI

Flutter and Material, styled to the design; Arabic RTL from the first screen

State, navigation, dependency injection

GetX, with binding/controller/page for each module

Architecture

UI, state, domain models/contracts, on-device adapters, and demo action handling separated

HTTP

No HTTP dependency is needed for a fully local POC. If a later adapter calls an approved internal API, use http, not Dio; keep transport/parsing out of controllers and make calls abortable

Audio playback visuals

audio_waveforms can inform UI if compatible, but recording must use an actual recording solution; do not treat PlayerController as a recorder

Native AI

Evaluate native SDKs or FFI for local inference; choose maintained, licensable dependencies after checking platform support and device cost

Platforms

iOS and Android phones for the POC. Document minimum OS versions, device requirements, and any platform-specific differences after implementation

Tests

Focus on state transitions, action/draft mapping, protected Arabic entities, and cancellation; manually verify native inference on real devices

Preferred GetX conventions: business logic in the controller, transport/native engine logic in dedicated services or adapters, and parsed state exposed to the UI. Dispose native engines, subscriptions, timers, and recordings in onClose. Do not introduce a second state-management or HTTP framework.

Project hierarchy

Create a new Flutter project. This is the intended separation; use consistent filenames and keep the feature module independent of demo code:

lib/
  main.dart
  app/
    app.dart                        # GetMaterialApp, theme, localization, routes
    app_routes.dart
    app_theme.dart
    app_translations.dart
  modules/
    home/
      home_binding.dart
      home_controller.dart
      home_page.dart
    ai_intake/                      # PORTABLE FEATURE: move this module later
      ai_intake_binding.dart
      ai_intake_controller.dart
      ai_intake_page.dart
      widgets/                      # recorder, image input, progress, review, actions
      models/                       # extraction, correction, action suggestion, draft
      contracts/                    # recorder, STT, OCR, reviewer, detector, host callback
      services/                     # orchestration and platform/on-device adapters
    action_preview/                 # DEMO ONLY: replaced by host app action forms
      action_preview_binding.dart
      action_preview_controller.dart
      action_preview_page.dart
test/
  modules/ai_intake/

The ai_intake feature must not import home, action_preview, project-specific chat models, authentication, or app routes. Provide a host-facing callback/interface such as onActionDraft(AiActionDraft draft); the demo shell supplies an implementation that opens action_preview. In a future app, the host will instead route that draft to its real form. Keep device permissions and native plugin setup documented so migration is practical.

Existing code supplied as reference

Two earlier snippets defined AudioPlayerWidget and AudioPlayerController for chat audio playback. They are design/behavior references, not files to paste into this new POC. The widget used AudioFileWaveforms, a play/pause button, duration/error labels, an optional local path, and onPlaying(ChatPostModel) to coordinate chat messages. The controller could download a remote document via AppConstants and ChatPostModel.docId, save .m4a, prepare playback, and show duration.

Do not import ChatPostModel, AppConstants, token-bearing document URLs, or the old remote download logic into this POC. Do not recreate the old playback defects: a disabled button when a remote file must first download, uncancelled duplicate listeners, swallowed errors, replacing Rx observables instead of updating .value, or logging token-bearing URLs. If the new feature needs playback of a just-recorded clip, give it a small independent local playback adapter.

Screen states and journeys

Voice

idle → permission → recording (timer + waveform) → stopped/preview → transcribing → text review → action draft preview

Show explicit stop, cancel, retry, and failure states. The user can listen to the captured clip before conversion if supported. Keep conversion progress honest: use indeterminate progress when the native engine cannot report a measured percentage.

Image

idle → camera/gallery → image preview → Arabic OCR → text review → action draft preview

Camera/gallery are in scope. Receiving images through another app's OS share sheet is a separate optional integration and should be reported as such. Handle image orientation, reasonable resolution limits, and multiple text blocks in reading order.

Shared review

Display original extraction, an editable final text, proposed corrections, action suggestions, extracted fields, and missing fields. Corrections are opt-in and can be individually accepted/rejected. Preserve names, monetary amounts, dates, emails, invoice numbers, file numbers, and IDs unless the user changes them. Allow zero, one, or multiple action suggestions. Never execute an action automatically.

On-device processing

Use replaceable interfaces. Evaluate candidates against representative Arabic content on actual target phones rather than assuming package support guarantees usable quality.

Operation

POC direction

Important checks

Speech to text

Multilingual local Whisper implementation is a candidate; evaluate a small model first

Egyptian/Gulf/Mixed Arabic, noisy speech, model storage, memory, heat, latency, iOS/Android integration

Arabic OCR

Arabic Tesseract model and supported native OCR are candidates

Printed Arabic, mixed Latin/Arabic, orientation, forms, image quality, reading order

Action detection

Local rules and structured extraction first; compare a small local model if needed

Multi-action commands, ambiguity, missing fields, false positives

Arabic grammar

Research and benchmark a suitable local approach; start with narrow corrections if necessary

Meaning preservation, dialect, entity protection, user acceptance, performance

The device OS speech recognizer can only be used for this offline POC after confirming that Arabic runs on-device on each supported device. Google ML Kit Text Recognition v2 must not be assumed to support Arabic OCR. If grammar correction is not reliable on supported phones, show this honestly in the POC and document an optional future on-premises service boundary. No public cloud AI calls and no silent network fallback.

Portable contracts

Define feature-owned models and interfaces, for example:

AiIntakeInput: sourceType(audio|image), localPath, captureMetadata
TextExtraction: originalText, language, segments, warnings
TextCorrection: originalSpan, proposedSpan, reason, accepted
ActionSuggestion: type(newRequest|meeting|email|task), evidenceText,
                  extractedFields, missingRequiredFields, confidence?
AiActionDraft: type, sourceType, originalText, reviewedText,
               acceptedCorrections, extractedFields, unresolvedFields

AudioRecorder / SpeechTranscriber / ImageTextExtractor /
ArabicTextReviewer / ActionDetector / ActionDraftHandler

The demo ActionDraftHandler routes to a preview showing exactly what would be passed to a host app. It must never actually send an email or modify external data. Document how a host app implements the handler and maps each of the four draft types to its existing forms.

Safety, privacy, and lifecycle

Keep raw media and extracted text on-device for the POC. Do not use public AI APIs or upload input for analytics.

Do not log transcript content, images, audio, tokens, or personal data.

Delete temporary media when appropriate; make retention and draft persistence explicit. Handle permission denial, silence, corrupt input, processing cancellation, missing model, and insufficient storage or memory.

Validate model provenance, licensing, download/packaging method, and update strategy. Do not fetch models from public URLs at runtime without an explicit product decision.

Inference output is a suggestion. Require review before producing a draft and before any future host app executes an action.

Work sequence for Codex or Claude

Create the standalone Flutter project and establish GetX modules, Arabic RTL, theme, routes, service contracts, and an independent demo action preview. Confirm the feature module does not depend on the demo shell.

Implement the design states and interactions for recording and image capture/selection. Use real device permission and capture flows.

Integrate real on-device Arabic transcription and OCR; compare model options on representative phones. If a native target cannot be run in the development environment, write integration code as far as possible and report the exact verification gap.

Implement local action detection, reviewed drafts, and individual correction acceptance. Evaluate Arabic grammar separately; label any experimental or stubbed part in UI and handover.

Verify on target devices and provide migration instructions for embedding modules/ai_intake into an existing Flutter project.

Acceptance criteria

Standalone demo runs on Android and iOS with Arabic RTL and UI close to the supplied visual reference.

Audio recording and image selection/capture are real. On supported pilot devices, Arabic STT and printed Arabic OCR process locally; otherwise the app shows a truthful unsupported/error state.

Original and reviewed text remain visible. Corrections require approval and preserve protected identifiers.

A text such as أنشئ طلب صيانة للتكييف وحدد اجتماعاً غداً مع الفريق may yield both request and meeting suggestions. Neither is executed.

All four action types generate structured, inspectable drafts through the feature interface. The demo previews them; no real external action occurs.

Cancellation and cleanup work; no silent external calls; clear distinction among real, experimental, unsupported, and stubbed behavior.

Handover specifies dependencies, minimum devices/OS, model sizes, native setup, tested Arabic samples and outcomes, and how to move the module into another app.

Open POC decisions

Determine/document maximum recording length, target devices and OS versions, printed versus handwritten image scope, acceptable Arabic dialects, whether users may retain recordings, and minimum quality thresholds. Make conservative documented POC choices where these are unspecified; ask only when a decision blocks progress.
