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
        model_setup_panel.dart      # download progress / offline / storage / retry — no paths shown
        review_panel.dart           # source-aware extraction summary, editable text, corrections
        action_suggestions_panel.dart
      models/
        ai_intake_input.dart
        ai_intake_step.dart
        model_setup_progress.dart   # download status snapshot — UI-safe, no file paths
        text_extraction.dart
        text_correction.dart
        action_suggestion.dart
        ai_action_draft.dart
      contracts/
        audio_recorder.dart
        audio_playback.dart
        speech_transcriber.dart
        speech_model_provisioner.dart  # <-- the app-managed setup seam
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
        whisper_model_spec.dart          # pinned URLs/SHA-256/sizes — single source of truth
        whisper_model_provisioner.dart   # REAL: downloads/verifies/installs the model, no dev step
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
    whisper_model_provisioner_test.dart  # download/resume/integrity/offline/reuse, mocked HTTP
    sherpa_whisper_arabic_transcriber_real_model_test.dart  # opt-in, needs the real model on disk
scripts/
  setup_whisper_arabic_model.sh   # OPTIONAL dev/test utility only — see below; end users never run this
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
5. **Navigating to review on a failed/cancelled attempt.** `VoiceEntryPage`
   and `ImageEntryPage` used to call `Get.toNamed(reviewRoute)`
   unconditionally after awaiting `confirmClipProceedToTranscription()` /
   `confirmImageProceedToOcr()` — so a failure, a cancellation, or (once
   model setup existed) a still-downloading model would still navigate to
   an empty/broken review screen. Both pages now check
   `controller.step.value == AiIntakeStep.review` before navigating; on any
   other outcome the page stays put and its own `_buildStep()` switch
   already renders the correct state (failure, model setup, or the
   recording/image preview it cancelled back to).

## App-managed on-device Arabic speech-to-text

`SpeechTranscriber` is backed by a **real, on-device, multilingual** Whisper
model via [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)
(`SherpaWhisperArabicTranscriber`). No cloud API is called at any point, and
**no manual/developer setup step is required**: `WhisperModelProvisioner`
downloads, verifies, and installs the model the first time it's needed, and
`AiIntakeController` waits for that before ever calling the transcriber.

### The app-managed setup flow

```
AiIntakeController.confirmClipProceedToTranscription()
  -> if provisioner not ready: step = preparingModel, await provisioner.ensureReady()
       -> ModelSetupView renders controller.modelSetup (downloading %, offline, storage, failed)
       -> user can retry (re-runs ensureReady()) or cancel (PopScope / cancelProcessing())
  -> once ready: step = transcribing, call SherpaWhisperArabicTranscriber.transcribe()
```

`WhisperModelProvisioner` (`services/whisper_model_provisioner.dart`):
- Downloads each of the 3 model files to a `<name>.part` sibling and only
  renames it into place after its **SHA-256 matches the pinned value** in
  `WhisperModelSpec` — a corrupted or truncated download can never be
  mistaken for a good one.
- **Resumes an interrupted download**: on retry, it sends an HTTP `Range`
  request starting from the `.part` file's current length; if the server
  doesn't honor the range (falls back to a `200` instead of `206`), the
  partial bytes are discarded and only *that* file restarts — files that
  already verified successfully are left untouched.
- **Reuses the install on every later launch** via a small manifest file
  (`.model_manifest.json`) recording each file's pinned hash/size; a valid
  manifest plus a matching on-disk file size is enough to report `ready`
  with **zero network calls** — verified in this session at 1ms (see below).
- Classifies failures instead of lumping them together: a `SocketException`/
  timeout/connection error → `ModelSetupStatus.offline`; a `FileSystemException`
  that looks like `ENOSPC` (or the Windows disk-full code) →
  `insufficientStorage`; anything else (bad HTTP status, hash mismatch) →
  `failed`. `ModelSetupView` shows a different, honest, non-technical Arabic
  message for each.
- Is cancellable (`cancel()`): the in-flight HTTP stream stops, already-
  verified files are kept, and the partial file is left on disk so a later
  attempt resumes rather than restarting.
- Reports `estimatedTotalBytes` **before any network call** — the 3 pinned
  file sizes are known upfront — so `ModelSetupView` can show "X of Y MB"
  from the very first frame.
- Never surfaces a file path, host name, or script name to the user —
  `ModelSetupProgress` only carries a status enum and byte counts.

### Model provenance

