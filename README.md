AI Intake: voice or image to reviewed actions

This document is the implementation brief for Codex or Claude working in the existing Flutter application. Implement the feature in that repository; do not create a separate app. The screenshot supplied with this brief is the visual reference for recording, transcription, image scanning, and result screens. Figma: AI Voice to Text. If Figma is inaccessible, use the attached screenshot and report any design details that cannot be determined.

Goal

An employee records Arabic speech or selects/captures an image. The app extracts editable text, proposes Arabic spelling/grammar corrections, and suggests one or more of these actions:

New request

Meeting

Email

Task

The employee reviews the source text, any corrections, and each suggested action before opening a prefilled draft. The app never creates a request or meeting, sends an email, or adds a task solely because AI suggested it.

My Flutter conventions

These are known preferences. Inspect the repository before choosing exact paths, names, dependencies, or APIs.

Flutter + GetX, using a binding, controller, and page for each module. Follow the existing project's structure and naming if it differs from the illustration below.

Use http for HTTP calls; do not introduce Dio. Keep HTTP transport and parsing outside the GetX controller. Repositories expose narrow operations to the feature.

Keep the access token in the existing session/singleton mechanism. If refresh fails, use the existing global logout/error flow. Never print tokens, document URLs containing tokens, transcripts, or image contents.

Where a network request is necessary, make it abortable and cancel active requests in onClose. Also stop timers, recordings, and native inference work when leaving the feature.

UI observes parsed state; it does not parse API responses inside widgets.

Arabic RTL is required. Preserve the existing theme, localization strategy, navigation, and reusable components.

The current AudioPlayerWidget/AudioPlayerController belong to chat playback. Inspect them for reusable styling, but create a separate recording and processing flow; do not break chat playback.

Illustrative feature layout, subject to repository inspection:

lib/
  modules/ai_intake/
    ai_intake_binding.dart
    ai_intake_controller.dart
    ai_intake_page.dart
    widgets/                 # recorder, waveform, image picker, review, action cards
    models/                  # input, extracted text, corrections, suggested actions
    repositories/            # orchestration and action-draft adapters
    services/                # recording, transcription, OCR, grammar, classification

Keep the actual existing placement of models, services, and repositories if the repo establishes one. Do not create parallel architectures.

Existing chat audio code: preserve and inspect

The two source snippets shared before this brief are existing chat audio playback code, not the new voice-capture implementation. Codex must inspect their actual current versions in the repository before editing. If they are not in the repository, request the files rather than reconstructing their APIs from this summary.

AudioPlayerWidget current contract:

Constructor receives an AudioPlayerController, a required ChatPostModel chatData, optional initialAudioPath, and optional onPlaying(ChatPostModel currentPlayer) callback.

Displays a play/pause icon, AudioFileWaveforms linked to the controller's PlayerController, a total-duration label via CCAOLabel, and a file-error label.

When given a local initial audio path, it initializes the controller path. When playback starts, it invokes onPlaying(chatData) so the parent can coordinate playback across messages.

The waveform uses PlayerWaveStyle and supports the existing chat layout. Preserve the message-level UI behavior when introducing the new recording screen.

AudioPlayerController current contract:

Uses GetX observables for the native PlayerController, filePath, isPlayingAudio, isPlayerError, and totalDuration; also has isRecording, isShowPlayer, audioSource, and an onDone() hook. Search for external uses before removing or renaming any of these.

Supports a local file path and a remote chat document identified by ChatPostModel.docId. The remote URL is generated with AppConstants.generateDocumentUrl using the existing token. A successful download is saved as a temporary .m4a; the model's isDownloaded and filePath are updated.

Prepares the native player with waveform extraction, reads DurationType.max, formats the duration, pauses other players when starting, and disposes the native player in onClose.

Preserve existing ChatPostModel, token/session handling, and any parent onPlaying coordination. The new AI voice feature must not replace chat playback or change existing message behavior.

