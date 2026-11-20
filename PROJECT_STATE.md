# Workout App — Project State

> **Purpose:** Living document tracking every task performed on this project.
> Read this file at the start of any new session to restore context. Update it
> after every meaningful change.
>
> **Last updated:** 2026-11-20 (security review, signed production APK,
> GitHub release v1.0.0 published, Android 16 startup-crash fix verified;
> 55/55 tests passing, repo clean and pushed)
> **Session model:** Each new feature/bugfix session appends to §5 Task Log.

---

## 0. Current State Snapshot (2026-11-20)

- **Git / GitHub:** `workout_app` is a Git repository. `origin` is
  `https://github.com/insect-cs/Workout_Tracking_App.git`, branch `main`.
  All work is committed and pushed; working tree is clean and `main` is in sync
  with `origin/main`. Two release commits sit on top of `1a4ed59`:
  `e53a47e` "Release v1.0.0: local-first sessions, pose tracking and signed
  Android build" and `717e615` "Fix release build crash on Android 16: preserve
  Room WorkDatabase constructor". Annotated tag `v1.0.0` points at `717e615`.
  GitHub release **v1.0.0 — Workout Tracking** is published (not draft, not
  prerelease) with `app-release.apk` and `app-release.apk.sha256`:
  https://github.com/insect-cs/Workout_Tracking_App/releases/tag/v1.0.0
- **Navigation / UI:** Global Material 3 expressive theme with seeded palette
  and app-wide Hero flights. The app now starts on a **single-session login
  gate** (`Continue as guest` / `Continue as new user`); after sign-in the root
  switches to `MainShell`, so there is no back route to login. Home has a
  **Sign out** action that returns to login while keeping the session on disk.
  Route-based bottom nav has **7 custom-drawn, name-specific animated glyphs**
  (Home / Plan / Calories / Generate / Saved / Logger / Pose). Home header has
  a light/dark toggle and an **Auto color scheme** button cycling six curated
  seeds; every `AppColors` role derives from the active `ColorScheme`. **Diet**
  and **Keys** are Home cards (routes `/diet` and `/keys`), kept out of the
  bottom bar. The **Plan** section now has a third **History** tab; generated
  weekly/single-day results can be saved there from the end of the result view.
- **Local-first persistence:** Ordinary app state is stored on-device as JSON
  in an **encrypted Hive CE box** via `lib/services/local_store.dart`. The
  32-byte AES key for that box is generated on first run and stored in
  `flutter_secure_storage` alongside API keys. This covers saved workouts,
  current workout, exercise logs, selected tab, diet days/goals/entries, theme
  mode/palette, Plan forms/result/tab/history, Calories form/results/tab, and
  the Workout input draft. `shared_preferences` is no longer used. All ordinary
  keys are namespaced to the active session (`guest` or `new_user`); only the
  session marker is global. Legacy unnamespaced data was migrated to `guest`.
- **Fonts / runtime network:** `Inter` and `SpaceGrotesk` TTFs are bundled in
  `assets/fonts`, and `main()` sets
  `GoogleFonts.config.allowRuntimeFetching = false`, so no `fonts.gstatic.com`
  requests are made. TF.js/MoveNet/model files were already local. Per user
  decision, YouTube scraping (native) and YouTube thumbnails are still allowed
  to use the network; web keeps the search-URL fallback to avoid CORS errors.
  User-initiated `url_launcher` browser opens also remain.
- **Plan generator:** Weekly + Single-day tabs collect goal, experience,
  equipment, schedule and optional exercise types/combinations (full
  deselection supported; empty values sent as "no preference"). CTAs
  `Generate Plan for a week` / `Generate Plan for a single day` (Single-day
  schedule defaults to **Day 1**) render the plan inline with YouTube demo
  cards resolved via `YouTubeService`. Both results end with **Save to
  History**, which stores that result in the Plan section's new **History**
  tab (newest first, reopen/delete actions); History is namespaced per session,
  so it works the same for guest and new user. AI-gated.
- **Calories:** Weekly estimate + BMI tabs collect Age/Gender/Height/Weight
  (plus Activity dropdown on Weekly). CTAs `Generate Estimate` /
  `Generate results`. Locally computed Mifflin-St Jeor BMR/TDEE and BMI values
  are sent to Gemini to keep the narrative accurate; results render inline.
  AI-gated.
- **Diet:** Date picker defaults to today; 24 one-hour slots; editable daily
  calorie and water goals. **Food** activity: item, veg/non-veg, quantity,
  optional photo, Gemini **Validate** (calories + nutrients inline, Save
  deducts calories from the calorie goal). **Water** activity: ml amount,
  Save deducts from the water goal. State is held by `DietState` and persisted
  per date via the device-local store.
- **AI keys (new, runtime):** No compile-time `GEMINI_API_KEY` requirement.
  Every AI action uses a shared `ensureAiAccess` gate: with no validated key it
  opens a dialog to paste a key and pick an endpoint/model (four Gemini presets
  or a custom base URL + model). **Validate** makes a real test request and
  only stores the key on HTTP 200; missing/invalid/expired/unreachable keys
  show a clear error. Valid keys are persisted with `flutter_secure_storage`.
  The `/keys` page shows the active endpoint/model and a **fixed-width full
  mask** (`••••••••••••`) with **no reveal button, no characters, and no length
  hint**. It still supports switching endpoints and deleting keys; deleting
  the active key forces re-auth. The active endpoint is displayed because
  results vary by model/endpoint.
- **API-key layout fixes (2026-11-20):** `ApiKeyDialog` now computes a finite,
  screen-fitting width via `LayoutBuilder` + `responsiveDialogWidth`, removes
  `Expanded` from the key row, and gives the **Validate** button an explicit
  finite width. This fixed `BoxConstraints forces an infinite width` on web.
