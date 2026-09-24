# AI Intake POC — Architecture Note

This is a standalone Flutter app. It is not part of the existing chat app;
nothing here imports `ChatPostModel`, `AppConstants`, or any remote-document
logic. The two loose files at the repo root, `audio_player_controller.dart`
and `audio_player_widget.dart`, are the old chat-audio snippets kept only as
a design/behavior reference (per README_AI_INTAKE.md) — they are excluded
from analysis, not imported anywhere, and not part of this app.

## Folder-by-folder

```
lib/
  main.dart                 # runApp(App()) only
  app/                       # ---- composition root (demo shell only) ----
    app.dart                 # GetMaterialApp: theme, ar-AE locale, routes
    app_routes.dart          # wires ai_intake -> DemoActionDraftHandler
    app_theme.dart           # Material 3 theme + status-banner colors
    app_translations.dart    # GetX Translations (ar_AE / en_US)
  modules/
    home/                    # ---- demo shell only ----
      home_binding.dart
      home_controller.dart
      home_page.dart          # landing page, two entry buttons
    ai_intake/               # ---- PORTABLE FEATURE ----
      ai_intake_binding.dart
      ai_intake_controller.dart
      voice_entry_page.dart
      image_entry_page.dart
      review_page.dart
      widgets/
        status_banner.dart          # real/stub/unsupported/error/warning label
        waveform_bar.dart           # live amplitude visualization
        voice_flow_header.dart      # gradient header used by the voice screens
        recorder_panel.dart         # idle/permission/recording/preview/failure views
        image_input_panel.dart      # idle/preview views
        processing_panel.dart       # honest progress + cancel (measured or indeterminate)
        review_panel.dart           # source-aware extraction summary, editable text, corrections
        action_suggestions_panel.dart
      models/
        ai_intake_input.dart
        ai_intake_step.dart
        text_extraction.dart
        text_correction.dart
        action_suggestion.dart
        ai_action_draft.dart
      contracts/
        audio_recorder.dart
        audio_playback.dart
        speech_transcriber.dart
        image_text_extractor.dart
        arabic_text_reviewer.dart
        action_detector.dart
        action_draft_handler.dart    # <-- the host-facing seam
        permission_gate.dart
        image_capture.dart
      services/
        device_audio_recorder.dart       # REAL (record package)
        local_audio_playback.dart        # REAL (audioplayers package)
        image_capture_service.dart       # REAL (image_picker package)
        permission_service.dart          # REAL (permission_handler package)
        sherpa_whisper_arabic_transcriber.dart # REAL on-device Whisper ASR (sherpa-onnx)
        stub_speech_transcriber.dart     # unused by default; kept as the honest-stub reference
        stub_image_text_extractor.dart   # STUB — labeled, not real AI (next milestone)
        rule_based_arabic_text_reviewer.dart  # REAL narrow rules, not ML
        rule_based_action_detector.dart       # REAL keyword rules, not ML
    action_preview/          # ---- DEMO ONLY ----
      action_preview_binding.dart
      action_preview_controller.dart
      action_preview_page.dart
      demo_action_draft_handler.dart   # implements ActionDraftHandler
      widgets/
        draft_preview_card.dart        # renders all 4 draft types read-only
test/
  widget_test.dart
  modules/ai_intake/
    fakes.dart
    ai_intake_controller_test.dart
    rule_based_action_detector_test.dart
    rule_based_arabic_text_reviewer_test.dart
    sherpa_whisper_arabic_transcriber_real_model_test.dart  # opt-in, needs the real model on disk
scripts/
  setup_whisper_arabic_model.sh   # downloads + stages the Whisper model (see below)
```

### Deviation from the literal file list in README_AI_INTAKE.md

