# Workout App — Project State

> **Purpose:** Living document tracking every task performed on this project.
> Read this file at the start of any new session to restore context. Update it
> after every meaningful change.
>
> **Last updated:** 2026-11-18 (Material 3 + Hero animation pass)
> **Session model:** Each new feature/bugfix session appends to §5 Task Log.

---

## 1. Project Overview

Flutter workout app (`workout_app/`) with pose tracking, exercise logging, and progress analytics.

### 1.1 Pose Tracking screen
- Detects exercises from gallery images / camera photos (Gemini AI Vision + ML Kit)
- Tracks skeletal landmarks **in real time** on:
  - **Web (Chrome):** TensorFlow.js MoveNet (SinglePose Lightning), weights bundled locally
  - **Android/iOS:** Google ML Kit pose detection (single-image + streaming camera modes)
- Continuous whole-video/stream exercise identification (re-evaluated every frame): squat, bicep curl, push-up (torso orientation distinguishes curl vs push-up)
- Dynamic rep counter labeled by the identified exercise (e.g. "BICEP CURL COUNTER") instead of a hardcoded squat label
- Live angles: knee angle and elbow angle; deepest knee/elbow bend surfaced in the identification banner
- Rep counting (knee-angle hysteresis for squats; elbow flexion cycles for curls/push-ups) with resets on new video/replay/live start
- Video playback with seek slider, replay-at-end (no looping)

### 1.2 Exercise Logger screen (Progress & history)
- History tab: per-session set logs (weight, reps, duration)
- Progress graph tab (Daily / Weekly / Monthly timeframe filters):
  - Summary banner (total volume, time recorded, total reps) for the selected timeframe
  - **Overall Exercise Progress**: bar/line/area/donut-pie visualizations over timeframe bins
  - **Category-Wise Distribution**: volume/time share per category with **set splits** showing per-session segmented bars — each set labeled `S# <weight> Rep-<reps> time:<sec>s` (segments sized by set duration)
  - **Export Data**: exports the **currently selected timeframe's column data only** to `.csv` or `.pdf`

**Key paths:**

| Path | Role |
|---|---|
| `lib/screens/pose_tracking_screen.dart` | Pose Tracking UI, frame-sampling tracker, dynamic rep counter, knee/elbow angles, continuous exercise classifier |
| `lib/screens/exercise_logger_screen.dart` | Exercise logger, history, progress graphs (bars/line/area/pie), category set splits, timeframe-scoped export trigger |
| `lib/services/pose_analysis_service.dart` | ML Kit detectors (single + streaming), Gemini analysis, `detectFromVideoFrameBytes` |
| `lib/services/export_service.dart` | Progress export: builds CSV (segregated rows/columns) and PDF (A4 tables) for timeframe snapshot; saves to documents (native) or triggers browser download (web) |
| `lib/models/workout_models.dart` | `WorkoutSessionLog` / `ExerciseSetLog`; `totalVolume` = sum of set weights as singular values (not multiplied by reps) |
| `lib/web/web_pose.dart` | Conditional export (web impl ↔ stub) |
| `lib/web/web_pose_web.dart` | MoveNet via `dart:js_interop` + `package:web`; hidden `<video>` sync; detector init |
| `lib/web/web_pose_stub.dart` | No-op stub for non-web builds |
| `lib/widgets/pose_skeleton_painter.dart` | CustomPainter drawing 13 landmarks + connections |
| `web/index.html` | Loads local `js/tf.min.js` + `js/pose-detection.min.js` |
| `web/js/` | Bundled TF.js 4.22 + pose-detection 2.1.3 (no CDN) |
| `web/models/movenet_lightning/` | Bundled MoveNet weights (model.json + 2 shards, ~4.7 MB) |
| `pubspec.yaml` | Deps include: camera, video_player, image_picker, google_mlkit_pose_detection, web, path_provider, **pdf** |

**Platform support matrix:**