`sherpa-onnx-whisper-tiny` — OpenAI's Whisper *tiny, multilingual* checkpoint
(99 languages including Arabic; explicitly **not** the `tiny.en`
English-only variant), converted to ONNX and int8-quantized by the
sherpa-onnx project.
- **Source (what the app actually downloads from):** a **pinned, immutable
  commit** of the sherpa-onnx project's own Hugging Face mirror —
  `https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/65176e2deb88badc814a94058666cadccc29b61c/<file>`.
  Pinning to a commit SHA (not a mutable branch) means the bytes served at
  each URL cannot change later. This session downloaded each of the 3 files
  from both this Hugging Face URL and the canonical GitHub release
  (`sherpa-onnx-whisper-tiny.tar.bz2`, tag `asr-models`) and confirmed their
  SHA-256 hashes are byte-for-byte identical — the pinned hashes in
  `WhisperModelSpec` are this verification, not an assumption.
- **License:** Whisper's weights are MIT (OpenAI); the sherpa-onnx runtime
  and conversion tooling are Apache-2.0.
- **Size:** exactly 103,609,903 bytes across the 3 files this app needs
  (`tiny-encoder.int8.onnx` 12,937,772 B, `tiny-decoder.int8.onnx`
  89,855,401 B, `tiny-tokens.txt` 816,730 B) — the fp32 `.onnx` files and
  `test_wavs/` bundled in the upstream release/repo are never downloaded.
- **Where it's installed:** `getApplicationSupportDirectory()` +
  `/ai_intake_whisper_tiny_ar/` (a constant in `WhisperModelSpec`, shared by
  the provisioner and the transcriber so they can never disagree).
- **Supported devices:** anywhere sherpa-onnx ships a prebuilt binary (iOS,
  Android arm64/armeabi/x86/x86_64, macOS, Linux, Windows). No GPU required;
  CPU-only int8 inference.
- **Known quality limitation, stated plainly:** the *tiny* model is the
  smallest/fastest Whisper checkpoint and has materially weaker Arabic
  accuracy than `base`/`small` (both hosted at the same Hugging Face
  organization, same integrity-verification approach, larger download —
  see "Optional: upgrading the model" below). This POC forces
  `language: 'ar'` (no language auto-detection, which is unreliable on
  `tiny`) and always surfaces a warning banner reminding the user to review
  the text — this is not a hidden limitation.

### How this was verified in this session (no physical phone available)

**The app-managed download/install/reuse pipeline was verified for real,
with no manual file copying performed by the operator:**
1. Cleared any previously-installed model from the macOS app's on-device
   storage to guarantee a genuinely fresh-install state.
2. Ran the actual compiled macOS app (`flutter run -d macos`) with a
   temporary diagnostic entrypoint that called
   `WhisperModelProvisioner()` — the real class, real `WhisperModelSpec`,
   real Hugging Face URLs, no test overrides — and watched it:
   - Report `estimatedTotalBytes = 103,609,903` before any network activity.
   - Stream real download progress from an empty directory to 100%.
   - Complete in ~16.7s: `FIRST ensureReady() => true (status=ready)`.
   - On an immediate second call: `SECOND ensureReady() => true in 1ms` —
     confirmed zero network activity, reused from the manifest on disk.
   - Inspected the installed directory afterward: all 3 files present with
     the exact pinned sizes, no leftover `.part` files, and a manifest
     whose recorded hashes match `WhisperModelSpec` exactly.
3. Immediately after (same run), constructed a fresh
   `SherpaWhisperArabicTranscriber()` (no overrides) and fed it the same two
   genuine Arabic/mixed-language WAV recordings used in earlier
   verification (macOS `say -v Majed` TTS, 16kHz mono) — both transcribed
   to real, non-empty, non-fabricated text, identical to prior runs:
   - "أنشئ طلب صيانة للتكييف وحدد اجتماعاً غداً مع الفريق" → "ان شعطلب سيانة لتكيف وحد دجتماعا غداً مع الفريق"
   - "من فضلك أرسل إيميل إلى الفريق بخصوص meeting schedule يوم الاثنين" → "من فضلك عرسلة عيميل للالفريق بخصوص ميطن صدبو اليوم للثنين"
4. A macOS-specific note, not an iOS/Android concern: this required adding
   `com.apple.security.network.client` to `macos/Runner/DebugProfile.entitlements`
   — the macOS debug build's App Sandbox blocks all outbound network
   calls without it. iOS and Android apps have no equivalent restriction
   (Android instead needs the `INTERNET` manifest permission, which this
   milestone added to `android/app/src/main/AndroidManifest.xml` — it was
   present only in the debug/profile manifests before, meaning a **release**
   Android build would have had no network access at all).