Known defects to check if this code is touched: the widget disables play when filePath is null, preventing the remote download path; audioSource needs to be set before a remote download; the asynchronous play toggle is not awaited before calling onPlaying; isPlayerError is reassigned to a new observable rather than updating .value; download errors are swallowed; player-state listeners are registered twice and are not cancelled explicitly; and debug printing may expose a token-bearing document URL. Fix these in a focused playback change if needed, then verify both local and remote chat audio. Do not copy these defects into the new recorder.

User journeys

Voice

Tap microphone; request permission with a clear explanation.

Show active recording, timer, waveform, and stop/cancel controls. Bound recording duration and file size according to existing product rules; if none exist, choose documented limits.

Tap Stop and convert. Show processing and allow cancellation.

Present the original transcript in an editable review screen. Show grammar suggestions separately and let the user accept or reject them.

Detect zero, one, or several possible actions. Show why each was suggested and flag missing details.

Open the selected existing action form as a draft. User reviews and explicitly confirms through that form.

Image

Select from gallery or capture with camera. Determine whether inbound OS share-sheet images are already supported by the app; scope any platform work separately if not.

Preview the image, then run Arabic OCR with processing/cancel/error states.

Use the same text review, grammar, action suggestion, and draft steps as the voice path.

Result screen

The reference screenshot shows task and meeting options. Extend its action area to include new request and email, while respecting narrow screen sizes. Keep the original text available after corrections; show exactly what changed. Allow direct editing. Never silently alter names, amounts, dates, file numbers, invoice identifiers, or email addresses.

Processing architecture

Prefer processing on the phone for iOS and Android. Do not call a public AI service. Flutter provides the UI and orchestration; native code/FFI can host device inference. Inspect current packages and app platform support before selecting bridges.

Operation

Initial direction

Required validation

Recording

Native-backed recorder controlled by Flutter

Permission, interruption, cancellation, audio format, temporary-file lifecycle

Arabic speech to text

Evaluate a multilingual on-device Whisper implementation (whisper.cpp is a candidate); do not use an English-only model

Real Arabic accents, mixed Arabic/English, names, noisy clips, runtime, memory, supported devices

Arabic image OCR

Evaluate Arabic Tesseract models and native platform OCR where supported

Printed Arabic, mixed Arabic/English, photographed documents, handwriting expectations, field order

Action detection

Begin with explainable local rules/structured extraction; compare a small local model if needed

Multi-action texts, ambiguous verbs, confidence, missing fields, false positives

Arabic grammar suggestions

Evaluate a suitable local model separately; simple rule-based fixes may cover only a subset

Preserve meaning and protected entities; show suggestions rather than replacing text automatically; measure quality and latency

OS speech APIs are usable only after verifying offline Arabic support on each target device; do not assume an API being available means that Arabic recognition stays local. Google ML Kit Text Recognition v2 does not list Arabic script as a supported OCR script. Do not choose it as the Arabic OCR implementation without verifying a changed capability. Evaluate packages, licenses, model sizes, install/update distribution, and minimum OS/device requirements before final selection.

If on-device grammar quality or a target device is insufficient, keep a separate TextReviewService interface so an approved on-premises implementation can be integrated later. Any such fallback must be explicit to the user and must not be presented as offline. If an essential backend endpoint is missing, implement the real supported flow and a clearly marked development stub for the blocked portion; provide the needed API contract. Never claim mocked AI works.

The phone may still call existing internal APIs after user confirmation to create a request, meeting, email draft/send, or task. Offline extraction does not imply offline action submission.

Suggested contracts

Choose names consistent with the repo, but retain these concepts:

AiInput
  sourceType: audio | image
  localSourcePath
  captureMetadata

TextExtraction
  originalText
  sourceType
  segments/locations, if available
  language
  processingWarnings

TextCorrection
  originalSpan
  proposedSpan
  explanation
  accepted: bool

ActionSuggestion
  type: newRequest | meeting | email | task
  evidenceText
  confidence, if supported
  extractedFields
  missingRequiredFields
  userSelected: bool