| Feature | Web | Android/iOS | Windows |
|---|---|---|---|
| Image analysis (Gemini) | ✅ | ✅ | ✅ |
| Video real-time tracking | ✅ MoveNet | ✅ ML Kit | ❌ |
| Live camera tracking | ❌ (clear error shown) | ✅ | ❌ |
| Rep counting / angles / ID | ✅ | ✅ | ❌ |
| Progress graphs & set splits | ✅ | ✅ | ✅ (UI) |
| Export CSV/PDF (timeframe-scoped) | ✅ (browser download) | ✅ (documents dir) | ✅ (documents dir) |

---

## 2. Architecture Decisions

1. **Web pose engine = MoveNet via JS interop.** ML Kit is mobile-only.
   Loaded from local bundle (user's network blocks CDNs:
   `cdn.jsdelivr.net`, `storage.googleapis.com`, `tfhub.dev`).
2. **Hidden `<video>` element for web detection.** Flutter's `video_player`
   on web renders its `<video>` inside a **shadow DOM** —
   `document.querySelectorAll('video')` can't reach it. Instead we create our
   own hidden `<video>` fed with the picked file's blob URL (`XFile.path`),
   kept in sync with the Flutter player (`syncPlayback`, 400 ms drift
   correction). MoveNet's `estimatePoses()` accepts `HTMLVideoElement` directly.
3. **No `RepaintBoundary.toImage()` for video on web.** It cannot capture
   platform views → frames come out blank → detection silently fails.
   Mobile still uses boundary capture → PNG → ML Kit.
4. **Videos never go to the Gemini API.** Base64-encoding whole videos hung
   for minutes. Videos get an instant placeholder result card; images still
   use Gemini (45 s timeout added).
5. **Per-frame re-detection = subject-agnostic.** Nothing cached between
   frames; skeleton re-locks onto any subject automatically. Classification and
   angle computations run on every frame so the exercise name/counters update
   throughout the whole video/stream.
6. **Rep counting:** squats via knee-angle hysteresis (< 110° down, > 155° up,
   5-sample smoothed). Curls/push-ups via elbow flexion cycles; torso
   orientation (shoulder–hip roughly horizontal) distinguishes push-up from
   curl. Dynamic counter displays the rep count for the currently identified
   exercise.
7. **Conditional import pattern** (`web_pose.dart`) keeps native builds
   unaffected by web-only code.
8. **Volume capture rule:** `totalVolume` = Σ set weights as logged (singular),
   **not** multiplied by reps (e.g. a 30 kg set contributes 30 kg). Progress
   graphs, summaries, and exports all follow this rule.
9. **Timeframe-scoped export:** Export builds a snapshot from the currently
   selected view (Daily = last 7 days, Weekly = last 28 days, Monthly = last
   180 days) — only that timeframe's aggregated bins/rows and matching sessions
   are included.

---

## 3. Current State

**UI/theme:** Material 3 theme applied globally (seeded vibrant orange scheme,
M3 typography + component themes), Material 3 `NavigationBar`, and route-based
navigation with Hero shared-element transitions on the major flows.

**Status:** Pose tracking working on Chrome (user-verified 2026-11-17). Logger
progress-graph features (set-split weight/reps/time, visualizations, timeframe
export) implemented 2026-11-18. Material 3 runtime regression fixed 2026-11-18:
Home now loads and bottom navigation works. Final validation:
`flutter analyze --no-pub` no issues, `flutter test` 2/2 passed,
`flutter build web --release` success (Wasm dry run succeeded).

**Pose tracking (web/mobile):**
- Real-time skeleton over playing video / live camera (mobile) ✅
- Knee + elbow angles, dynamic exercise-labeled counter, continuous ID ✅
- MoveNet loads from local bundle ✅
- Seek slider with time labels, replay-at-end (no looping) ✅

**Progress / logging:**
- Volume = singular set weight (not × reps) across model, graphs, history, export ✅
- Category set splits with `S# <weight> Rep-<reps> time:<sec>s` per set ✅
- Overall graph views: Bars / Line / Area / Pie (donut w/ legend) ✅
- Export Data button: CSV & PDF for selected timeframe only (Daily/Weekly/Monthly) ✅