5. Built this app for the **iOS simulator** (`flutter build ios --simulator`)
   — confirms sherpa-onnx's and `http`'s iOS binaries link correctly.
   **Not verified this session:** driving the simulator's UI (tap record,
   grant the mic permission dialog, speak) — no UI-automation tool (idb/
   Maestro/Appium) is available in this environment, and the simulator's
   mic passthrough was not exercised. So: the download/install/transcribe
   *pipeline* is verified end-to-end through a real compiled app; a live,
   finger-tap-driven recording on an iOS/Android device is not.
6. `flutter test` on macOS still cannot run `sherpa_onnx` directly (its
   lightweight `flutter_tester` host resolves an incompatible native
   binary — unrelated to this milestone's code, same limitation noted
   previously); `WhisperModelProvisioner`'s own logic is instead covered by
   `test/modules/ai_intake/whisper_model_provisioner_test.dart` using a
   mocked `http.Client` (no network, no real model needed) exercising
   download/resume/integrity-failure/retry/offline/reuse paths directly —
   these *do* run under plain `flutter test`.

### Optional: engine-level manual testing (not needed for normal use)

`scripts/setup_whisper_arabic_model.sh` still exists for one purpose only:
letting a developer stage the model into an arbitrary local directory to
exercise `sherpa_whisper_arabic_transcriber_real_model_test.dart` (a lower-
level test of the transcriber's decode correctness in isolation from the
provisioner). It is **not** part of the app's runtime path and an end user
never needs it — a real install downloads the model itself, as verified
above.

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
   `sherpa_onnx`, `http`, `crypto`.
3. Add the iOS `Info.plist` keys (`NSMicrophoneUsageDescription`,
   `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`), the
   Android manifest permissions (`RECORD_AUDIO`, `CAMERA`, `INTERNET`) — see
   below — and, only if also targeting macOS,
   `com.apple.security.network.client` in that platform's entitlements
   (iOS/Android need no equivalent).
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
6. Nothing else for STT — `WhisperModelProvisioner` downloads, verifies, and
   installs the model itself on first use (see "App-managed on-device
   Arabic speech-to-text" below); there is no setup step to run. Decide
   whether to keep `StubImageTextExtractor` / `RuleBasedArabicTextReviewer` /
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
| Arabic speech-to-text | **Real, on-device, app-managed setup** | Whisper tiny (multilingual) via sherpa-onnx; `WhisperModelProvisioner` downloads/verifies/installs the model on first use, no cloud call at inference, no manual step; falls back to an honest stub only if setup was skipped entirely |
| Arabic OCR | **Stub** (next milestone) | Explicitly labeled; returns `TextExtraction.stub(...)`, never invented text |
| Arabic text normalization | **Real, narrow** | Tatweel removal + whitespace collapse only, with protected-entity detection (emails/amounts/dates/IDs). Not a grammar/spelling model. |
| Action detection | **Real, rule-based** | Arabic keyword/pattern matching for the four types, field extraction via simple regex/context windows. Not ML; `confidence` is always `null`. |
| Action drafts + preview | **Real (as data)**, demo preview only | Drafts are real, inspectable objects; the preview screen never submits anything |

## What another project must still supply to get real AI

- **STT setup is fully app-managed for this milestone**, but a production
  host should still decide: `tiny` vs. `base`/`small` (accuracy/size
  trade-off — swap the 3 URLs/hashes/sizes in `WhisperModelSpec`, same
  provisioner code), whether to ask the user's consent before a ~100MB
  cellular download (this POC downloads unconditionally on first need —
  see README_AI_INTAKE.md "Open POC decisions"), and whether Wi-Fi-only
  download is required for a production release.
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
  compatible with that floor. `android/app/src/main/AndroidManifest.xml`
  now declares `INTERNET` (needed for the one-time model download; it was
  previously only in the debug/profile manifests Flutter adds for its own
  tooling, which are not part of a release build).
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
- The ~103MB model download happens unconditionally on first need, on
  whatever network is available (no Wi-Fi-only gate, no user consent
  prompt before spending cellular data) — a deliberate POC simplification,
  flagged above under "What another project must still supply."
- `macos/Runner/DebugProfile.entitlements` now includes
  `com.apple.security.network.client`, added solely so this session could
  verify the download flow through a real compiled app on this development
  machine. macOS is not a target platform for this app (README_AI_INTAKE.md
  scopes this POC to iOS/Android phones); the change is harmless and
  debug-only, kept because it makes the same verification reproducible
  later without rediscovering the App Sandbox restriction.