The README sketches one `ai_intake_page.dart`. This build instead ships
`voice_entry_page.dart`, `image_entry_page.dart`, and `review_page.dart`,
because the ask (idle voice screen, idle image screen, and a *shared*
review screen) is naturally three routed screens, not one page with an
internal chooser. All three share the *same* `AiIntakeController` instance
(registered with `fenix: true` so it survives across the three routes) —
the module/dependency boundaries the README cares about are unaffected.

## Reliability fixes made before adding real STT

The flow had four correctness bugs that would have undermined trust in real
output once STT stopped being a stub. All four are fixed and covered by
tests in `test/modules/ai_intake/ai_intake_controller_test.dart`:

1. **Wrong/false result messaging.** The review screen used to show a
   hardcoded "تم تحويل التسجيل إلى نص" (recording converted) banner
   unconditionally — wrong wording for an image source, and a false claim
   of success for a stub or empty extraction. `ExtractionSummary`
   (`widgets/review_panel.dart`) now derives the banner from
   `controller.lastSourceType` and the actual extraction outcome: a real
   success banner only when text was actually recognized, a new
   `StatusBannerKind.warning` when a real engine ran but found nothing, and
   the existing stub banner otherwise.
2. **Stale suggestions after editing text.** `AiIntakeController
   .updateReviewedText` now clears `corrections`/`suggestions`/
   `selectedSuggestionIds` whenever the user's free-form edit actually
   changes the text, so a draft can never carry `extractedFields` computed
   against text the user has since changed. Accepting/rejecting an
   individual correction does *not* go through this method, so it does not
   wipe the suggestion list mid-review.
3. **Unhandled failures, cancellation, and leaving mid-flight.**
   `confirmClipProceedToTranscription`/`confirmImageProceedToOcr` now wrap
   the engine call in try/catch (routing a real exception to
   `AiIntakeStep.failure` instead of hanging), and a `_generation` counter
   invalidates any result that arrives after the user cancelled
   (`cancelProcessing()`, now reachable from a cancel button on both
   processing screens) or started a new session. `VoiceEntryPage` and
   `ImageEntryPage` wrap their `Scaffold` in a `PopScope` that stops the
   recorder or cancels processing before letting a back-gesture leave the
   screen mid-recording/mid-transcription.
4. **Resource/temp-file leaks.** `AudioRecorder`/`AudioPlayback` and now
   `SpeechTranscriber`/`ImageTextExtractor` all expose `dispose()`, called
   from `AiIntakeController.onClose()`. The recorded `.wav` is deleted on
   `discardClipAndRetry()`, and on any session reset that leaves one
   behind — it is no longer left on disk indefinitely.

## On-device Arabic speech-to-text (this milestone)

`SpeechTranscriber` is now backed by a **real, on-device, multilingual**
Whisper model via [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)
(`SherpaWhisperArabicTranscriber`, `services/sherpa_whisper_arabic_transcriber.dart`).
No cloud API is called at any point; `isAvailable`/the returned
`TextExtraction.isStub` are computed from whether the model files are
actually present on-device, not hardcoded.

**Why sherpa-onnx.** It is Apache-2.0, actively maintained (14.9k GitHub
stars, a release the week of this session), ships prebuilt native binaries
for iOS/Android/macOS/Linux/Windows via federated pub packages (no native
build step required beyond a normal `flutter build`), and its Dart API is
pure FFI — verifiable outside a full app via plain `dart run`, which is how
this milestone first validated it (see "How this was verified" below).

**Model.** `sherpa-onnx-whisper-tiny` — OpenAI's Whisper *tiny, multilingual*
checkpoint (99 languages including Arabic; explicitly **not** the `tiny.en`
English-only variant), converted to ONNX and int8-quantized by the
sherpa-onnx project.
- **Source:** `https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.tar.bz2`
- **License:** Whisper's weights are MIT (OpenAI); the sherpa-onnx runtime
  and conversion tooling are Apache-2.0.