- **Responsive dialogs:** Added shared `lib/widgets/app_dialog.dart` with
  `AppDialog` + `responsiveDialogWidth`. Used by the API-key dialog, remove-key
  confirmation, and clear-history confirmation so dialogs stay on screen when
  the web dialog theme injects `BoxConstraints.expand()`.
- **Key hygiene:** Keys are no longer placed in request URLs (`?key=`). All
  Gemini-compatible calls now send `x-goog-api-key` via shared
  `geminiHeaders(key)`. UI continues to show only the full-width `maskedKey`,
  never the raw value.
- **Gemini URL fix:** `AiEndpoint.generateUrl` no longer duplicates
  `:generateContent` when a custom base URL is pasted as a full endpoint URL.
- **YouTube web fix:** `YouTubeService` skips direct YouTube scraping on web
  (`kIsWeb`) and returns a search URL, removing CORS console errors.
- **Pose tracking:** Web uses TensorFlow.js MoveNet with bundled model files;
  Android/iOS use ML Kit. Landmark tracking, rep counting, angles, continuous
  exercise identification, seek slider and dynamic rep counter run per frame.
  Videos are never uploaded to Gemini; still-image analysis uses the active
  validated key.
- **Configuration / security:** Real keys are entered at runtime and stored in
  secure storage — no real keys in tracked files, tokens, or credential files.
  `env.json` / `env.example.json` remain but are no longer required by AI
  features.
- **Validation:** `dart format lib test` clean, `flutter analyze lib test`
  **No issues found**, `flutter test` **55/55 passed**, and
  `flutter build web --release` succeeded after the Plan-History change.
  Built `build/web/assets/assets/fonts/` contains the bundled TTFs. Signed
  Android release APK built and verified after the R8 fix; 55/55 tests still
  pass. `flutter config --enable-windows-desktop` was restored after the
  temporary build workaround.
