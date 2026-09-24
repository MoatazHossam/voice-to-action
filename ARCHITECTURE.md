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
        image_model_provisioner.dart   # <-- the OCR app-managed setup seam
      services/
        device_audio_recorder.dart       # REAL (record package)
        local_audio_playback.dart        # REAL (audioplayers package)
        image_capture_service.dart       # REAL (image_picker package)
        permission_service.dart          # REAL (permission_handler package)
        whisper_model_spec.dart          # pinned URLs/SHA-256/sizes — single source of truth
        whisper_model_provisioner.dart   # REAL: downloads/verifies/installs the STT model, no dev step
        sherpa_whisper_arabic_transcriber.dart # REAL on-device Whisper ASR (sherpa-onnx)
        stub_speech_transcriber.dart     # unused by default; kept as the honest-stub reference
        tesseract_model_spec.dart        # pinned URLs/SHA-256/sizes for OCR trained-data
        tesseract_model_provisioner.dart # REAL: downloads/verifies/installs the OCR model, no dev step
        tesseract_arabic_ocr_extractor.dart # REAL on-device Arabic OCR (Tesseract 4 LSTM)
        stub_image_text_extractor.dart   # unused by default; kept as the honest-stub reference
        rule_based_arabic_text_reviewer.dart  # REAL narrow rules, not ML
        rule_based_action_detector.dart       # REAL keyword rules, not ML
    action_preview/          # ---- DEMO ONLY ----
      action_preview_binding.dart
      action_preview_controller.dart
      action_preview_page.dart
      demo_action_draft_handler.dart   # implements ActionDraftHandler
      widgets/
        draft_preview_card.dart        # renders all 4 draft types read-only
assets/
  tessdata_config.json   # tiny filename-list config flutter_tesseract_ocr always reads
                          # from the asset bundle — NOT trained-data itself (see below)
test/
  widget_test.dart
  modules/ai_intake/
    fakes.dart
    ai_intake_controller_test.dart
    rule_based_action_detector_test.dart
    rule_based_arabic_text_reviewer_test.dart
    whisper_model_provisioner_test.dart  # download/resume/integrity/offline/reuse, mocked HTTP
    tesseract_model_provisioner_test.dart  # same coverage, for the OCR model
    tesseract_arabic_ocr_extractor_test.dart  # output mapping, empty/error handling, EXIF orientation
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
6. **A manifest-write failure could strand the setup screen.** Found in
   review of the milestone that added `WhisperModelProvisioner`:
   `_runEnsureReady()` guarded `dir.create()` with try/catch but not the
   final `_writeManifest()` call — an exception there (e.g. the device runs
   out of space on that very last write, after every file already
   downloaded and verified) escaped `ensureReady()` uncaught. Since
   `AiIntakeController` `await`s that call without its own try/catch around
   it, the exception would propagate out of `confirmClipProceedToTranscription()`
   entirely unhandled: no terminal status ever got emitted, so
   `ModelSetupView` stayed frozen showing "downloading 100%" forever with no
   way to retry. Both `WhisperModelProvisioner` and the new
   `TesseractModelProvisioner` now wrap their *entire* `ensureReady()` body
   in try/catch, guaranteeing it always resolves to a terminal status
   (`ready` or a classified failure) and never throws. Regression-tested in
   `whisper_model_provisioner_test.dart` (`'a failure while writing the
   manifest is reported, never left stuck mid-setup'`) by pre-creating the
   manifest's temp-file path as a directory so the write genuinely fails.

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

## App-managed on-device Arabic OCR

`ImageTextExtractor` is backed by a **real, on-device** OCR engine —
Tesseract 4's LSTM engine via `flutter_tesseract_ocr` (native:
Tesseract4Android on Android, SwiftyTesseract on iOS). No cloud API is
called at any point. Exactly like STT, no manual/developer setup step is
required: `TesseractModelProvisioner` downloads, verifies, and installs the
trained-data files the first time OCR is needed, and `AiIntakeController`
waits for that before ever calling the extractor. The whole design mirrors
`WhisperModelProvisioner`/`SherpaWhisperArabicTranscriber` point-for-point
(shared `ModelSetupProgress`/`ModelSetupView`, same pinned-checksum
download/resume/manifest-cache approach) — see that section above for the
mechanics, not repeated here.

### Why Tesseract, not Google ML Kit