AiIntakeDraft
  originalText
  reviewedText
  acceptedCorrections
  suggestedActions[]
  sourceReference (local only until submission policy is decided)

Define interfaces for AudioRecorder, SpeechTranscriber, ImageTextExtractor, ArabicTextReviewer, ActionDetector, and ActionDraftRouter. Implementations should be replaceable independently. Confirm that the newRequest, meeting, email, and task destinations exist before wiring navigation; reuse their existing validation and submission logic. Preserve multiple suggestions rather than forcing exactly one classification.

States and failure handling

Support idle, permission denied, capturing, recorded/selected, processing, review, draft navigation, cancelled, and failed/retry states. Do not lose the original text if correction or action detection fails. Releasing the screen must stop recording, cancel/ignore in-flight work, and clean up temporary media according to app policy. Handle empty audio, silence, unsupported/corrupt images, low OCR quality, missing on-device models, insufficient memory/storage, interrupted recording, and unavailable internal APIs with clear Arabic messages.

Security and data handling

Keep raw audio/images and extracted text on-device during local processing; disclose any later transfer to an internal API in the UX.

Do not upload source media for analytics or log it. Do not add external SDKs or model downloads from public endpoints at runtime without an explicit product decision.

Follow the app's current retention and access policy. Document temporary-file deletion and any offline draft persistence.

AI output is untrusted input. Existing forms and backend enforce authorization and business rules. Require user confirmation before any action that writes or sends data.

Implementation sequence for Codex

Inspect: Read pubspec.yaml, app entry/routing, GetX bindings, theme/localization, AudioPlayerWidget, AudioPlayerController, and existing request/meeting/email/task flows. Report actual structure and existing integration points, then continue implementation.

Build shared UI/state: Implement screenshot-aligned voice/image screens, review screen, action suggestion cards, models, controllers, and service contracts. Use one review flow for both input types.

Make inputs real: Integrate recording and image capture/selection. Prototype real on-device Arabic transcription and OCR on representative Android/iOS devices; record model size, memory, latency, and accuracy findings. Do not substitute English-only or cloud-dependent defaults.

Language/action processing: Implement local action suggestions and entity preservation, then evaluate Arabic grammar suggestions. Use a clearly identified incomplete state if model integration or quality remains unresolved.

Connect drafts: Prefill existing forms, validate missing fields there, and require explicit user confirmation. Do not bypass existing repositories or create duplicate submission code.

Verify: Run available Flutter analysis and focused tests; manually inspect RTL layout and native behavior on target devices. Report what was run and what could not be run.

Acceptance criteria

A short Arabic recording can be stopped and transcribed locally on supported devices; the result can be edited. The UI clearly identifies unsupported devices/models.

A printed Arabic image can produce editable text locally on supported devices; uncertain text remains reviewable.

Grammar suggestions show original and proposed text, can be accepted individually, and preserve protected identifiers unless the user edits them.

One input such as أنشئ طلب صيانة للتكييف، وحدد اجتماعاً غداً مع الفريق can suggest both a request and a meeting without creating either automatically.

Each of four action types opens the correct existing form as a draft; required missing details are requested; sending/creation requires the existing confirmation flow.

Cancel, retry, permissions, errors, backgrounding, and controller disposal behave predictably. No token or media content appears in logs.

Existing chat voice messages still play from local paths and remote docId documents; their waveform, duration, error state, and onPlaying(chatData) coordination remain functional.

The handover distinguishes real device functionality, stubs, backend dependencies, and untested platform/device combinations.

Decisions to resolve from the repository or with me

Exact existing form/routes/API names and whether email draft creation is separate from sending.

Minimum iOS/Android versions and representative low-end devices for the pilot.

Whether image sharing means camera/gallery selection only or also receiving images from other apps' share sheets.

Maximum audio length, image sizes, and local retention period.

Whether an approved on-premises fallback is acceptable when device Arabic grammar quality is insufficient.

Do the implementation work that can be done from the repo now. Ask only for a decision that blocks a specific next step; report the assumption and continue with independent tasks in the meantime.