- **Size:** archive ~111MB; only 3 files are needed on-device
  (`tiny-encoder.int8.onnx` ~12MB, `tiny-decoder.int8.onnx` ~90MB,
  `tiny-tokens.txt` ~0.8MB — the archive's fp32 `.onnx` files and
  `test_wavs/` are discarded).
- **Packaging:** not bundled in this repo (too large for git, and per
  README_AI_INTAKE.md the app must not fetch models from a public URL at
  runtime). `scripts/setup_whisper_arabic_model.sh <dir>` downloads the
  archive, verifies its SHA-256
  (`c46116994e539aa165266d96b325252728429c12535eb9d8b6a2b10f129e66b1`),
  and stages the 3 needed files.
- **Where the app expects them:** `getApplicationSupportDirectory()`
  + `/ai_intake_whisper_tiny_ar/` (constants in
  `SherpaWhisperArabicTranscriber`). Until they're placed there,
  `transcribe()` returns an honest `TextExtraction.stub(...)` naming the
  exact expected path — the app builds and runs with zero setup either way.
- **Supported devices:** anywhere sherpa-onnx ships a prebuilt binary
  (iOS, Android arm64/armeabi/x86/x86_64, macOS, Linux, Windows). No GPU
  required; CPU-only int8 inference. Concretely verified only on macOS
  desktop and the iOS *build* (see below) in this session — Android and a
  physical iOS/Android phone are unverified.
- **Known quality limitation, stated plainly:** the *tiny* model is the
  smallest/fastest Whisper checkpoint and has materially weaker Arabic
  accuracy than `base`/`small` (both also available from the same
  sherpa-onnx release, same setup script pattern, larger download). This
  POC forces `language: 'ar'` (no language auto-detection, which is
  unreliable on `tiny`) and always surfaces a warning banner reminding the
  user to review the text — this is not a hidden limitation.

**How this was verified in this session (no physical phone available):**
1. Downloaded the model and checksummed it; generated two **real** speech
   recordings offline via macOS's built-in Arabic TTS voice (`say -v Majed`,
   16kHz mono WAV) — one Arabic-only, one mixed Arabic/English — genuine
   audio waveforms, not synthetic test doubles.