**Known limitations:**
- Live camera tracking is mobile-only (web shows explanatory error)
- Windows desktop: no pose tracking (ML Kit/camera limitations)
- MoveNet confidence < 0.3 joints are not drawn (painter rule)
- Export on native saves to app documents directory (path shown in snackbar);
  on web it triggers a browser download
- Latest pose-tracking refinements (dynamic counter/elbow angle/continuous ID)
  and logger/export changes await user verification in-app

---

## 4. Environment / Commands

```bash
cd E:\test\workout_app
flutter pub get
flutter analyze          # expect pre-existing withOpacity infos only, 0 errors/warnings
flutter run -d chrome    # web
flutter run -d android   # mobile
flutter build web --release
```

- Flutter SDK: ^3.13.7 (Dart 3.x, wasm-capable)
- Analyzer: keep at **0 errors / 0 warnings**; infos acceptable
- Web build time ~150–195 s; use `flutter build web --release` as compile check
- PowerShell note: `flutter analyze` stderr trips PowerShell NativeCommandError;
  pipe through `Out-File` then filter, e.g.
  `flutter analyze --no-pub 2>&1 | Out-File -Encoding utf8 E:\test\analyze_out.txt`
- Workspace is not a git repo (per `E:\test`); rely on this file for state

---

## 5. Task Log

> Append-only. Format: `### <date> — <task>` with What/Why/Files/Result.

### 2026-11-17 — Replace test video with live camera squat tracking
- **What:** Replaced bundled test-video button with live camera mode
  (front camera preferred, ML Kit streaming mode, real-time skeleton + rep
  counter + knee angle + coaching feedback).
- **Files:** `pose_tracking_screen.dart`, `pose_analysis_service.dart`
  (added `streamingDetector` + `detectFromCameraImage`), `pubspec.yaml` (+camera).
- **Result:** Works on Android; crashed on web (next task).

### 2026-11-17 — Fix web crash "platform._operatingSystem"
- **What:** `dart:io` `Platform.isAndroid` throws on web. Added `kIsWeb` guard
  with clear error message; live tracking requires Android/iOS.
- **Files:** `pose_tracking_screen.dart` (`_startLiveSquatTracking`).
- **Result:** Web no longer crashes; shows explanatory error card.

### 2026-11-17 — Real-time tracking on playing video (subject-agnostic)
- **What:** Frame sampler (200 ms timer) captures video via `RepaintBoundary`
  → PNG → per-frame detection → live skeleton overlay (green) replaces static
  post-analysis skeleton. Rep counter runs on video too.
- **Files:** `pose_tracking_screen.dart` (`_startVideoFrameTracking`,
  `_captureAndTrackVideoFrame`), `pose_analysis_service.dart`
  (`detectFromVideoFrameBytes`, normalizes by full frame dims).
- **Result:** Worked on mobile path; web still static (next tasks).

### 2026-11-17 — Web: endless "analyzing" + static landmarks + dead rep counter
- **What:** Root causes: (1) whole video base64 → Gemini with no timeout;
  (2) ML Kit mobile-only → null keypoints on every web frame.
- **Fix:** Videos skip Gemini (instant placeholder card); Gemini got 45 s
  timeout; added MoveNet engine: `web/index.html` loads TF.js + pose-detection;
  `lib/web/web_pose_web.dart` (`WebPoseService`), stub + conditional export;
  `pubspec.yaml` +`web: ^1.1.0`. COCO-17 → app keypoint name mapping
  (nose→head).
- **Result:** Still failed on web (blank frames, next task).

### 2026-11-17 — Web: RepaintBoundary cannot capture platform views
- **What:** Video platform view captures blank on web → no detection.
- **Fix:** `detectFromVideoElement()` — find `<video>` in DOM, pass directly
  to `estimatePoses`. Status line surfaced in stats card (amber text).
- **Result:** Still failed — `<video>` is inside shadow DOM (next task).