- **Android release / signing:** Unique app ID `com.insectcs.workoutapp`,
  launcher label "Workout Tracking", version 1.0.0 (code 1), minSdk 24 /
  targetSdk 36. Release signing reads git-ignored `android/key.properties`,
  which points at git-ignored `android/app/release-keystore.jks` (alias
  `workoutapp`, RSA 2048, valid to 2054-04-07, cert SHA-256
  `c12b84b5dc519c096d3bf1aa3c70c88e747dd0a56c11cf6c0ffc962c7bd00c63`).
  APK SHA-256 (current fixed build):
  `d837f75266bf39af269e429d985f6108c1dd3cbe797cfd77e39cbc02615b8cc2`.
  Backup outside the repo: `E:\test\keystore-backup\2026-11-20\` and
  `E:\test\keystore-backup\workout-tracking-keystore-2026-11-20.zip`.
- **Release build workarounds:** `android/build.gradle.kts` adds explicit
  `androidx.concurrent:concurrent-futures:1.2.0` to every Android module
  (CameraX 1.5 + Gradle 9 compile-classpath bug). `android/gradle.properties`
  sets `kotlin.incremental=false` (cross-drive C:/E: cache bug).
  `android/app/proguard-rules.pro` keeps Room `*_Impl` constructors and
  WorkManager classes (AGP 9 R8 startup-crash fix). Windows builds need
  Developer Mode for plugin symlinks, or Flutter's Windows-desktop flag
  temporarily disabled.
- **Docs / licensing:** `README.md` rewritten for users (features, install,
  bring-your-own-key, privacy, build notes). Added MIT `LICENSE` (copyright
  2026 insect-cs) and third-party `NOTICE`. Removed unreferenced demo media
  with unverifiable licensing; `.gitkeep` files retained.
- **End-of-day save:** All 2026-11-20 work is captured above and in §5 Task
  Log. Everything is committed, pushed and released. The authoritative
  validation for this saved state is analyze clean, 55/55 tests passing, a
  signed APK whose release download hash was re-verified, and user confirmation
  that the app launches correctly on Android 16.
- **Local run:** `flutter run` (no `--dart-define` needed now); VS Code configs
  / `run_local.bat` still pass `--dart-define-from-file=env.json` but it is no
  longer required.
- **Remaining backlog:** see §7 (web live camera, persistence, form feedback,
  multi-person detection, and final user verification).

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
10. **Local-first state:** Secrets use `flutter_secure_storage` (API keys and
    the Hive AES key); all other data uses `LocalStore` + an encrypted Hive CE
    box. Keys are namespaced per session, so guest and new user can never
    coexist. Screens read synchronously from the in-memory cache after startup
    load, and writes are fire-and-forget (`unawaited`) from existing void
    setters/callbacks.
11. **Bundled Google Fonts:** `allowRuntimeFetching = false` requires matching
    local assets; `Inter-*.ttf` and `SpaceGrotesk-*.ttf` are checked into
    `assets/fonts` and declared in `pubspec.yaml`. Without the assets, styles
    throw/emit errors when runtime fetching is disabled.
12. **YouTube network policy:** User explicitly allowed YouTube scraping and
    YouTube thumbnails to access the network. Native scraping remains; web
    avoids direct scraping (CORS) and returns a YouTube search URL. Gemini /
    custom BYOK endpoints remain the only other app-originated network calls.
13. **Single session rule:** `SessionState` is the only authority for profile
    selection. `signIn()` deletes the other namespace and gives a new user a
    clean partition; `signOut()` only flips the session marker. The login screen
    disables both options until the stale session's delete icon is used.

---

## 3. Current State

**UI/theme:** Material 3 theme applied globally (seeded vibrant orange scheme,
M3 typography + component themes), Material 3 `NavigationBar`, and route-based
navigation with Hero shared-element transitions on the major flows.

**Status:** Pose tracking working on Chrome (user-verified 2026-11-17). Logger
progress-graph features (set-split weight/reps/time, visualizations, timeframe
export) implemented 2026-11-18. Material 3 runtime regression fixed 2026-11-18:
Home now loads and bottom navigation works. Local-first persistence and bundled
fonts added 2026-11-20. Single-session login, full key masking, and Plan
History added the same day. Signed Android release APK published as GitHub
v1.0.0 the same day; an Android 16 launch crash caused by AGP 9 R8 was fixed and
the user confirmed the app works correctly. Latest validation (authoritative):
`flutter analyze lib test` no issues, `flutter test` 55/55 passed,
`flutter build web --release` succeeded, release APK signature and download
hash verified.

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
- Local-first, not fully offline: Gemini/BYOK calls, YouTube scraping/
  thumbnails, and user-opened links still require network.
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
- Workspace root `E:\test` is not a repo, but `E:\test\workout_app` **is** a Git
  repo (`main`, origin configured). Use Git for snapshots; keep this file as the
  human-readable context companion.

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

### 2026-11-18 — Project state snapshot and GitHub verification
- **What:** Added §0 “Current State Snapshot” with the final feature, security,
  validation, and local-run status for today's session.
- **Result:** Verified `origin/main` contains theme commit `8ddc2e4`, no real
  API keys are tracked, and `env.json` remains ignored by Git.

### 2026-11-19 — New Plan section (weekly + single day) with Gemini-gated generation
- **What:** Added a sixth bottom-nav destination, **Plan**. The screen has
  Weekly and Single day tabs; each keeps its own form state and collects
  Primary Goal (fat loss / weight gain / muscle building / raw strength /
  general endurance), Experience Level (beginner / intermediate / advanced),
  Equipment (bodyweight only / dumbbells / resistance bands / full commercial
  gym), Schedule (2–7 days per week) and Exercise Types (Full Body / Push /
  Pull / Legs / Upper / Lower / Rest-Light Cardio, multi-select).
  The bottom CTA changes to `Generate Plan for a week` on the Weekly tab and
  `Generate Plan for a single day` on the Single day tab. Pressing it checks
  the compile-time Gemini API key first: when absent, no request is made and a
  clear error banner is shown; when present, Gemini returns a structured plan
  which is rendered inline (per-day cards with exercises, sets, reps, rest and
  coaching cues) with an edit/regenerate action.
  Refinement: the Single day tab's Schedule is a Day 1–Day 7 selector that
  defaults to **Day 1**; that label is sent to Gemini and shown on the result.
  The Weekly tab keeps its 2–7 days/week slider.
  Also added **Exercise Combinations** to both tabs: presets Chest+Tricep,
  Back+Bicep, Legs+Shoulder, plus a Custom plus-separated input
  (A+B+...+Nth string) with live parsed-group preview and empty-value
  validation. The combination goes into the Gemini prompt and result summary.
  Generated exercises now get accurate YouTube demonstrations: `PlanService`
  resolves every exercise through `YouTubeService` (deduplicated + parallel)
  and stores the exact watch URL on each `ExerciseModel`; the Plan result
  renders a video thumbnail card (with play overlay + external launch via
  `url_launcher`) and falls back to a "Find demo on YouTube" link if no exact
  video id could be resolved.
  Both Exercise Types and Exercise Combinations are now optional: every chip
  can be deselected (including the last one), clearing a combination is done by
  tapping the selected preset again, and Gemini receives an explicit
  "no preference" instruction instead of a forced default.
- **Files:** `lib/models/plan_models.dart` (new), `lib/services/plan_service.dart`
  (new), `lib/screens/plan_screen.dart` (new), `lib/screens/main_shell.dart`
  (new route/nav destination), `test/app_smoke_test.dart` (new tab index map),
  `test/plan_screen_test.dart` (new).
- **Result:** `flutter analyze --no-pub`: No issues found. `flutter test`: 5/5
  passed (including no-API-key error path and CTA label switching).

### 2026-11-19 — New Calories section (weekly estimate + BMI) with Gemini gating
- **What:** Added a seventh bottom-nav destination, **Calories**, with two
  tabs. The Weekly estimate tab collects Age, Gender, Height, Weight and a
  6-level Activity dropdown (sedentary → extra active); its CTA is
  `Generate Estimate`. The BMI calculate tab collects Age, Gender, Height and
  Weight; its CTA is `Generate results`. Both CTAs check the compile-time
  Gemini key first and show a clear error when it is missing.
- **Files:** `lib/models/calories_models.dart` (new, includes testable
  `CalorieMath` with Mifflin-St Jeor BMR, TDEE multipliers, WHO BMI category
  and healthy weight range), `lib/services/calories_service.dart` (new),
  `lib/screens/calories_screen.dart` (new), `lib/screens/main_shell.dart`
  (route + nav destination), `test/app_smoke_test.dart` (updated tab indices),
  `test/calories_screen_test.dart` (new).
- **Result:** Gemini receives the locally computed reference numbers so its
  narrative stays accurate; results render inline (7-day breakdown + tips for
  calories, BMI value/category/range/recommendations for BMI).

### 2026-11-19 — Auto colour scheme button + name-specific nav animations
- **What:** Added an **Auto color scheme** button (palette icon) to the Home
  header. Each tap cycles through six curated Material 3 seed colours, and the
  whole app — including every custom `AppColors` role — re-themes instantly in
  the current light/dark mode. The active palette name is shown under the
  title. All seven navigation icons are now **custom-drawn animated glyphs**
  with name-specific motion: Home shows a chimney rising off the roof and
  fading away; Plan is a calendar whose page physically turns; Calories is a
  swaying, stretching flame; Generate has stars that fade out and reappear one
  by one; Saved shoots upward then returns from below; Logger's stopwatch hand
  sweeps away from 12 and comes back; Pose's figure hand swings sideways and
  returns to rest. Every motion returns to rest and repeat taps replay it.
- **Files:** `lib/theme/theme_controller.dart` (palette list + seed/name
  notifiers), `lib/theme/app_theme.dart` (seed comes from the controller),
  `lib/theme/app_colors.dart` (all roles derived from the active `ColorScheme`
  instead of hard-coded constants), `lib/main.dart` (listens to seed changes
  and rebuilds the shell), `lib/screens/home_screen.dart` (button + animated
  title), `lib/theme/nav_icon_art.dart` (new: custom painters + motion math
  for all seven glyphs), `lib/theme/nav_animations.dart` (durations,
  press-event notifier and reusable animated icon widget),
  `lib/screens/main_shell.dart` (wires each destination to its animation),
  `test/theme_test.dart`, `test/nav_animations_test.dart` (new).
- **Result:** `flutter analyze --no-pub`: No issues found. `flutter test`:
  26/26 passed.

### 2026-11-19 — Diet planner page
- **What:** Added a **Diet** page, opened from a new card on Home (kept out of
  the bottom bar so the seven animated destinations stay uncrowded). It has a
  date picker defaulting to today, a grid of all 24 one-hour time slots, and
  editable daily **calorie** and **water** goals with a Save goals button.
  Tapping a slot opens an activity editor with two types:
  - **Food:** Food Item, Type (Veg / Non veg), Quantity, optional Photo, then a
    **Validate with Gemini** button. Missing API key shows the standard
    configuration error; a valid key shows an in-button loading spinner while
    Gemini returns calories, a nutrient breakdown and a short summary, all
    rendered inline. A Save button writes the analysed portion to the slot and
    deducts its calories from the remaining daily calorie goal.
  - **Water:** Water quantity in ml. Saving writes the entry to the slot and
    deducts that amount from the remaining water intake goal.
  Saved entries are listed inside their slot with a delete action, and remain
  in memory when switching tabs.
- **Files:** `lib/models/diet_models.dart` (new: `DietDay`, `DietEntry`,
  `FoodAnalysis`, `slotLabel`), `lib/state/diet_state.dart` (new: shared
  in-memory per-day store), `lib/services/diet_service.dart` (new: Gemini food
  analyser with key gating), `lib/screens/diet_screen.dart` (new),
  `lib/screens/main_shell.dart` (`/diet` route + Home callback),
  `lib/screens/home_screen.dart` (Diet callout card),
  `test/diet_test.dart` (new), `test/app_smoke_test.dart` (Home → Diet → back).
- **Result:** `flutter analyze --no-pub`: No issues found. `flutter test`:
  32/32 passed.

### 2026-11-19 — App-wide validated API keys + Keys page
- **What:** Removed the compile-time `GEMINI_API_KEY` requirement entirely.
  Every AI action (Generate workout, Plan, Calories, Diet food validation and
  Pose image analysis) now calls a shared `ensureAiAccess` gate: if no validated
  key is active it opens a dialog where the user pastes a key and picks an
  endpoint/model (four Google Gemini presets or a custom base URL + model).
  The **Validate** button makes a real, tiny request to that endpoint and only
  stores the key on HTTP 200; empty, invalid, expired or unreachable keys show
  a descriptive error in the dialog. Valid keys are persisted with
  `flutter_secure_storage`. A new **Keys** page (Home card) shows the currently
  active endpoint/model and "Use this endpoint" / remove actions (the original
  hide/unhide control was later removed in favour of a fixed full mask).
  Removing the active key means the next AI
  feature asks for authentication again. Different endpoints/models are shown
  explicitly because they produce different results.
- **Files:** `lib/services/api_key_service.dart` (new: `AiEndpoint`,
  `ApiKeyEntry`, `ApiKeyStore`, `ApiKeyValidator`), `lib/widgets/api_key_dialog.dart`
  (new: dialog + `ensureAiAccess` gate), `lib/screens/keys_screen.dart` (new),
  `lib/services/{gemini,plan,calories,diet,pose_analysis}_service.dart` (use the
  stored key/endpoint), `lib/screens/{plan,calories,diet,workout_input,pose_tracking}_screen.dart`
  (gated AI buttons), `lib/screens/main_shell.dart` (`/keys` route),
  `lib/screens/home_screen.dart` (Keys card), `lib/main.dart` (preload keys),
  `pubspec.yaml` (`flutter_secure_storage`), `test/api_key_service_test.dart`
  (new), updated screen/smoke/theme tests.
- **Result:** `flutter analyze --no-pub`: No issues found. `flutter test`:
  39/39 passed. `flutter build web --release`: succeeded.

### 2026-11-20 — API-key dialog layout + key hygiene fixes
- **What:** Fixed repeated web rendering crash
  `BoxConstraints forces an infinite width (w=Infinity, h=46.0)` at the
  `FilledButton` in `ApiKeyDialog`. Root cause: the web dialog route/theme can
  inject `BoxConstraints.expand()`, and `AlertDialog`'s internal
  `IntrinsicWidth` + stretched `Column` combined with `Row` + `Expanded` to
  propagate an infinite intrinsic width. First fix (`constraints: BoxConstraints(maxWidth: 400)`)
  was insufficient; final fix computes a tight finite dialog width with
  `LayoutBuilder`, sizes content from that width, removes `Expanded`, and gives
  the validate button a fixed width.
- **What (remove-key):** Fixed `This widget has been unmounted ... get context`
  when tapping Remove. The dialog builder had captured the `KeysScreen`
  `State.context`; it now uses the dialog's own `dialogContext` for `pop()`, and
  a `mounted` guard was added before deleting the key.
- **What (dialogs):** Introduced shared `AppDialog` so all confirmation dialogs
  get finite, screen-fitting widths. Applied to remove-key, clear-history, and
  API-key dialogs.
- **What (security):** Moved the Gemini key out of `?key=` URLs into the
  `x-goog-api-key` header via `geminiHeaders(key)` across validation, Gemini
  service, Plan, Calories, Diet, and Pose analysis. This keeps the key out of
  browser console/network-error URLs. Discussed that this is **not** full
  secrecy: browser/Android can still inspect headers/runtime memory; a backend
  proxy is required for real confidentiality. Reiterate: the key previously
  printed in console must be rotated.
- **What (URL/CORS):** Fixed duplicated
  `...:generateContent/{model}:generateContent` for pasted custom full URLs.
  Skipped direct YouTube search scraping on web to remove CORS errors.
- **Files:** `lib/widgets/app_dialog.dart` (new), `lib/widgets/api_key_dialog.dart`,
  `lib/screens/keys_screen.dart`, `lib/screens/exercise_logger_screen.dart`,
  `lib/services/api_key_service.dart`, `lib/services/gemini_service.dart`,
  `lib/services/{plan,calories,diet,pose_analysis}_service.dart`,
  `lib/services/youtube_service.dart`, `test/app_dialog_test.dart` (new),
  `test/api_key_dialog_test.dart`, `test/api_key_service_test.dart`.
  `dart format` also normalized formatting across existing `lib/` and `test/`
  files; no behavior changes from formatting alone.
- **Result:** `flutter analyze lib test`: No issues found. `flutter test`:
  **42/42 passed**. Committed locally and tagged
  `saved-2026-11-20-api-key-fixes`; not pushed.

### 2026-11-20 — Local-first device persistence + bundled fonts
- **What:** Added `shared_preferences` and a shared `LocalStore` with async
  startup load, synchronous cached reads, JSON writes, and a test reset hook.
  Added `toJson`/`fromJson` to workout, diet, plan, and calorie models.
  `WorkoutState` now restores saved workouts, current workout, exercise logs,
  and selected tab; `DietState` restores per-date goals/entries;
  `ThemeController` restores mode/palette; `PlanScreen` restores both form
  drafts, generated plan, and tab; `CaloriesScreen` restores form, weekly/BMI
  results, and tab; `WorkoutInputScreen` restores its input draft. `main()`
  loads the store and all states before `runApp`. `MainShell` uses
  `WorkoutState.instance`.
- **What (fonts/network):** Downloaded `Inter` and `SpaceGrotesk` TTF weights
  from the already-installed `google_fonts` 6.3.3 asset URLs into
  `assets/fonts`, declared the folder in `pubspec.yaml`, and disabled runtime
  fetching in `main()`. No app code fetches Google Fonts at runtime. Following
  the user's explicit correction, native YouTube scraping and YouTube thumbnail
  images were restored; web still returns a search URL for scraping to avoid
  CORS errors.
- **What (tests):** Added `test/local_persistence_test.dart` for store JSON
  round-trips and restore of workout, diet, theme, generated-plan, and
  calorie/BMI state. Screen/state tests now reset `LocalStore` in `setUp` so
  persistence does not leak between tests.
- **Files:** `pubspec.yaml`, `pubspec.lock`, `assets/fonts/*` (new),
  `lib/services/local_store.dart` (new), `lib/main.dart`,
  `lib/screens/main_shell.dart`, `lib/screens/{plan,calories,workout_input}_screen.dart`,
  `lib/state/{workout_state,diet_state}.dart`, `lib/theme/theme_controller.dart`,
  `lib/models/{workout,diet,plan,calories}_models.dart`, updated tests and new
  `test/local_persistence_test.dart`.
- **Result:** `dart format lib test` clean. `flutter analyze lib test`:
  **No issues found**. `flutter test`: **48/48 passed**.
  `flutter build web --release`: succeeded; bundled fonts are present in
  `build/web/assets/assets/fonts/`. Changes are **uncommitted** in the working
  tree and have not been pushed.

### 2026-11-20 — Migrate local data to encrypted Hive CE
- **What:** Replaced `shared_preferences` with `hive_ce` + `hive_ce_flutter`.
  `LocalStore` now calls `Hive.initFlutter()`, generates/reuses a 32-byte AES
  key from `flutter_secure_storage`, opens the `workout_app_local_v1` box with
  `HiveAesCipher`, and mirrors its JSON string values in memory. If the stored
  key no longer matches the box, the store recovers by deleting and recreating
  the box with a fresh key. Added `LocalStore.flush()`; Hive CE also flushes on
  app pause via `hive_ce_flutter`.
- **Clarification:** Requested `flutter_secure_package` was interpreted as
  `flutter_secure_storage` (the actual pub.dev package, already used for API
  keys). API keys and the Hive encryption key both live there. No app data is
  stored in plain SharedPreferences anymore.
- **Version note:** Pinned `hive_ce_flutter: 2.5.0`. Version `2.6.0` adds
  native-asset zlib hooks that fail on this Windows setup with
  `No compiler configured on host 'windows_x64'`. `hive_ce: ^2.24.0` works.
- **Files:** `pubspec.yaml`, `pubspec.lock`, `lib/services/local_store.dart`,
  `PROJECT_STATE.md`.
- **Result:** `dart format lib test` clean. `flutter analyze lib test`:
  **No issues found**. `flutter test`: **48/48 passed**.
  `flutter build web --release`: succeeded. Changes were uncommitted at this
  point; committed and released later the same day (entries below).

### 2026-11-20 — Single-session login gate + fully masked keys
- **What:** Added `lib/screens/login_screen.dart` and
  `lib/state/session_state.dart`. The app now boots to a login screen with
  `Continue as guest` and `Continue as new user`. Choosing guest seeds the
  preloaded test workouts/logs (`GuestSeed` + `WorkoutState.ensureSeeded()`);
  choosing new user deletes both namespaces, clears saved API keys, and reloads
  empty state. There is no back route into login after sign-in - only the
  **Sign out** button in the Home header returns there.
- **Single-session rule:** Sign-out keeps the session marker on disk. The login
  screen then shows the session label and a delete icon; both sign-in buttons
  stay disabled until that icon confirms deletion. Deleting removes both
  namespaces, the session marker, and saved API keys. `LocalStore` now scopes
  ordinary keys as `workout_app.<namespace>.<key>` and keeps only the session
  marker global; legacy keys were migrated to `guest`.
- **State reload:** `WorkoutState.reload()`, `DietState.reload()`, and
  `ThemeController.reload()` swap singleton state to the selected namespace.
  `ThemeController` suppresses persistence while notifiers are being reset so
  an old palette cannot leak into the new profile.
- **Keys:** `ApiKeyEntry.maskedKey` is now a fixed 12-bullet mask. Removed the
  Keys-page reveal/show/hide control entirely; neither characters, key length,
  nor raw key text appear in the frontend. `ApiKeyStore.clear()` was added for
  session deletion.
- **Files:** `lib/main.dart`, `lib/screens/{login_screen,main_shell,home_screen,keys_screen}.dart`,
  `lib/services/{local_store,api_key_service}.dart`,
  `lib/state/{session_state,guest_seed,workout_state,diet_state}.dart`,
  `lib/theme/theme_controller.dart`, updated `test/app_smoke_test.dart`,
  `test/api_key_service_test.dart`, and new `test/session_login_test.dart`.
- **Result:** `dart format lib test` clean. `flutter analyze lib test`:
  **No issues found**. `flutter test`: **51/51 passed**.
  `flutter build web --release`: succeeded. Changes were uncommitted at this
  point; committed and released later the same day (entries below).

### 2026-11-20 — Plan History tab for weekly and single-day results (pre-release)
- **What:** Added a third **History** tab to the Plan section alongside Weekly
  and Single day. Generated results now end with **Save to History**, which
  stores the exact generated plan (including its scope, inputs, days, exercises
  and YouTube demo URLs) as a timestamped entry. Once saved, the button changes
  to **Saved to History** and a **View History** shortcut appears.
- **History view:** Saved plans are listed newest first with scope, saved time,
  overview, **Open saved plan**, and confirmed **Delete saved plan** actions.
  Opening an entry restores it to the result view. The empty state explains how
  to create the first entry. The History tab has no generate CTA, and the last
  selected Weekly/Single-day form still determines the generator scope.
- **Session scope:** `SavedPlanEntry` plus the new `PlanHistoryStore` persist
  through the encrypted, namespaced `LocalStore`. Guest and new user histories
  are isolated; new-user sign-in starts empty and session deletion removes the
  history with the rest of that namespace. `LocalStore.deleteNamespace()` was
  also fixed to clear matching in-memory cache keys, not just Hive box keys.
- **Files:** `lib/models/plan_models.dart`, `lib/services/local_store.dart`,
  `lib/services/plan_history_service.dart` (new), `lib/screens/plan_screen.dart`,
  updated `test/local_persistence_test.dart` and `test/plan_screen_test.dart`.
- **Result:** `dart format lib test` clean. `flutter analyze lib test`:
  **No issues found**. `flutter test`: **55/55 passed**.
  `flutter build web --release`: succeeded. Changes were uncommitted at this
  point; they were committed and released later the same day (entries below).

### 2026-11-20 — Pre-release security review and signed Android APK
- **What:** Reviewed the whole repository before any push: tracked files,
  working tree and full git history for real credentials. Confirmed the real
  Gemini key exists only in git-ignored `env.json`; the git remote has no
  embedded credentials; only placeholder keys (`AIzaSyAbCdEfGh1234567890`) and
  a minified-JS false positive appeared in history. Added `/android/build/` to
  `.gitignore`. Nothing was pushed at this stage (user chose review + APK only).
- **What (APK):** Set unique namespace/application ID `com.insectcs.workoutapp`
  (user chose a new ID; org-derived from `insect-cs`), launcher label
  "Workout Tracking", moved `MainActivity.kt` to the new package, generated a
  release JKS with alias `workoutapp`, and wired signing via git-ignored
  `android/key.properties`. Built and verified the signed APK: v2 signature,
  cert `CN=Workout Tracking`, correct app ID/version, no embedded API key.
  Created a keystore backup outside the repo at `E:\test\keystore-backup\`.
- **Build blockers fixed:** Kotlin cross-drive incremental cache
  (`kotlin.incremental=false`), Windows symlink requirement (temporarily
  `flutter config --no-enable-windows-desktop`, restored afterwards), CameraX
  1.5 / Gradle 9 missing `androidx.concurrent.futures.CallbackToFutureAdapter`
  on the compile classpath (explicit `androidx.concurrent:concurrent-futures:1.2.0`
  in `android/build.gradle.kts`), and a UTF-8 BOM in `key.properties` corrupting
  `storePassword` (file rewritten without BOM).
- **Files:** `.gitignore`, `android/app/build.gradle.kts`,
  `android/app/src/main/AndroidManifest.xml`,
  `android/app/src/main/kotlin/com/insectcs/workoutapp/MainActivity.kt` (new),
  old `.../com/example/workout_app/MainActivity.kt` (deleted),
  `android/build.gradle.kts`, `android/gradle.properties`,
  `android/key.properties` (ignored), `android/app/release-keystore.jks`
  (ignored), `E:\test\keystore-backup\*` (outside repo).
- **Result:** `flutter test` 55/55; signed `app-release.apk` produced, signature
  and binary secret scan verified; keystore backup hashes matched the originals
  and the JKS opened with the stored password.

### 2026-11-20 — README, LICENSE, NOTICE and media provenance cleanup
- **What:** Replaced the stock `README.md` with user-facing docs (features,
  APK install, bring-your-own-key flow, privacy/data behaviour, build notes).
  Added MIT `LICENSE` (copyright 2026 insect-cs) and `NOTICE` listing direct
  Flutter/Dart packages with resolved versions, bundled TensorFlow.js/MoveNet
  assets, Inter/Space Grotesk fonts (SIL OFL 1.1), Material Icons, and native
  Android dependencies.
- **What (media verification):** Audited four bundled demo assets.
  `workout_sample.mp4` and `deepx_squat.mp4` were byte-identical; the video/JPEG
  files had Google/C2PA or no provenance metadata and no license. None were
  referenced anywhere in `lib/` or `test/` — they were only bundled because
  `pubspec.yaml` declares the asset directories. Removed all four (`.gitkeep`
  retained), updated `NOTICE`/`README`, and rebuilt the APK (~106.5 MB → 99.8 MB).
- **Files:** `README.md`, `LICENSE` (new), `NOTICE` (new),
  `assets/images/workout_sample.jpg` (deleted), `assets/videos/*.mp4` (deleted).
- **Result:** Rebuilt APK verified (same signing cert, no embedded key, new
  SHA-256); 55/55 tests still passed.

### 2026-11-20 — Published GitHub release v1.0.0
- **What:** With user approval, staged all 58 files and committed as `e53a47e`
  "Release v1.0.0: local-first sessions, pose tracking and signed Android
  build", pushed `main`, created and pushed annotated tag `v1.0.0`, and published
  a non-draft/non-prerelease GitHub release with release notes covering features,
  BYOK setup, privacy and checksum. Attached `app-release.apk` plus
  `app-release.apk.sha256`.
- **What (verification):** Re-downloaded the APK from the public release URL and
  confirmed its SHA-256 matched the local build exactly.
- **Files:** release at
  https://github.com/insect-cs/Workout_Tracking_App/releases/tag/v1.0.0
- **Result:** Release live; no secrets in repo/history/APK; repo clean and in
  sync with `origin/main`.

### 2026-11-20 — Fix Android 16 startup crash (R8 stripped Room constructor)
- **What:** User reported launch crash on Android 16:
  `RuntimeException: Failed to create an instance of androidx.work.impl.WorkDatabase`
  via `androidx.startup.InitializationProvider` / `WorkManagerInitializer`.
  Root cause: AGP **9.1.0** R8 removed the generated `WorkDatabase_Impl` no-arg
  constructor; Room instantiates it reflectively. Confirmed from the R8 mapping
  file: `WorkDatabase_Impl` was present but had no `<init>` entry.
- **Fix:** Added `android/app/proguard-rules.pro` with
  `-keep class * extends androidx.room.RoomDatabase { <init>(); }` plus keeps
  for `androidx.work.impl.**` and `androidx.work.WorkManagerInitializer`, and
  wired `isMinifyEnabled = true` + `proguardFiles(...)` into the release build
  type. Rebuilt; mapping now contains `WorkDatabase_Impl.<init>()` and
  `WorkManagerInitializer.<init>()`/`create()`.
- **What (release repair):** Per user choice, deleted the broken APK/checksum
  assets from v1.0.0 and uploaded the fixed pair (old SHA-256
  `40b25900…80f259` → new `d837f752…e8cc2`); updated release notes with the new
  hash and a fix note; committed the fix as `717e615`, pushed `main`, and
  force-moved the `v1.0.0` tag to that commit so the source tag matches the APK.
  Re-downloaded and hash-verified the repaired release.
- **Files:** `android/app/proguard-rules.pro` (new), `android/app/build.gradle.kts`,
  GitHub release v1.0.0 assets/notes, tag `v1.0.0`.
- **Result:** User confirmed the app now works properly on Android 16. 55/55
  tests pass; signature unchanged (`c12b84b5…00c63`). User is continuing to test
  and will report any further issues.

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
13. **Web dialog theme:** This Flutter build's `_FullWindowDialogWrapper`
    injects `DialogThemeData(constraints: BoxConstraints.expand())`. With an
    unsized web viewport that becomes tightly infinite. Always use `AppDialog`
    (finite `BoxConstraints.tightFor(width: ...)`) instead of raw `AlertDialog`.
14. **`Expanded` + `IntrinsicWidth`:** `AlertDialog` wraps content in
    `IntrinsicWidth`; avoid `Expanded` inside its content unless all ancestors
    have provably finite widths. Give children explicit finite widths instead.
15. **Context after `await`/in dialog builders:** Never capture the parent
    `State.context` inside a dialog builder. Use the builder-provided context
    (`dialogContext`) for `Navigator.pop()`, and check `mounted` before touching
    state after async work.
16. **Client-side secrets:** Base64/AES/`flutter_dotenv` with bundled keys is
    obfuscation only. Once decrypted in the browser/app, the key is visible in
    memory/DevTools. Real confidentiality needs a backend proxy + secret
    manager. `x-goog-api-key` keeps keys out of URL/console logs but not out of
    inspected request headers.
17. **Disabling Google Fonts fetching is not enough:** bundle the exact asset
    names (`Inter-Regular.ttf`, `SpaceGrotesk-Bold.ttf`, etc.) or styled text
    fails. `google_fonts` chooses the nearest bundled weight for requests such
    as `FontWeight.w800` when that exact weight is not published.
18. **Persistence in tests:** `LocalStore.resetForTesting()` must run before
    pumping screens or checking state; otherwise a previous test's saved form
    state leaks into the next one. `WorkoutState.instance` is now the single
    shared instance used by the app shell; extra instances are valid in tests.
19. **`hive_ce_flutter` 2.6.0 on Windows:** its zlib native assets require a C
    compiler (`vswhere.exe` / Visual Studio Build Tools). This environment has
    none configured, so 2.5.0 is pinned. Revisit only after installing build
    tools or when a pure-Dart backend is available.
20. **Hive CE box iteration:** `Box<E>` exposes `keys`, not `entries`; read each
    value with `box.get(key)`. `Hive.initFlutter()` is safe on web (path stays
    `null` and Hive uses IndexedDB).
21. **Root widget switch is the login gate:** `MaterialApp.home` switches
    between `LoginScreen` and `MainShell` from `SessionState.signedIn`. Do not
    reintroduce a login *route* on the inner `Navigator`, or back navigation
    could reveal it after sign-in.
22. **Reset `ApiKeyStore` in widget tests that sign in:** if a test pumps
    `WorkoutTrackingApp` and taps a sign-in option, call
    `ApiKeyStore.instance.resetForTesting()` in `setUp`; otherwise
    `ensureLoaded()` tries the secure-storage plugin and the sign-in await can
    stall the root switch.
23. **Dart field initializers cannot read earlier instance fields:** pristine
    guest data is captured in `WorkoutState._captureInitialData()` from both
    constructors, not in field initializers.
24. **`deleteNamespace()` must clear the in-memory cache too:** Hive keys alone
    are enough in the app, but tests/memory-only mode need `_values` removal or
    deleted session data appears to survive a namespace switch.
25. **AGP 9 + R8 strips Room `*_Impl` constructors:** WorkManager opens a Room DB
    at startup via App Startup; if R8 removes the no-arg constructor, the app
    dies before `main()` with "Failed to create an instance of WorkDatabase".
    Keep `-keep class * extends androidx.room.RoomDatabase { <init>(); }`.
26. **CameraX 1.5 + Gradle 9:** `camera-core` declares `concurrent-futures` as
    runtime-only, but its compiled classes carry JSpecify annotations needing it
    on the compile classpath. Add `androidx.concurrent:concurrent-futures`
    explicitly to every Android module, including plugins.
27. **`key.properties` must have no UTF-8 BOM:** PowerShell `Set-Content
    -Encoding UTF8` adds `EF BB BF`, which corrupts the first key name and makes
    AGP report `SigningConfig "release" is missing required property
    "storePassword"`. Write with `UTF8Encoding($false)`.
28. **Kotlin cache across drives:** with the pub cache on `C:` and the project
    on `E:`, incremental Kotlin compilation fails; `kotlin.incremental=false` in
    `android/gradle.properties` is the workaround.
29. **Windows Flutter symlinks:** building with the `windows/` folder present
    needs Developer Mode; toggling `flutter config --no-enable-windows-desktop`
    temporarily (and restoring it afterwards) avoids the requirement.
30. **Unreferenced asset folders are still bundled:** `pubspec.yaml` directory
    entries (e.g. `assets/videos/`) include every file in the folder. Remove
    unused media to keep the APK small and licensing clean.

---

## 7. Next Steps / Backlog

- [ ] User verification: pose-tracking dynamic counter + elbow angle + continuous
      identification (video & live camera)
- [ ] User verification: logger set splits (weight/reps/time), graph
      visualizations (Bars/Line/Area/Pie), and timeframe-scoped CSV/PDF export
- [ ] Web fallback for live camera (getUserMedia + MoveNet) instead of error
- [ ] Hand off pose-tracking rep counts into `WorkoutState` session history;
      generic workouts/logs are now persisted, but pose reps are not yet wired
      into that flow
- [ ] Form feedback based on tracked metrics (depth %, tempo, asymmetry)
- [ ] Consider multi-person detection (MoveNet MultiPose) for videos with
      several subjects
- [ ] Clean up pre-existing `withOpacity` deprecation infos
- [ ] **Backend proxy decision:** Choose Cloudflare Workers / Firebase
      Functions / Cloud Run / Vercel Functions / Supabase Edge Functions for
      app-owned Gemini key. Add auth/rate limiting, then switch Flutter
      services from direct Gemini calls to `/api/gemini`. Keep BYOK path for
      users who prefer their own key.
- [x] Re-ran `flutter build web --release` after the 2026-11-20 changes.
- [x] Commit/tag the local-first + Hive CE + login-gate + Plan-History +
      bundled-font changes (done as `e53a47e`, tag `v1.0.0`).
- [x] Push the local commit/tag(s) to `origin/main` (done).
- [ ] User verification: continued Android 16 testing after the R8 fix (user is
      testing and will report any further issues).
- [ ] Copy the keystore backup ZIP from `E:\test\keystore-backup\` to durable,
      offline storage (password manager or external drive).
- [ ] Revisit build workarounds (`kotlin.incremental=false`, explicit
      concurrent-futures dependency, R8 keeps) when Flutter/AGP versions move on.