2. Ran them through the actual sherpa-onnx Dart API via a standalone
   `dart run` script (no Flutter engine involved) — confirmed non-empty,
   plausible Arabic transcription:
   - Arabic-only input "أنشئ طلب صيانة للتكييف وحدد اجتماعاً غداً مع الفريق" → recognized "ان شعطلب سيانة لتكيف وحد دجتماعا غداً مع الفريق"
   - Mixed input "من فضلك أرسل إيميل إلى الفريق بخصوص meeting schedule يوم الاثنين" → recognized "من فضلك عرسلة عيميل للالفريق بخصوص ميطن صدبو اليوم للثنين" (the English phrase came out as Arabic-script phonetic approximations — the `tiny` model's typical code-switching behavior when the language is forced to Arabic, not empty and not fabricated)
3. Built this Flutter app for the iOS simulator (`flutter build ios --simulator`) — confirms sherpa-onnx's iOS binaries link correctly; did not run inference on the simulator since it has no real microphone input.
4. Built and ran the actual compiled **macOS app** (`flutter run -d macos`), placed the model files at the exact on-device path `SherpaWhisperArabicTranscriber` resolves via `path_provider`, and called `transcribe()` on the same two WAV files through the real adapter class end-to-end — reproduced the same non-empty output as step 2, confirming the app-level integration (path resolution, sandboxed file access, plugin initialization) works, not just the underlying library.
5. `flutter test` on macOS could **not** run this (its lightweight `flutter_tester` host resolves a stale/incompatible native sherpa-onnx binary — a known limitation of that host for FFI desktop plugins, unrelated to this adapter's logic); the opt-in test
   `test/modules/ai_intake/sherpa_whisper_arabic_transcriber_real_model_test.dart`
   exists for reproducibility but must be run via `flutter run -d macos` (as
   in step 4) or on a real device, documented in the test file's header.

**Reproducing this setup:**
```bash
bash scripts/setup_whisper_arabic_model.sh /tmp/whisper-ar
# macOS desktop debug build (bundle id com.example.voiceToAction):
DEST="$HOME/Library/Containers/com.example.voiceToAction/Data/Library/Application Support/com.example.voiceToAction/ai_intake_whisper_tiny_ar"
mkdir -p "$DEST" && cp /tmp/whisper-ar/ai_intake_whisper_tiny_ar/* "$DEST/"
# iOS/Android: push the same 3 files into the app's application-support
# directory on-device (e.g. via Xcode's Devices window file sharing, or
# `adb push ... /data/data/<pkg>/app_flutter/ai_intake_whisper_tiny_ar/`
# for a debuggable Android build) — not verified on real hardware this
# session; report this gap rather than assuming it works.
```

## Dependency direction

```
app/            -> modules/ai_intake, modules/action_preview, modules/home
modules/home    -> app/app_routes.dart (route name constants)
modules/action_preview -> modules/ai_intake (contracts + models only)
modules/ai_intake -> (nothing outside itself)
```

`modules/ai_intake` does not import `home`, `action_preview`, `app/*`, or
any chat-specific class. This is enforced by construction, not by a lint
rule: every page in `ai_intake` takes route names or callbacks as
constructor parameters (`reviewRouteName`, `onAfterConfirm`) instead of
importing `AppRoutes`, and the only thing it takes from outside itself is
an `ActionDraftHandler` instance, injected into `AiIntakeBinding` from
`app/app_routes.dart`.

## The host boundary: `ActionDraftHandler`

```dart
abstract class ActionDraftHandler {
  void onActionDraft(AiActionDraft draft);
}
```

This is the *only* way `ai_intake` communicates a result outward. This demo
ships `DemoActionDraftHandler` (in `modules/action_preview`), which appends
the draft to an in-memory list an `ActionPreviewController` renders
read-only — it never sends an email, schedules a meeting, creates a task,
or submits a request.

### What a host app provides to embed `modules/ai_intake`

1. Copy `lib/modules/ai_intake/` into the host project unchanged.
2. Add its dependencies to the host's `pubspec.yaml`: `get`, `record`,
   `audioplayers`, `image_picker`, `permission_handler`, `path_provider`,
   `sherpa_onnx`.
3. Add the iOS `Info.plist` keys (`NSMicrophoneUsageDescription`,
   `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`) and the
   Android manifest permissions (`RECORD_AUDIO`, `CAMERA`) — see below.
4. Implement `ActionDraftHandler` once, mapping `AiActionDraft.type` to the
   host's real forms:
   - `ActionType.newRequest` → the host's request-creation form, pre-filled
     from `extractedFields['category']` / `['description']`.
   - `ActionType.meeting` → the host's meeting/calendar form, pre-filled
     from `extractedFields['date']` / `['attendees']`.
   - `ActionType.email` → the host's compose screen, pre-filled from
     `extractedFields['recipient']` / `['subject']`, body = `reviewedText`.
   - `ActionType.task` → the host's task form, pre-filled from
     `extractedFields['title']` / `['dueDate']`.
   In every case, `unresolvedFields` lists what the host's form still needs
   to ask the user for — this milestone's rule-based detector does not
   guarantee full extraction.
5. Register `AiIntakeBinding(actionDraftHandler: () => YourHandler())` on
   whatever routes push `VoiceEntryPage` / `ImageEntryPage` / `ReviewPage`
   (see `app/app_routes.dart` for the exact wiring pattern to copy).
6. Run `scripts/setup_whisper_arabic_model.sh` and provision the model files
   on the target device (see "On-device Arabic speech-to-text" below) if
   real STT is wanted; otherwise `SherpaWhisperArabicTranscriber` degrades
   to an honest stub on its own. Decide whether to keep
   `StubImageTextExtractor` / `RuleBasedArabicTextReviewer` /
   `RuleBasedActionDetector`, or swap in better implementations behind the
   same contracts — nothing else in the module needs to change either way.

Nothing else is required: the module owns its own models, its own state
machine, and its own on-device adapters.

## What is real vs. stubbed in this milestone

| Piece | Status | Notes |
|---|---|---|
| Audio recording | **Real** | `record` package, actual mic capture, real permission flow, real amplitude/duration streams |
| Local clip playback | **Real** | `audioplayers`, plays the just-recorded file only — no relation to the old chat player |
| Camera/gallery capture | **Real** | `image_picker`, real permission flow, resolution capped at 2000px |
| Arabic speech-to-text | **Real, on-device** | Whisper tiny (multilingual) via sherpa-onnx, no cloud call; falls back to an honest stub if the model files aren't provisioned on-device — see above |
| Arabic OCR | **Stub** (next milestone) | Explicitly labeled; returns `TextExtraction.stub(...)`, never invented text |
| Arabic text normalization | **Real, narrow** | Tatweel removal + whitespace collapse only, with protected-entity detection (emails/amounts/dates/IDs). Not a grammar/spelling model. |
| Action detection | **Real, rule-based** | Arabic keyword/pattern matching for the four types, field extraction via simple regex/context windows. Not ML; `confidence` is always `null`. |
| Action drafts + preview | **Real (as data)**, demo preview only | Drafts are real, inspectable objects; the preview screen never submits anything |

## What another project must still supply to get real AI

- **STT is done for this milestone**, but a production host should still
  decide: `tiny` vs. `base`/`small` (accuracy/size trade-off, same setup
  script pattern), and how the 3 model files actually get onto a real
  device at install time (this POC only documents/manually verifies macOS;
  a production app needs a real asset-bundling or first-run-download-with-
  consent strategy — deliberately not decided here, see README_AI_INTAKE.md
  "Open POC decisions").
- An on-device Arabic OCR engine behind `ImageTextExtractor` — next
  milestone. Evaluate Arabic Tesseract or a vetted native OCR SDK; do not
  assume ML Kit v2 supports Arabic.
- Optionally, a real grammar/spelling model behind `ArabicTextReviewer` if
  the narrow rule-based normalization here proves insufficient.
- Model licensing/provenance/update-strategy decisions before bundling any
  of the above — none of this POC fetches a model at runtime.

## Minimum platform notes (from plugin constraints, not yet device-verified)

- iOS: `record`/`image_picker`/`permission_handler` in current versions
  target iOS 13+; this repo's `ios/Flutter/AppFrameworkInfo.plist` deployment
  target should be checked against that if raised in a future milestone.
- Android: `minSdkVersion` is left at Flutter's default (currently 23+ for
  this Flutter version); `record`/`image_picker`/`permission_handler` are
  compatible with that floor.
- These are plugin-constraint-derived, conservative statements, not
  measurements from a physical device — real-device verification is next
  milestone's job, per README_AI_INTAKE.md's own phasing.

## Known POC-scope simplifications (documented, not hidden)

- Recording length is uncapped in this milestone (open POC decision).
- The recorded `.wav` is deleted when discarded or when a new session
  starts/the controller closes; a picked image file is *not* proactively
  deleted (it is owned by the OS photo library/camera roll for a gallery
  pick, and for a camera capture, `image_picker` already places it in a
  temp location the OS reclaims) — full retention policy remains an open
  POC decision.
- `cancelProcessing()` is a best-effort UI-level cancellation: it discards
  the eventual result and frees the UI immediately, but sherpa-onnx's
  synchronous `decode()` call already in flight keeps running natively
  until it finishes — there is no native interrupt. Documented here rather
  than silently assumed away.
- Multi-block OCR reading order, handwriting, and OS share-sheet image
  ingestion are all out of scope, as called out in README_AI_INTAKE.md.