### 2026-11-17 — Web: shadow DOM blocks video discovery; replay instead of loop
- **What:** `video_player` web renders inside shadow DOM. Looping requested off.
- **Fix:** Hidden `<video>` element owned by us (`setVideoSource(blobUrl)`),
  synced with Flutter player (`syncPlayback`). `setLooping(false)`,
  `_onVideoUpdate` listener, `_videoEnded` flag, REPLAY VIDEO overlay button
  (resets tracking session). Stub updated with new no-op methods.
- **Result:** Still failed — CDN blocked (next task).

### 2026-11-17 — CDN blocked → bundle TF.js + MoveNet locally
- **What:** User network blocks `cdn.jsdelivr.net` / `storage.googleapis.com`
  → "Pose model failed to load (CDN b…)".
- **Fix:** Downloaded `tf.min.js` (1.4 MB) + `pose-detection.min.js` (72 KB)
  into `web/js/`; MoveNet Lightning weights (model.json + 2 shards, 4.7 MB)
  from Kaggle into `web/models/movenet_lightning/`. `index.html` references
  local scripts; detector config: `modelUrl` (absolute via `Uri.base`) +
  `fromTFHub: false`. WebGL→CPU backend fallback added.
- **Result:** TF loaded (backend: webgl) but detector init failed (next task).

### 2026-11-17 — TypeError: "MoveNet": type 'String' is not a subtype of 'JSObject'
- **What:** `poseDetection.SupportedModels.MoveNet` is a JS **string**, not an
  object. Interop typing was wrong.
- **Fix:** `external JSString get MoveNet;` and
  `createDetector(JSAny? model, JSAny? config)`.
- **Result:** ✅ **User confirmed working.** Console: backend webgl → detector
  ready → skeleton tracks, reps count.

### 2026-11-17 — Exercise banner + seek slider
- **What:** (1) "IDENTIFIED FROM LIVE TRACKING" banner above the Live Video
  Exercise card — classifies squat (knee < 110° / reps), bicep curl (elbow
  flexion cycles), push-up (horizontal torso); shows rep tallies + deepest
  knee bend; resets on new video/replay. (2) Seek slider under video with
  current/total time labels (`ValueListenableBuilder`, tabular figures);
  seek re-syncs hidden web video via drift correction.
- **Files:** `pose_tracking_screen.dart` (`_classifyExercise`,
  `_buildLiveIdentificationBanner`, slider in `_buildMediaPreview`,
  `_formatDuration`, state resets in `_pickVideo`/`_replayVideo`).
- **Result:** Build clean (0 errors/warnings); awaiting user verification.

### 2026-11-18 — Pose tracking: dynamic counter, elbow angle, continuous identification
- **What:** Replaced hardcoded "SQUATS COUNTED" with a dynamic counter labeled
  by the identified exercise (e.g. `BICEP CURL COUNTER`, `PUSH-UP COUNTER`),
  showing the rep count for that exercise. Added live elbow angle
  (shoulder–elbow–wrist, averaged) alongside knee angle in the stats card and
  deepest-elbow-bend in the banner. Classification now runs continuously on
  every frame for **both** video and live camera, re-evaluating throughout the
  whole stream: knee dips → squat, elbow flexion cycles → curl (upright torso)
  or push-up (horizontal torso via `_isTorsoHorizontal`). Separate push-up/curl
  counts; unified `_resetLiveTrackingState()` on pick/replay/start.
- **Files:** `lib/screens/pose_tracking_screen.dart` (`_computeElbowAngle`,
  `_classifyExercise`, `_isTorsoHorizontal`, `_counterLabel`,
  `_identifiedRepCount`, `_buildLiveStatsCard`, live/video frame handlers).
- **Result:** `flutter analyze` on file: 0 issues.

