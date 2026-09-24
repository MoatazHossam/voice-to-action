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
        status_banner.dart          # real/stub/unsupported/error label
        waveform_bar.dart           # live amplitude visualization
        recorder_panel.dart         # idle/permission/recording/preview/failure views
        image_input_panel.dart      # idle/preview views
        processing_panel.dart       # honest progress (measured or indeterminate)
        review_panel.dart           # extraction summary, editable text, corrections
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
        stub_speech_transcriber.dart     # STUB — labeled, not real AI
        stub_image_text_extractor.dart   # STUB — labeled, not real AI
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
```

### Deviation from the literal file list in README_AI_INTAKE.md

The README sketches one `ai_intake_page.dart`. This build instead ships
`voice_entry_page.dart`, `image_entry_page.dart`, and `review_page.dart`,
because the ask (idle voice screen, idle image screen, and a *shared*
review screen) is naturally three routed screens, not one page with an
internal chooser. All three share the *same* `AiIntakeController` instance
(registered with `fenix: true` so it survives across the three routes) —
the module/dependency boundaries the README cares about are unaffected.

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
   `audioplayers`, `image_picker`, `permission_handler`, `path_provider`.
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
6. Decide whether to keep this POC's `StubSpeechTranscriber` /
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
| Arabic speech-to-text | **Stub** | Explicitly labeled; returns `TextExtraction.stub(...)`, never invented text |
| Arabic OCR | **Stub** | Same honesty contract as STT |
| Arabic text normalization | **Real, narrow** | Tatweel removal + whitespace collapse only, with protected-entity detection (emails/amounts/dates/IDs). Not a grammar/spelling model. |
| Action detection | **Real, rule-based** | Arabic keyword/pattern matching for the four types, field extraction via simple regex/context windows. Not ML; `confidence` is always `null`. |
| Action drafts + preview | **Real (as data)**, demo preview only | Drafts are real, inspectable objects; the preview screen never submits anything |

## What another project must still supply to get real AI

- An on-device Arabic STT engine behind `SpeechTranscriber` (README
  suggests evaluating a small multilingual local Whisper build first).
- An on-device Arabic OCR engine behind `ImageTextExtractor` (evaluate
  Arabic Tesseract or a vetted native OCR SDK — do not assume ML Kit v2
  supports Arabic).
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
- Recorded clips and picked images are not proactively deleted after a
  session ends (retention policy is an open POC decision, flagged inline
  in `AiIntakeController.discardClipAndRetry`).
- Multi-block OCR reading order, handwriting, and OS share-sheet image
  ingestion are all out of scope, as called out in README_AI_INTAKE.md.