Google ML Kit's on-device Text Recognition (v2) supports Latin, Chinese,
Devanagari, Japanese, and Korean scripts — **Arabic is not in that list**,
confirmed by checking Google's own supported-languages documentation (it
has no mention of Arabic at all). This is exactly the trap
README_AI_INTAKE.md warns against ("Google ML Kit Text Recognition v2 must
not be assumed to support Arabic"). No ML Kit variant was evaluated further
once this was confirmed.

Tesseract was chosen instead because: it has genuine, mature Arabic trained
data (`tessdata_fast`, actively maintained by the Tesseract project, 617
GitHub stars on that data repo alone); Flutter wrappers exist for both
target platforms wrapping the same well-established native libraries
(`Tesseract4Android`, `SwiftyTesseract`); and — most importantly — this
milestone actually **ran** it against a real image on both iOS and Android
and got real, inspectable, non-empty Arabic output (see below), which is
the standard this repo holds itself to rather than trusting a package
description.

### Model provenance

`tessdata_fast`'s `ara.traineddata` + `eng.traineddata` — Tesseract's own
"fast" (integer-optimized, LSTM-only) trained data, chosen over
`tessdata`/`tessdata_best` for its much smaller size, appropriate for a
phone. Both Arabic and English data are fetched (not Arabic alone) so
`ara+eng` mixed-language recognition — required by this milestone — actually
works; recognizing only `ara` would garble any English/Latin substring
(emails, invoice codes) even worse than documented below.
- **Source:** a pinned, immutable commit of the official
  `tesseract-ocr/tessdata_fast` GitHub repository —
  `https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/87416418657359cb625c412a48b6e1d6d41c29bd/<file>`.
- **License:** Apache-2.0 (same as the Tesseract project itself).
- **Size:** 1,432,056 bytes (`ara.traineddata`) + 4,113,088 bytes
  (`eng.traineddata`) = 5,545,144 bytes total — this session's own SHA-256
  checksums of the downloaded bytes are what's pinned in
  `TesseractModelSpec`, not assumed values.
- **Where it's installed:** this is the one place OCR setup is *not*
  free to choose its own directory — `flutter_tesseract_ocr`'s own Dart code
  hardcodes `getApplicationDocumentsDirectory()/tessdata` internally (see
  `_loadTessData()` in its source) and there is no API to override that.
  `TesseractModelSpec.resolveModelDirectory()` matches this exactly, and
  because the provisioner places real, correctly-named files there before
  the plugin's own internal "copy from asset bundle" fallback ever runs,
  that fallback is never triggered.
- **The one thing still bundled as an asset:** `flutter_tesseract_ocr`
  unconditionally reads a small `assets/tessdata_config.json` (just
  `{"files": ["ara.traineddata", "eng.traineddata"]}`) from the Flutter
  asset bundle on every call, regardless of where the actual trained-data
  files come from — this is a few dozen bytes of filenames, not the
  trained-data itself, and is committed to this repo (declared in
  `pubspec.yaml`'s `flutter: assets:`).
- **Supported devices:** Tesseract4Android supports Android's standard ABIs;
  SwiftyTesseract ships as a compiled framework. No GPU required.

### A confirmed platform gap: iOS Simulator on Apple Silicon (documented, not hidden)

`flutter_tesseract_ocr`'s SwiftyTesseract dependency ships a precompiled
framework with **no arm64 simulator slice**, and Apple's newest simulator
runtimes (confirmed here on iOS 26.2) have also dropped x86_64/Rosetta
support entirely — so on a current Apple Silicon Mac with only the latest
runtime, this plugin cannot run on a simulator at all (`unsupported Swift
architecture`, then `module not found` once arm64 is excluded, then
`the following target(s) do not support arm64 architecture ... required
for Apple Silicon iOS 26+ simulators`). This is a real, upstream limitation
of the dependency, not this app's code.

**Workaround used to make verification possible in this environment:**
`ios/Podfile`'s `post_install` and three build configurations in
`ios/Runner.xcodeproj/project.pbxproj` now set
`EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64` and
`ARCHS[sdk=iphonesimulator*] = x86_64`, forcing the whole simulator build to
the x86_64 slice SwiftyTesseract does provide. This only affects the
`iphonesimulator` SDK — real device builds (`iphoneos`, arm64) are
completely unaffected. Verification then required booting an **older**
simulator runtime that still supports x86_64/Rosetta (iOS 17.5 here; iOS
26.2 does not) — see the verification log below.

**What this means going forward:** a physical iPhone is unaffected by any
of this (it always builds/runs arm64 device natively) and is the
recommended way to verify iOS OCR from here on. If SwiftyTesseract never
ships an arm64-simulator slice, iOS simulator testing of this feature will
keep requiring an older runtime + this workaround, or should move to a
device.

**Also required for Android:** the *published* pub.dev release of
`flutter_tesseract_ocr` (0.4.31) still calls the defunct `jcenter()` in its
`android/build.gradle` and fails to build under current Gradle/AGP
(`Could not find method jcenter()`). The fix (`mavenCentral()`) exists on
the package's GitHub `master` but was never published to pub.dev. This repo
pins a git dependency directly to the commit that has the fix
(`259994d4d93d755f8d365907df0f3b174f85ff57`) — see `pubspec.yaml` — rather
than patching pub-cache locally, so the fix is reproducible for anyone who
runs `flutter pub get` on this repo, not just this machine.

### How this was verified in this session

Real Arabic invoice-style test image (rendered via headless Chrome from
HTML — genuine rasterized glyphs, not a text file) containing: an Arabic
title, an invoice number, a date, an Arabic name, an email address, a full
Arabic sentence with an embedded plain number, an amount with a currency
code, and a closing line mixing Arabic and English:

```
فاتورة صيانة
رقم الفاتورة: INV-2026-00123
التاريخ: 12/05/2026
اسم العميل: أحمد محمد السيد
البريد الإلكتروني: ahmed.sayed@example.com
تم إصلاح وحدة التكييف المركزي واستبدال الفلتر بناءً على طلب الصيانة رقم 4487.
المبلغ الإجمالي: 1,250.00 AED
يرجى السداد خلال 15 يوماً من تاريخ الفاتورة. للاستفسار Contact Support Team.
```

**Setup pipeline (both platforms):** cleared any installed model, ran the
real app, watched `TesseractModelProvisioner` report
`estimatedTotalBytes=5,545,144` before any network call, stream real
download progress from a real network request against the pinned GitHub
URLs, reach `ready` (iOS: ~1s reusing a warm connection; Android: seconds on
first run), and reuse it on a second call (Android: 33ms/12ms across
separate runs) with zero network activity — installed files' sizes and the
manifest's recorded hashes matched `TesseractModelSpec` exactly. No file was
ever copied in by hand for the model.

**OCR result — iOS 17.5 simulator** (via the Rosetta workaround above), run
through the real `TesseractArabicOcrExtractor` class:

```
فاتورة صيادة

INV-2026-00123 :8)9iLa!! a3,

التاريخ: 12/05/2026

اسم العميل: أحمد محمد السيد

البريد الإلكتروني: 16.6010م311760.521[/60)6967<310

تم إصلاح وحدة التكييف المركزي واستبدال الفلتر بناءً على طلب الصيانة رقم 4487.
المبلغ الإجمالي: (اعا 1,250.00

يرجى السداد خلال 15 ‎Logs‏ من تاريخ الفاتورة. للاستفسار 162317 51000011 0011361).
```

**OCR result — Android emulator (Pixel 3a, API 33)**, same image, same
extractor class:

```
فاتورةصيادة

 رقم الفاتورة:‎INV-2026-00123‏

 التاريخ:12/05/2026

 اسم العميل: أحمد محمدالسيد

 البريد الإلكتروني:‎ahmed.sayed@example.com‏

 تم إصلاح وحدة التكييف المركزي واستبدال الفلتر بناءً على طلب الصيانة رقم4487.
 المبلغ الإجمالي: ‎AED‏1,250.00

 يرجى السداد خلال 15 ‎Logs‏ من تاريخ الفاتورة. للاستفسار‎.Contact Support Team‏
```

**Honest accuracy assessment, stated plainly:**
- **Strong on printed, fully-Arabic content**: the customer-name line and
  the full Arabic maintenance-description sentence (including a plain
  embedded number, "4487") came back **character-for-character correct on
  both platforms**. The date line was correct on both platforms too.
- **Android was noticeably more accurate than iOS on this same image**: the
  invoice number line, the full email address, and the closing English
  phrase ("Contact Support Team") were all recognized correctly on Android
  and badly garbled on iOS. Both platforms use the same trained data and
  the same `ara+eng`/PSM-3 settings, so this difference comes from the
  native engines themselves (Tesseract4Android vs. SwiftyTesseract), not
  this app's code — and is exactly the kind of per-platform gap this
  milestone was asked to surface rather than average away.
- **Mixed Arabic/English spans are the weak point on both platforms**: a
  short Latin run embedded inside an RTL Arabic line (a currency code, a
  short label right before a code) is where recognition degrades most; a
  standalone paragraph in one script does much better than a line that
  switches scripts mid-stream.
- **Never fabricated**: every garbled span above is visibly wrong (stray
  punctuation, digit soup, word-salad) rather than plausible-looking
  invented text — consistent with this being the model's genuine output,
  not a mock.
- These are the *pinned, small* `tessdata_fast` models. `tessdata`/
  `tessdata_best` (same source, same integrity-verification approach, larger
  download — swap the URLs/hashes/sizes in `TesseractModelSpec`) would be
  the first thing to evaluate if higher accuracy is needed; this was not
  attempted this session.

**What was not verified this session:** the iOS **26.2** simulator (blocked
by the arm64-slice gap above — an *older* runtime was used instead), any
physical iPhone or Android phone, and a live, finger-tap-driven run through
the actual app UI (home → image entry → gallery/camera → review) on either
platform — no UI-automation tool (idb/Maestro/Appium for iOS; Android's
`adb shell input tap` was available but not used for this pass) was used
this session. What *was* verified end-to-end is the exact production
`TesseractModelProvisioner` and `TesseractArabicOcrExtractor` classes
`AiIntakeBinding` wires up, executed directly and for real on both
platforms outside the widget tree — the same code path the UI calls into,
just not driven by simulated taps.

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
   `sherpa_onnx`, `http`, `crypto`, `image`, and `flutter_tesseract_ocr`
   (pinned to the git commit in this repo's `pubspec.yaml` — the pub.dev
   release fails to build on Android; see "On-device Arabic OCR" below).
3. Declare `assets/tessdata_config.json` (copy the file itself too) in the
   host's `pubspec.yaml` under `flutter: assets:` — `flutter_tesseract_ocr`
   reads it unconditionally regardless of where trained-data comes from.
4. Add the iOS `Info.plist` keys (`NSMicrophoneUsageDescription`,
   `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`), the
   Android manifest permissions (`RECORD_AUDIO`, `CAMERA`, `INTERNET`) — see
   below — and, only if also targeting macOS,
   `com.apple.security.network.client` in that platform's entitlements
   (iOS/Android need no equivalent). If the host also needs to run OCR on an
   Apple Silicon iOS simulator, copy this repo's `ios/Podfile` post_install
   block and the three `EXCLUDED_ARCHS[sdk=iphonesimulator*]`/
   `ARCHS[sdk=iphonesimulator*]` build settings in
   `ios/Runner.xcodeproj/project.pbxproj` — both are scoped to the simulator
   SDK only and do not affect device builds (see "On-device Arabic OCR").
5. Implement `ActionDraftHandler` once, mapping `AiActionDraft.type` to the
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
6. Register `AiIntakeBinding(actionDraftHandler: () => YourHandler())` on
   whatever routes push `VoiceEntryPage` / `ImageEntryPage` / `ReviewPage`
   (see `app/app_routes.dart` for the exact wiring pattern to copy).
7. Nothing else for STT or OCR — `WhisperModelProvisioner` and
   `TesseractModelProvisioner` each download, verify, and install their own
   model files on first use (see the two "App-managed on-device Arabic ..."
   sections below); there is no setup step to run for either. Decide
   whether to keep `RuleBasedArabicTextReviewer` / `RuleBasedActionDetector`,
   or swap in better implementations behind the same contracts — nothing
   else in the module needs to change either way.

Nothing else is required: the module owns its own models, its own state
machine, and its own on-device adapters.

## What is real vs. stubbed in this milestone

| Piece | Status | Notes |
|---|---|---|
| Audio recording | **Real** | `record` package, actual mic capture, real permission flow, real amplitude/duration streams |
| Local clip playback | **Real** | `audioplayers`, plays the just-recorded file only — no relation to the old chat player |
| Camera/gallery capture | **Real** | `image_picker`, real permission flow, resolution capped at 2000px |
| Arabic speech-to-text | **Real, on-device, app-managed setup** | Whisper tiny (multilingual) via sherpa-onnx; `WhisperModelProvisioner` downloads/verifies/installs the model on first use, no cloud call at inference, no manual step; falls back to an honest stub only if setup was skipped entirely |
| Arabic OCR | **Real, on-device, app-managed setup** | Tesseract 4 (LSTM) via `flutter_tesseract_ocr`; `TesseractModelProvisioner` downloads/verifies/installs the model on first use, no cloud call, no manual step; a genuine recognition failure degrades to an honest empty result (not a hard failure) so manual entry stays possible; falls back to an honest stub only if setup was skipped entirely |
| Arabic text normalization | **Real, narrow** | Tatweel removal + whitespace collapse only, with protected-entity detection (emails/amounts/dates/IDs). Not a grammar/spelling model. |
| Action detection | **Real, rule-based** | Arabic keyword/pattern matching for the four types, field extraction via simple regex/context windows. Not ML; `confidence` is always `null`. |
| Action drafts + preview | **Real (as data)**, demo preview only | Drafts are real, inspectable objects; the preview screen never submits anything |

## What another project must still supply to get real AI

- **STT and OCR setup are both fully app-managed as of this milestone**, but
  a production host should still decide: model size trade-offs (Whisper
  `tiny` vs. `base`/`small`; Tesseract `tessdata_fast` vs. `tessdata`/
  `tessdata_best` — swap the URLs/hashes/sizes in the respective
  `*ModelSpec`, same provisioner code either way), whether to ask the user's
  consent before a cellular download (this POC downloads unconditionally on
  first need — see README_AI_INTAKE.md "Open POC decisions"), and whether
  Wi-Fi-only download is required for a production release.
- Real-device OCR verification: this milestone verified two simulators
  (iOS 17.5, Android API 33), not a physical phone — see "On-device Arabic
  OCR" above for exactly what that means and the confirmed iOS-simulator
  architecture gap.
- Optionally, a real grammar/spelling model behind `ArabicTextReviewer` if
  the narrow rule-based normalization here proves insufficient — the next
  milestone after this one, per this milestone's own scope.
- Model licensing/provenance/update-strategy decisions before bundling any
  of the above — none of this POC fetches a model from an undocumented or
  unpinned source at runtime.

## Minimum platform notes

- iOS: `record`/`image_picker`/`permission_handler` in current versions
  target iOS 13+; this repo's `ios/Flutter/AppFrameworkInfo.plist` deployment
  target should be checked against that if raised in a future milestone.
  **iOS Simulator on Apple Silicon has a confirmed gap for OCR specifically**
  (SwiftyTesseract has no arm64-simulator slice, and iOS 26's simulator
  runtime dropped x86_64/Rosetta) — see "On-device Arabic OCR" above for the
  workaround and its limits. This does not affect real devices.
- Android: `minSdkVersion` is left at Flutter's default (currently 23+ for
  this Flutter version); `record`/`image_picker`/`permission_handler` are
  compatible with that floor. `android/app/src/main/AndroidManifest.xml`
  now declares `INTERNET` (needed for the one-time model download; it was
  previously only in the debug/profile manifests Flutter adds for its own
  tooling, which are not part of a release build).
- Both platforms' OCR support is now genuinely device/simulator-verified
  (not just plugin-constraint-derived) — see "On-device Arabic OCR" above
  for exactly what ran where. STT verification remains as documented in its
  own section (macOS + iOS build only, no physical phone).
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
- OCR intentionally does **not** mirror STT's hard-failure behavior: a real
  engine exception during transcription routes to `AiIntakeStep.failure`
  (retry-only), but a real engine exception during OCR is caught inside
  `TesseractArabicOcrExtractor` and turned into an honest empty result that
  still reaches the editable review screen. This is deliberate — this
  milestone explicitly requires manual entry to remain possible after a
  recognition failure — not an inconsistency with the STT adapter.
- `flutter_tesseract_ocr` is pinned to a git commit, not the pub.dev release
  (see pubspec.yaml and "On-device Arabic OCR" above) because the published
  version fails to build on Android. Re-evaluate this pin if/when a fixed
  version reaches pub.dev.