### 2026-11-18 — Logger progress: singular-weight volume, set splits, visualizations, timeframe export
- **What:**
  - **Data rule:** `WorkoutSessionLog.totalVolume` now sums set weights as
    singular values (e.g. 30 kg set = 30 kg, not 30 × reps); graphs, summary,
    history, and exports use this consistently.
  - **Category set splits:** per-session segmented bars under each category,
    each set segment sized by duration and labeled
    `S# <weight> Rep-<reps> time:<sec>s` (singular weight, never × reps).
  - **Overall graph visualizations:** selectable `Bars / Line / Area / Pie`
    (donut pie with per-bin legend and total) for the selected timeframe.
  - **Export Data:** button under timeframe selector exports **only the
    currently selected view's column data** (Daily/Weekly/Monthly) to `.csv`
    or `.pdf`. CSV is fully segregated into sections/rows/columns: meta+summary,
    overall progress bins, category distribution, and per-set detail (Date,
    Exercise, Category, Set, Weight kg as logged, Reps, Set Duration, Rest).
    PDF is an A4 report with matching tables. Web triggers browser download;
    native saves to application documents directory.
- **Files:** `lib/models/workout_models.dart`, `lib/screens/exercise_logger_screen.dart`,
  `lib/services/export_service.dart` (new), `pubspec.yaml` (+`pdf`).
- **Result:** `flutter pub add pdf` ok. `flutter analyze` on touched files:
  0 errors/warnings (pre-existing `withOpacity` infos only).

### 2026-11-18 — Material 3 (Expressive-style) redesign + Hero animations app-wide
- **What:**
  - Added `lib/theme/app_theme.dart`: full Material 3 theme (seeded
    `DynamicSchemeVariant.vibrant` dark/light `ColorScheme`, Material 3
    typography, expressive-shaped component themes for buttons, cards,
    chips, segmented buttons, nav bar, dialogs, sheets, snackbars, tabs).
  - `main.dart` now wires `theme`/`darkTheme` with `ThemeMode.dark`.
  - `AppColors` remapped to Material 3 tonal roles from the same orange seed.
  - Rebuilt `main_shell.dart` around a real `Navigator` + Material 3
    `NavigationBar` (5 destinations). Navigation is now route-based so
    Flutter `Hero` transitions actually fly between screens.
  - Converted UI to current M3 widgets across every screen: `SearchBar`,
    `FilterChip`, `SegmentedButton`, `FilledButton`/`FilledButton.tonal`,
    themed `TabBar`, `Chip`; replaced deprecated `withOpacity` with
    `withValues(alpha:)`.
  - Added shared-element Hero flights: AI generator badge (Home/Saved →
    Input), exercise name (Home → Input), saved workout card → result hero
    card, "Log Sets" button → logger exercise selector (tags centralized in
    `lib/theme/app_hero_tags.dart`).
- **Files:** `lib/theme/app_theme.dart` (new), `lib/theme/app_colors.dart`,
  `lib/theme/app_hero_tags.dart` (new), `lib/main.dart`, `lib/screens/*.dart`.
- **Result:** `flutter analyze --no-pub`: 0 errors/warnings (only the 4
  pre-existing web-interop infos). `flutter build web --release`: success.

### 2026-11-18 — Secret hygiene before GitHub push
- **What:** Removed the hardcoded Gemini API key from `gemini_service.dart` and
  `pose_analysis_service.dart`; both now read `GEMINI_API_KEY` via
  `String.fromEnvironment`. Added a clear error when the key is missing.
- **Files:** `lib/services/gemini_service.dart`,
  `lib/services/pose_analysis_service.dart`, `.gitignore`,
  `env.example.json` (new), `README.md`.
- **Result:** Real key kept only in local ignored `env.json`; no secrets staged.
  `flutter analyze --no-pub` clean; `flutter test` 2/2 passed.

### 2026-11-18 — Local env launch + navigation/video performance
- **What:** Added VS Code launch configs and `run_local.bat` so debugging passes
  `--dart-define-from-file=env.json` automatically. Reduced tab-switch lag by
  moving `NavigationBar` selection to a `ValueNotifier` (only the bar rebuilds)
  and replacing pop-then-push with a single `pushNamedAndRemoveUntil`.
- **What:** Removed the full-video `readAsBytes()` stall, preloaded TF.js/MoveNet
  when the Pose screen opens, deduplicated concurrent model loads, and removed
  stale hidden `<video>` elements on source change/dispose. Also fixed a narrow
  Pose-screen preview-button overflow and extended the tab smoke test to Pose.
- **What:** Fixed selected navigation icon reverting to Home by ignoring
  intermediate `didRemove`/`didReplace` observer events from
  `pushNamedAndRemoveUntil`; selection now follows only visible routes.
- **Files:** `.vscode/launch.json` (new), `run_local.bat` (new), `README.md`,
  `lib/screens/main_shell.dart`, `lib/screens/pose_tracking_screen.dart`,
  `lib/web/web_pose_web.dart`.
- **Result:** `flutter analyze --no-pub` clean; `flutter test` 2/2 passed;
  `flutter build web --release --dart-define-from-file=env.json` success.

### 2026-11-18 — Home light/dark theme toggle
- **What:** Added a global `ThemeController` and a Material 3 icon toggle in the
  Home header. The app starts dark; toggling switches both the seeded
  `MaterialApp` theme and every custom `AppColors` tonal role to light/dark.
- **What:** Converted `AppColors` constants to brightness-aware getters, removed
  stale `const` usages across screens, and replaced remaining hard-coded dark
  card/gradient colors with dynamic roles.
- **Files:** `lib/theme/theme_controller.dart` (new), `lib/theme/app_colors.dart`,
  `lib/main.dart`, `lib/screens/home_screen.dart`, all other `lib/screens/*.dart`,
  `test/app_smoke_test.dart`, `README.md`.
- **Result:** `flutter analyze --no-pub` clean; `flutter test` 2/2 passed;
  smoke test verifies toggling dark → light → dark.

---

## 6. Gotchas / Lessons Learned

1. **`dart:io` on web** throws `Unsupported operation: platform._operatingSystem`
   — always guard with `kIsWeb` before `Platform.*`.
2. **`RepaintBoundary.toImage()` cannot capture platform views** (video,
   camera on web) — captures come out blank, no error.
3. **`video_player` web `<video>` lives in shadow DOM** — not findable via
   `document.querySelectorAll`; own a separate element instead.
4. **CDN scripts may be blocked** (corporate/firewalled networks) — bundle
   TF.js + model weights in `web/`; TF.js serves stale errors otherwise.
5. **`SupportedModels.MoveNet` is a JS string** — type it `JSString` in
   `dart:js_interop`, not `JSObject`.
6. **ML Kit pose detection** works only on Android/iOS; `PoseDetectionMode.stream`
   (not `.streaming`); `InputImageRotation.rotation0deg` (not `rotation000deg`).
7. **Stale web session after big changes:** user saw an old error string that
   no longer existed in code — always `flutter clean` + full restart +
   Ctrl+Shift+R before debugging confusing reports.
8. **Gemini video uploads** (base64 whole file, no timeout) hang for minutes —
   never send videos; use local per-frame tracking for motion analysis.
9. **PowerShell + flutter CLI:** stderr on success trips PowerShell; buffer
   output to a file and grep it instead.
10. **Analyzer budget:** pre-existing `withOpacity` infos in other screens are
    acceptable — leave them; fix all new errors/warnings immediately.
11. **Web downloads via `dart:js_interop`/`package:web`:** convert byte buffers
    to `Uint8List` and pass `[uint8List.toJS].toJS` to `Blob` (a raw
    `List<int>`/`toJS` on it won't compile); keep `kIsWeb` branches separate
    from `dart:io` file writes.
12. **Volume semantics:** "weight as singular" means do **not** multiply by reps
    when aggregating volume; display the logged weight per set in splits/exports.

---

## 7. Next Steps / Backlog

- [ ] User verification: pose-tracking dynamic counter + elbow angle + continuous
      identification (video & live camera)
- [ ] User verification: logger set splits (weight/reps/time), graph
      visualizations (Bars/Line/Area/Pie), and timeframe-scoped CSV/PDF export
- [ ] Web fallback for live camera (getUserMedia + MoveNet) instead of error
- [ ] Persist rep counts / session history (integrate with workout_state) where
      not already persisted
- [ ] Form feedback based on tracked metrics (depth %, tempo, asymmetry)
- [ ] Consider multi-person detection (MoveNet MultiPose) for videos with
      several subjects
- [ ] Clean up pre-existing `withOpacity` deprecation infos
