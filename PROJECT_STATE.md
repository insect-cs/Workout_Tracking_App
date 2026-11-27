# Workout App — Project State

> **Purpose:** Living document tracking every task performed on this project.
> Read this file at the start of any new session to restore context. Update it
> after every meaningful change.
>
> **Last updated:** 2026-11-27 (prepared and published v1.3.0 with a signed
> release APK and GitHub release after a full secret scan. Earlier today: added nutrient bar charts after saving an
> analysed food, weekly nutrient totals and major contributor foods, a date-range
> selector for the diet summary/export, a clear selected state for time slots,
> and fixed the saved-workout right-edge overflow. Earlier today: fixed the login
> update check reporting the installed `v1.2.0` as an update, added Resume saved
> session, moved the Auto palette button to login, palette-themed the sign-out
> and login buttons, tidied the API key dialog, and changed the Gemini presets to
> 3.1 Flash Lite / 3.8 Flash / 3.5 Flash Lite plus Custom. Live tracking keeps the
> 270° camera lock with the preview aspect fix, and the exercise classifier covers
> neck/shoulder/back/biceps/triceps/chest/legs/core with a stricter squat gate.)
> **Session model:** Each new feature/bugfix session appends to §5 Task Log.

---

## 0. Current State Snapshot (2026-11-27)

- **Current worktree (2026-11-27):** The live camera path keeps the 24 Nov
  `v1.2.0` settings (`availableCameras()` picker, manual switching,
  `ResolutionPreset.medium`, NV21 on Android, no audio, `FlashMode.off`, no
  Activity orientation lock). The live session locks only the camera use cases
  to `DeviceOrientation.landscapeLeft` (270° clockwise); the app UI never rotates
  and the detector/rotation probe is left untouched. Only the drawn
  skeleton/replay is rotated to match the stream. On Android, recording now carries the
  frame callback because plain CameraX recording silently unbinds image
  analysis; a 3-second watchdog can drop video and fall back to a plain image
  stream without changing lenses. The badge shows
  `N FRAMES · N LANDMARKS` and a silent MoveNet rejection reports its pose/max
  joint scores, rotation and frame format. Android detection is bundled TFLite
  MoveNet Lightning with a low-rate ML Kit depth sample; web stays on TF.js
  MoveNet and iOS stays on ML Kit. No MediaPipe model/JNI is bundled. The crop
  clamp matches TF.js (the square crop may extend past the frame edge), the
  detector probes frame rotations after a short run of empty frames, and live
  counting uses the same 0.12 joint threshold as the skeleton painter. Live
  tracking is now labelled **LIVE EXERCISE TRACKING**; a dedicated classifier
  identifies neck, shoulder, back, biceps, triceps, chest, legs and core
  movements, and only the identified exercise's counter moves. Bodyweight squats
  now need a learned standing hip reference, both knees bent together, hip fold
  and a real hip drop, so bent knees during curls or sitting no longer produce
  false squat reps. The skeleton keeps using the same 270° lock value because
  both the plugin texture and MoveNet are brought upright first. The login gate
  now owns the Auto palette button and offers a Resume saved session action
  after sign-out. Current validation: `dart format` clean,
  `flutter analyze lib test android` clean, and the full `flutter test` suite
  passes. These changes were committed and published as v1.3.0 on 2026-11-27.
- **Superseded uncommitted work (2026-11-25, Android 16 landmarks still
  failing):** The
  user reported that Android 16 still shows no 3D landmarks during live camera
  streaming and that the saved session only says “No live tracking happened”.
  The v1.2.0 release did **not** contain the newer MediaPipe work in the
  working tree. Current uncommitted code switches native live/video tracking to
  MediaPipe Pose Landmarker, bundles `pose_landmarker_lite.task`, keeps ML Kit as
  a fallback, repacks row-padded NV21 frames, treats MediaPipe's low/zero IMAGE
  visibility as unknown so landmarks actually draw, and writes the real
  detector error into the History message. After the user still saw no error,
  the real root cause was found: CameraX silently unbinds image analysis when a
  plain video recording starts, so the detector got zero frames. Android now
  records with an `onAvailable` frame callback and a frame watchdog that can
  drop video to preserve tracking; frame counts are shown in the UI. The user
  then reported camera-angle friction, moving landmarks creating their own
  activity, and two detector errors. MediaPipe now runs in VIDEO mode with
  lower detection thresholds, the Android 16 `Optional<Float>` visibility cast
  is fixed, one subject is tracked with continuity scoring and landmark
  smoothing, and held frames no longer drive exercise counters. The user then
  reported that the stream still needed repeated manual adjustment and that
  landmarks still created activity: live tracking now automatically tries every
  camera reported by the platform when the first one cannot find a stable pose,
  uses MediaPipe metric world coordinates for joint angles, keeps the raw
  detector reliability separate from the promoted overlay confidence, and only
  feeds counters after consecutive reliable same-subject frames with a held
  movement. Analyzer clean, 112/112 tests pass, and a fresh `app-debug.apk` was
  rebuilt. **Needs on-device verification.**
- **Released work (2026-11-24, v1.2.0):** (1) Android 16 live-camera
  pose-tracking fix — `lib/services/pose_analysis_service.dart`,
  `lib/screens/pose_tracking_screen.dart`, new `test/pose_frame_test.dart`.
  (2) Diet planner upgrade — slot colours, daily/weekly Rest goals, food
  quantity units, and CSV/PDF exports written to Android Downloads via a new
  MethodChannel (`MainActivity.kt`, `download_saver*.dart`). (3) Calories
  response History — save buttons at the end of weekly and BMI results, a new
  third History tab, and a namespaced `CalorieHistoryStore`. (4) Android YouTube
  link fix — canonical HTTPS watch URLs preserve case-sensitive video IDs
  instead of lowercasing them in a `vnd.youtube://` host. (5) Generated-result
  return buttons — Plan and Calories results end with **Go to previous screen**,
  which clears the result and restores the matching form tab. (6) Live-session
  replay landmarks — time-stamped skeletons are stored with the recorded video
  and drawn on the History video as it plays. See the §5 task-log entries for
  details. **Committed, pushed, tagged and released; still needs user
  verification on the Android 16 device.**
- **Git / GitHub:** `workout_app` is a Git repository. `origin` is
  `https://github.com/insect-cs/Workout_Tracking_App.git`, branch `main`.
  Released work is committed and pushed; `main` is in sync with `origin/main`
  at `6f0abff` (the state-doc commit after `7bfa403` / **v1.2.0**). The
  2026-11-25 MediaPipe work is **uncommitted in the working tree**. The
  2026-11-24 fixes above are in commit `7bfa403` / **v1.2.0**, authored as
  `insect-cs@users.noreply.github.com`. Annotated tag **v1.2.0** is pushed.
  GitHub release **v1.2.0 — Workout Tracking** is
  published (not draft, not prerelease) with `app-release.apk` and
  `app-release.apk.sha256`:
  https://github.com/insect-cs/Workout_Tracking_App/releases/tag/v1.2.0
  Previous releases remain at
  https://github.com/insect-cs/Workout_Tracking_App/releases/tag/v1.1.0 and
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
- **Android live-camera landmark fix (2026-11-24):** `detectFromCameraImage`
  now repacks CameraX frames into an exact-size NV21 buffer (handles padded
  NV21 and 3-plane YUV_420_888), falls back from STREAM to SINGLE detector
  mode, probes frame rotation if a device reports a mismatched sensor
  orientation, and normalizes landmarks against the true rotated frame size.
  The live screen now publishes the camera before starting the image stream,
  starts video recording without blocking tracking, and shows native
  detection errors on screen instead of silently reporting "no person".
  Added `test/pose_frame_test.dart` for frame packing / normalization.
- **Configuration / security:** Real keys are entered at runtime and stored in
  secure storage — no real keys in tracked files, tokens, or credential files.
  `env.json` / `env.example.json` remain but are no longer required by AI
  features.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **112/112 passed** (the 97 v1.2.0 tests plus 9 MediaPipe conversion/stability
  tests and 6 frame/angle/reliability regression tests), and
  `flutter build apk --debug`
  succeeded on 2026-11-25. `flutter build web --release` succeeded earlier.
  Built `build/web/assets/assets/fonts/` contains the bundled TTFs. Signed
  Android release APK for v1.2.0 was built and verified after the R8 fix; the
  uncommitted 2026-11-25 MediaPipe work has **only a debug APK** so far.
  `flutter config --enable-windows-desktop` was restored after the
  temporary build workaround.
- **Android release / signing:** Unique app ID `com.insectcs.workoutapp`,
  launcher label "Workout Tracking", version 1.0.0 (code 1), minSdk 24 /
  targetSdk 36. Release signing reads git-ignored `android/key.properties`,
  which points at git-ignored `android/app/release-keystore.jks` (alias
  `workoutapp`, RSA 2048, valid to 2054-04-07, cert SHA-256
  `c12b84b5dc519c096d3bf1aa3c70c88e747dd0a56c11cf6c0ffc962c7bd00c63`).
  APK SHA-256 (current fixed build):
  `d837f75266bf39af269e429d985f6108c1dd3cbe797cfd77e39cbc02615b8cc2`.
  Backup outside the repo: `<backup-location>/2026-11-20/` and
  `<backup-location>/workout-tracking-keystore-2026-11-20.zip`.
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
- **End-of-day save:** All 2026-11-20/23/24 work is captured above and in §5
  Task Log and is committed, pushed and released as v1.2.0. Authoritative
  validation for the current tree: analyze clean, 97/97 tests passing, freshly
  built signed APK with a verified v2 signature and checksum, and user
  confirmation that the app launches on Android 16. The landmark, diet, export,
  History, YouTube and return-button fixes still need on-device verification.
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
the user confirmed the app works correctly. On 2026-11-24 the Android live
camera landmark pipeline was first repaired for ML Kit, then restored to that
`v1.2.0` camera path on 2026-11-26 and re-layered with TFLite MoveNet, relative
depth visualisation, and TF.js-matching crop/rotation handling (see §5). Latest
validation (authoritative): `flutter analyze lib test android` no issues,
`flutter test` 110/110 passed, `flutter build apk --debug` (271,327,015 bytes)
and `flutter build web --no-wasm-dry-run` succeeded, release APK signature and
download hash verified for v1.2.0. The uncommitted Android MoveNet/depth path
still needs on-device verification.

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
- MoveNet joints with confidence < 0.12 are not drawn or counted (aligned live
  painter, replay and counter threshold)
- Export on native saves to app documents directory (path shown in snackbar);
  on web it triggers a browser download
- Latest pose-tracking refinements (dynamic counter/elbow angle/continuous ID)
  and logger/export changes await user verification in-app

---

## 4. Environment / Commands

```bash
cd <project-root>
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
  `flutter analyze --no-pub 2>&1 | Out-File -Encoding utf8 analyze_out.txt`
- The workspace root is not a repo, but the `workout_app` directory **is** a Git
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

### 2026-11-23 — Diet weekly goals, summary export, day status and Rest
- **What:** Added editable **weekly calorie/water goals** (default 14000 kcal /
  17500 ml = 7 × daily defaults) stored per Monday. All daily food/water
  activities now also deduct from the week's remaining goals. A **THIS WEEK**
  strip highlights each day green when 50%+ of either daily goal is met, red
  otherwise. Both goal cards show their seed values as `DEFAULT` data with a
  Restore action. A **DIET SUMMARY** button opens a bottom sheet with totals for
  everything logged up to now (calories, water, sleep, days at 50%+, activity
  counts) plus CSV/PDF export. The time-slot editor gained a **Rest** activity
  type that records sleep duration and feeds daily/weekly sleep totals.
- **Files:** `lib/models/diet_models.dart` (rest type, sleepMinutes, week goals,
  summary DTOs), `lib/state/diet_state.dart` (weekly goal persistence and
  weekly consumption/summary), `lib/screens/diet_screen.dart` (weekly goals
  card, week strip, summary sheet, Rest editor),
  `lib/services/diet_export_service.dart` (new CSV/PDF exporter),
  `lib/services/export_service.dart` (shared `saveBytes`),
  `test/diet_test.dart` (4 new tests).
- **Result:** `flutter analyze`: No issues found. `flutter test`: 59/59 passed.

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
  Created a keystore backup outside the repo at `<backup-location>`.
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
  (ignored), `<backup-location>/*` (outside repo).
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

### 2026-11-23 — Android video fix, live tracking history, icon and welcome cards
- **What (video):** Fixed the Android **“Could not open video player.”** error.
  Android 11+ package visibility hid browsers/YouTube from `canLaunchUrl`, and
  local gallery picks could return `content://` URIs that `File()` could not
  open. Added `<queries>` for HTTPS/YouTube intents, a shared
  `VideoLaunchService` (YouTube app → external app → browser fallback without a
  pre-flight `canLaunchUrl`), and `VideoPlayerController.contentUri` support in
  the Pose video picker.
- **What (live history):** History now lives inside the **Pose** screen as its
  own **History** tab (there is no extra bottom-nav section). An explicit
  **Save live tracking** button snapshots the active (or just-stopped) session
  into device-local storage; stopping alone no longer saves tracked data, but a
  recording with no detected pose is saved as a video-only “No live tracking”
  entry. Saved sessions show reps, angles, duration, engine/camera, feedback,
  the last detected skeleton and a playable video, with per-session delete and
  Clear all. History is namespaced per signed-in profile and removed on session
  deletion.
- **What (icon):** Replaced the default Flutter launcher icon with a custom
  orange-gradient dumbbell icon. Added legacy mipmap PNGs, round icons,
  adaptive foregrounds, `mipmap-anydpi-v26` XML, background colour and source
  `assets/icons/app_icon.png`; manifest now declares `android:roundIcon`.
- **What (welcome):** Removed the dots/slider entirely. The two option cards
  themselves are selectable with the mouse wheel, touch swipe, arrow keys or a
  tap; tapping the highlighted card (or pressing Enter) confirms. The selected
  card uses a peach fill with dark text so the guest option is readable. Fixed
  the saved-profile label being clipped with `Expanded` + ellipsis, and kept
  disabled card text readable instead of faded to 45%.
- **Files:** `android/app/src/main/AndroidManifest.xml`, new
  `android/app/src/main/res/mipmap-*/ic_launcher*.png`,
  `mipmap-anydpi-v26/ic_launcher*.xml`, `values/ic_launcher_background.xml`,
  `assets/icons/app_icon.png`; `lib/services/video_launcher_service.dart` (new),
  `lib/services/live_tracking_history_service.dart` (new),
  `lib/models/pose_history_models.dart` (new),
  `lib/screens/live_tracking_history_screen.dart` (new),
  `lib/screens/pose_tracking_screen.dart`, `lib/screens/workout_result_screen.dart`,
  `lib/screens/plan_screen.dart`, `lib/screens/login_screen.dart`, tests
  (`session_login_test.dart`, `app_smoke_test.dart`, `widget_test.dart`,
  `local_persistence_test.dart`).
- **Result:** `flutter analyze`: no issues. `flutter test`: 62/62 passed.
  `flutter build apk --debug` and `flutter build web --release`: succeeded.

### 2026-11-23 — Pose tracking console errors
- **VideoFrame warning:** Web camera teardown could dispose the `CameraController`
  while `camera_web` still had an in-flight MediaStreamTrackProcessor frame,
  producing “A VideoFrame was garbage collected without being closed”. Camera
  release now stops the image stream, waits briefly for the plugin to close the
  frame, then disposes the controller.
- **Unmounted context:** The Save snackbar's **View** action captured
  `State.context`; if the page was popped first, the callback threw
  “This widget has been unmounted”. It now captures a `BuildContext` while
  mounted and checks `context.mounted` before using it. The same guard was added
  around async image/camera pick flows and the video listener.
- **Result:** `flutter analyze`: no issues. `flutter test`: 62/62 passed.
  `flutter build web --release`: succeeded.

### 2026-11-23 — Recorded live video in history + browser VideoFrame fix
- **VideoFrame warning:** The remaining warning came from `camera_web`'s
  `MediaStreamTrackProcessor`, which can leave an in-flight `VideoFrame` open
  when the track stops. Before creating the web `CameraController`, the app now
  removes `MediaStreamTrackProcessor` from `window`, so camera_web uses its
  canvas frame path instead. No `VideoFrame` is allocated and the warning is
  gone; `WebCameraCompat` is a no-op on native.
- **Video capture:** Live sessions now record the camera stream alongside pose
  detection. Stop finalises the recording: native copies it into app documents,
  web stores base64 bytes (blob URLs do not survive reloads). History cards show
  an inline player with play/pause, mute and scrubbing.
- **No tracking:** Stopping a recorded session with no detected pose/reps
  auto-saves a video-only entry titled **No live tracking** with the message
  “No live tracking happened…”. Explicit Save still covers tracked sessions and
  now finalises the recording first so the video is included.
- **Files:** `lib/models/pose_history_models.dart`,
  `lib/screens/pose_tracking_screen.dart`,
  `lib/screens/live_tracking_history_screen.dart`,
  `lib/services/pose_video_source*.dart`, `lib/web/web_camera_compat*.dart`,
  tests (`widget_test.dart`, `local_persistence_test.dart`).
- **Result:** `flutter analyze`: no issues. `flutter test`: 63/63 passed.
  `flutter build web --release` and `flutter build apk --debug`: succeeded.

### 2026-11-23 — Welcome cards replace selection dots
- **What:** Removed the Guest / New user dots from the welcome screen. The two
  cards themselves now act as the selector: mouse wheel/trackpad, touch swipe,
  and up/down arrow keys change the highlight; tapping an unhighlighted card
  selects it, and tapping the highlighted card (or pressing Enter) confirms the
  session. Wheel events are claimed so a parent scroll view does not also move.
- **Readability:** The highlighted card uses a peach fill with dark title,
  subtitle and icon colours, so the guest card is no longer low-contrast.
  Disabled cards keep their readable text.
- **Files:** `lib/screens/login_screen.dart`, `test/session_login_test.dart`.
- **Result:** `flutter analyze`: no issues. `flutter test`: 64/64 passed.

### 2026-11-23 — Save snackbar fix
- **Exception:** The Save snackbar's **View** action called
  `DefaultTabController.of(context)` using the screen's own context, but the
  `DefaultTabController` was a *descendant* created inside `build()`, so the
  lookup threw “no DefaultTabController ancestor”. Because the exception fired
  inside `SnackBarAction.onPressed`, Flutter never reached
  `hideCurrentSnackBar()` and the message stayed on screen, blocking controls.
- **Fix:** The screen now owns a `TabController` (with
  `TickerProviderStateMixin`), passed directly to `TabBar` and `TabBarView`.
  The **View** action calls `_poseTabController.animateTo(1)` with a `mounted`
  guard — no inherited-widget lookup, so no exception. The snackbar also has an
  explicit 3-second duration and `showCloseIcon: true` so it always clears.
- **Files:** `lib/screens/pose_tracking_screen.dart`.
- **Result:** `flutter analyze`: no issues. `flutter test`: 64/64 passed.

### 2026-11-23 — Android launcher name
- **What:** Changed the Android application label from “Workout Tracking” to
  **WT** in `android/app/src/main/AndroidManifest.xml`. The debug/profile
  manifests contain no label, so the release/debug launcher name is now WT.
- **Result:** `flutter build apk --debug` succeeded; `aapt dump badging` confirms
  `application: label='WT'`.

### 2026-11-23 — New-user name entry page
- **What:** Confirming **Continue as new user** now opens a dedicated name-entry
  page instead of signing in immediately. The heading above the field is
  “Welcome” and updates live to “Welcome, &lt;name&gt;” as the user types.
  **Next** (enabled only for a non-empty name) creates the session with that
  display name, pops the page and lands on Home. Guests skip this step.
- **State:** `SessionState` gained a persistent `displayName` notifier stored in
  the session map (restored on launch, cleared on delete). The Home greeting is
  now “WELCOME BACK, &lt;NAME&gt;” for named new users and falls back to
  “WELCOME BACK, ATHLETE” for guests.
- **Files:** `lib/screens/name_entry_screen.dart` (new),
  `lib/screens/login_screen.dart`, `lib/screens/home_screen.dart`,
  `lib/state/session_state.dart`, `test/session_login_test.dart`.
- **Result:** `flutter analyze`: no issues. `flutter test`: 65/65 passed.
  `flutter build web --release` and `flutter build apk --debug`: succeeded.

### 2026-11-23 — Check for updates on the login screen
- **What:** Added a **Check for updates** button below the privacy text on the
  login screen. It calls the GitHub Releases API for
  `insect-cs/Workout_Tracking_App`, compares the latest tag with the app version
  and shows a dialog: **Update available** (with release notes, tag and a
  **Download** button that opens the `.apk` asset or release page) or
  **You're up to date**. Network/API failures show a snackbar instead of
  hanging; requests have a 10-second timeout and a User-Agent header.
- **Files:** `lib/services/update_service.dart` (new; injectable client and
  checker for tests), `lib/screens/login_screen.dart`,
  `test/update_service_test.dart` (new), `test/session_login_test.dart`.
- **Note:** `UpdateService.currentVersion` mirrors `pubspec.yaml` (`1.0.0`)
  because `package_info_plus` is not a dependency; update both when bumping the
  app version. Installation is handled by the browser/Android download flow.
- **Result:** `flutter analyze`: no issues. `flutter test`: 72/72 passed.
  `flutter build web --release` and `flutter build apk --debug`: succeeded.

### 2026-11-23 — Release preparation
- **Version:** Bumped `pubspec.yaml` to `1.1.0+2` (Android versionCode 2) and
  `UpdateService.currentVersion` to `1.1.0` so the new release is detected by
  the in-app update checker. Release tag should be **v1.1.0**.
- **Secrets:** `env.json` contains a real Gemini key but is ignored by
  `.gitignore` and absent from git history. Only `env.example.json` with a
  placeholder is tracked. Signing keys/backups live outside the repo.
- **Result:** `flutter analyze`: no issues. `flutter test`: 72/72 passed.
  `flutter build web --release` and `flutter build apk --debug`: succeeded.

### 2026-11-23 — Pushed v1.1.0 and published GitHub release
- **What:** Committed all pending work in five logical commits (`633ce86`,
  `b08254d`, `d6400ea`, `3349399`, `65300c8`), pushed `main`, created and pushed
  annotated tag **v1.1.0**, then published a non-draft/non-prerelease GitHub
  release. Notes cover the new-user name flow, in-app update checker, live
  tracking history/video, web camera fixes, diet/export improvements and WT
  branding.
- **Assets:** Universal signed release APK `app-release.apk` (105,558,208 bytes)
  plus `app-release.apk.sha256`, SHA-256
  `623a5af0e89b605dc3fb3c1798326638a87e3ebf1aeb6450999f9953d4af5fdc`.
  Downloaded the public asset and re-verified the hash; `apksigner` confirmed a
  valid v2 signature from the existing Workout Tracking certificate.
- **Secret safety:** Re-scanned the five commits and the built APK for API-key,
  token and private-key patterns — no matches. `env.json` is still ignored,
  untracked and absent from history; only the `env.example.json` placeholder is
  tracked. The keystore, `android/key.properties` and backups remain outside the
  repo.
- **Tooling:** `gh` CLI is not installed on this machine, so release creation
  and asset upload used the GitHub REST API with the cached git credential for
  `github.com` (token was never printed or written to the repo).
- **Result:** Release live at
  https://github.com/insect-cs/Workout_Tracking_App/releases/tag/v1.1.0
  `main` and tag are in sync with `origin`; working tree is clean. The in-app
  update checker now sees `v1.1.0` as the latest release and reports
  “You're up to date” for this build.

### 2026-11-24 — Fix Android 16 live camera: no landmarks / angles / reps
- **Reported by user:** On an Android 16 device, Pose Tracking → Live Squat
  Tracking opened the camera picker and the stream started, but no landmarks
  were drawn and exercise identification, elbow/knee angles and rep count never
  updated.
- **Root cause:** The native frame pipeline fed raw `CameraImage` data straight
  to ML Kit:
  - `camera_android_camerax` can return an NV21 buffer with padding from the Y
    plane row stride, making it longer than `width × height × 1.5`. ML Kit
    rejects that with `Image dimension, ByteBuffer size and format don't match`;
    the old code caught the exception and returned null, so the UI only ever
    said "No person detected".
  - Some devices deliver three YUV_420_888 planes even when NV21 is requested.
  - Landmarks were normalized by the largest landmark coordinate (`maxX`/`maxY`)
    instead of the real rotated frame size, distorting the skeleton and angles.
  - `_cameraController` was stored only after `startVideoRecording()` returned,
    so all early frames were dropped by `_processLiveFrame`.
- **Fix (`lib/services/pose_analysis_service.dart`):**
  - Added `packedNv21FromCameraImage()` — trims padded single-plane NV21 to the
    exact ML Kit size and converts 3-plane YUV_420_888 (with row/pixel strides)
    into interleaved NV21. iOS keeps its BGRA metadata path.
  - Added `poseFrameSize()` — swaps width/height for 90°/270° rotations so
    normalized landmarks line up with the preview.
  - Live detection now falls back from STREAM to SINGLE detector mode when no
    pose is returned, and probes the other three rotations after 8 empty frames
    if the device reports a mismatched sensor orientation (locks in the working
    rotation for the session). Session start calls `resetLiveTracking()`.
  - Native errors are exposed via `lastNativeDetectionError` instead of being
    silently swallowed; `dispose()` also closes the streaming detector.
- **Fix (`lib/screens/pose_tracking_screen.dart`):**
  - Stores the active camera/controller **before** `startImageStream()`;
    `_processLiveFrame` uses the stored description.
  - `startVideoRecording()` is now non-blocking/optional (`_startRecordingIfPossible`).
  - Native detection errors appear in a live-preview badge and in the stats
    card, with a real "Frame error" message if processing throws.
- **Tests:** Added `test/pose_frame_test.dart` (7 tests): exact-size NV21,
  padded NV21 trimming, short-buffer rejection, YUV_420_888 → NV21 order,
  stride handling, and rotation-aware frame sizing.
- **Validation:** `dart format` clean, `flutter analyze lib test` **No issues
  found**, `flutter test` **79/79 passed** (including widget/smoke tests).
- **Status:** Changes are **uncommitted**; no new APK built or released yet.
  Next: commit/push, build a signed APK, and ask the user to verify on the
  Android 16 device. The on-screen error badge will expose any remaining
  device-specific detector failure.

### 2026-11-24 — Diet planner slot colours, Rest goals, quantity units, Downloads exports
- **Requested by user:**
  1. Diet time slots with an activity should be green; idle slots red, and an
     empty slot should turn green as soon as it is filled.
  2. Add editable Rest/sleep goals to both Daily and Weekly goals.
  3. Food activity quantity should offer `g`, `mg`, `ml`, `pcs` units.
  4. Diet summary and exercise-tracking progress exports (CSV/PDF) must be
     saved into the device Downloads folder, visible from a file manager.
- **Slot colours (`lib/screens/diet_screen.dart`):** `_slotTile` now fills
  emerald when the hour has entries and rose when empty; selection is shown by
  an orange border. Added `Semantics` labels (`Filled slot HH:00` /
  `Empty slot HH:00`) and updated the helper text.
- **Rest goals (`lib/models/diet_models.dart`, `lib/state/diet_state.dart`):**
  added `restGoalMinutes` to `DietDay` (default 480 min) and `DietWeekGoals`
  (default 3360 min), with JSON persistence, `restProgress`, remaining values,
  and inclusion in the 50%-goal status. `setGoals`/`setWeekGoals` accept the new
  value; `addEntry`/`removeEntry` preserve it. Defaults are derived from the
  Monday daily goal for unsaved weeks. Added editable "REST GOAL" / "WEEK REST
  GOAL" fields, DEFAULT/Restore support and progress rows to the UI.
- **Food quantity units:** added `kFoodQuantityUnits = [g, mg, ml, pcs]` and a
  unit selector in the food editor. Plain numeric amounts are sent to Gemini
  as `value unit`; free-form quantities still pass through unchanged.
  `DietEntry.quantityUnit` is persisted and included in the summary exports.
- **Downloads exports:** `ExportService.saveBytes` now calls
  `saveToAndroidDownloads()` first on Android. New `download_saver*.dart` files
  bridge to a `MethodChannel` (`com.insectcs.workoutapp/downloads`) implemented
  in `android/app/src/main/kotlin/.../MainActivity.kt` using `MediaStore.Downloads`
  with `DISPLAY_NAME`, `MIME_TYPE`, `RELATIVE_PATH = Download`, and `IS_PENDING`
  so no storage permission is required on Android 16. Non-Android/native and
  failed channel calls keep the existing app-documents fallback; web still
  triggers a browser download. This covers both diet summary exports and the
  Progress graph exports because they share `saveBytes`.
- **Exports content:** diet CSV/PDF now include the weekly Rest goal, per-day
  Rest goal, and the food quantity unit column.
- **Tests:** extended `test/diet_test.dart` with Rest-goal state/JSON tests,
  quantity-unit persistence plus a widget check that all four units are
  offered, and slot colour semantics checks before/after filling a slot.
- **Validation:** `dart format` clean, `flutter analyze lib test android`
  **No issues found**, `flutter test` **81/81 passed** at the time, and
  `flutter build apk --debug` succeeded (new Kotlin channel compiles).
- **Status:** **Uncommitted**; no release APK built yet. Needs on-device
  verification of coloured slots, goal editing and Downloads visibility.

### 2026-11-24 — Calories/BMI response History tab
- **Requested by user:** Add a Save response button at the end of both the
  Gemini-generated weekly calorie estimate and the BMI result; store those saved
  responses in a new History tab just beside BMI calculate.
- **Third tab (`lib/screens/calories_screen.dart`):** the Calories tab bar is now
  `Weekly estimate | BMI calculate | History`. Added `_formTabIndex` so visiting
  History preserves the last generator tab and its CTA label/scope. The bottom
  CTA is hidden on History, and the persisted tab index is bounds-checked to
  0–2.
- **Save flow:** `_resultScaffold` appends **Save to History** at the end of both
  result views. It becomes **Saved to History** (disabled) once the response id
  is in History, with a **View History** button that clears the current result
  and animates to tab 2. Generating a new weekly/BMI result also clears the
  opposite result so a stale response cannot be shown.
- **Persistence (`lib/models/calories_models.dart`,
  `lib/services/calorie_history_service.dart`):** new `SavedCalorieEntry`
  wrapper (separate history id/kind/savedAt around the response) and
  `CalorieHistoryStore` backed by the namespaced `LocalStore` key
  `workout_app.calories_history.v1`. Entries are newest-first, session-scoped,
  reopenable, and deletable through an `AppDialog` confirmation.
- **History UI:** empty state plus cards with title, response kind, preview,
  saved timestamp, **Open saved response**, and a delete icon. Reopening a card
  restores the exact weekly estimate or BMI result screen.
- **Tests:** extended `test/calories_screen_test.dart` with four tests — History
  tab empty state, weekly save/reopen, BMI save, and history JSON/session
  scoping. Full suite was 85/85 at the time; 87/87 after the YouTube fix.
- **Validation:** `dart format` clean, `flutter analyze lib test android`
  **No issues found**, `flutter test` **85/85 passed** at the time. This task
  changed no native code; the previous debug APK build still covers the Android
  channel.
- **Status:** **Uncommitted**; needs on-device UI verification.

### 2026-11-24 — Android YouTube links: preserve case-sensitive video IDs
- **Reported by user:** Android YouTube links showed “Video unavailable” in the
  YouTube app or “page isn't available” in the mobile browser, although the same
  links worked in the web build.
- **Root cause:** `VideoLaunchService` built `vnd.youtube://<videoId>`. Dart
  normalises URI hosts to lowercase, so a mixed-case ID such as `8iPEnn-ltC8`
  became `8ipenn-ltc8`. YouTube IDs are case-sensitive, so the app rejected the
  video. The custom scheme also had no useful fallback once the app opened.
- **Fix (`lib/services/video_launcher_service.dart`):** removed the
  `vnd.youtube://` host deep link. Direct video URLs are normalised to
  `https://www.youtube.com/watch?v=<id>`, keeping the ID in the query string
  where its case is preserved. Android App Links open the YouTube app when
  installed; otherwise the same HTTPS page opens in the browser. Added strict
  11-character ID validation and a YouTube search-URL fallback when a supplied
  link has no valid ID (both callers now pass the exercise name as
  `searchQuery`).
- **Shared parser:** added public `youTubeVideoId()` and `canonicalWatchUrl()`;
  `plan_screen.dart`'s `youtubeVideoIdFromUrl()` now delegates to them, so
  thumbnails and launches use the same case-sensitive logic.
- **Tests:** extended `test/plan_video_test.dart` with mixed-case ID
  preservation across `youtu.be`, `m.youtube.com/watch`, and `/shorts`, plus
  rejection of malformed and search URLs. Full suite was 87/87 at the time;
  91/91 after the return-to-form buttons were added.
- **Validation:** `dart format` clean, `flutter analyze lib test android`
  **No issues found**, `flutter test` **87/87 passed** at the time. No
  native/manifest changes were needed.
- **Status:** **Uncommitted**; needs on-device verification with a mixed-case ID
  exercise such as Incline Dumbbell Press (`8iPEnn-ltC8`).

### 2026-11-24 — Generated results return to the edit screen
- **Requested by user:** End every Gemini-generated Plan result (weekly and
  single day) and Calories result (weekly estimate and BMI) with a
  **Go to previous screen** button that sends the user back to the edit form.
- **Plan (`lib/screens/plan_screen.dart`):** `_buildResultView` now ends with an
  outlined **Go to previous screen** button after **Create another plan**. Its
  `_returnToEditScreen` clears the persisted result and animates to the tab that
  matches `plan.scope` (Weekly = 0, Single day = 1). Using the result's scope
  instead of `_formTabIndex` also handles plans reopened from History while the
  tab controller is on tab 2.
- **Calories (`lib/screens/calories_screen.dart`):** `_resultScaffold` now takes
  `isWeekly` and ends with the same button after **Create another estimate**.
  `_returnToEditScreen` clears both persisted results and restores the matching
  form (Weekly estimate = 0, BMI calculate = 1), including saved responses
  reopened from History.
- **Tests:** added two Plan tests (one per `PlanScope`) and two Calories tests
  (weekly/BMI). Each prewrites the result JSON, taps the new button, and asserts
  that the result is gone and the correct form CTA is visible. Full suite was
  91/91 at the time; 97/97 after the replay-landmark work.
- **Validation:** `dart format` clean, `flutter analyze lib test android`
  **No issues found**, `flutter test` **91/91 passed** at the time, and
  `flutter build apk --debug` succeeded. No native/manifest changes.
- **Status:** **Uncommitted**; needs on-device verification with a freshly built
  APK.

### 2026-11-24 — Recorded landmarks on live-session replay video
- **Requested by user:** A live tracking session's saved video preview in Pose
  History should show the landmarks that were recorded during live tracking,
  not just the video and metrics.
- **Capture (`lib/screens/pose_tracking_screen.dart`):** `_processLiveFrame`
  now calls `_recordPoseFrame()` after a successful detection. Samples are timed
  from `_videoRecordingStartedAt` (set when `startVideoRecording()` completes),
  throttled to 5 fps, capped at 3600 samples (12 minutes), and skipped for
  frames with no usable visualised landmark. Each sample is compacted to the
  13 landmarks drawn by `PoseSkeletonPainter`.
- **Persistence (`lib/models/pose_history_models.dart`):** new
  `PoseReplayFrame` stores `tMs` plus a flat integer array (x/y quantised to
  0..1000, confidence to 0..100). `LiveTrackingSession.poseFrames` is optional
  and backwards-compatible; `landmarksMirroredX` records the front-camera
  mirror state so replay can flip samples back onto the raw recorded video.
  The existing `keypoints` last-frame snapshot is preserved for older sessions.
- **Replay (`lib/screens/live_tracking_history_screen.dart`,
  `lib/widgets/pose_replay_overlay.dart`):** `_SessionVideoPlayer` listens to
  playback position and rebuilds only when the nearest recorded sample changes.
  A `PoseReplayOverlay` paints that sample with `PoseSkeletonPainter` inside the
  video's `AspectRatio`, so the skeleton tracks the person as the clip plays.
  The old standalone orange skeleton card now appears only for legacy sessions
  without timed frames.
- **Tests:** added `test/pose_replay_test.dart` (quantization, JSON round-trip,
  malformed/legacy frames, timestamp lookup, overlay painting and front-camera
  unmirroring) and extended the persistence round-trip fixture. Full suite is
  97/97.
- **Validation:** `dart format` clean, `flutter analyze lib test android`
  **No issues found**, `flutter test` **97/97 passed**, and
  `flutter build apk --debug` succeeded. No native/manifest changes.
- **Status:** Included in v1.2.0; needs on-device verification with a live
  session recorded on the Android 16 device.

### 2026-11-24 — Secret audit and v1.2.0 release
- **Requested by user:** Before pushing to GitHub and uploading an updated APK
  to GitHub Releases, verify that no sensitive data would be published.
- **Audit:** Scanned the working-tree diff, all untracked files, tracked source
  and both APKs for real API-key, token, private-key and signing-password
  patterns: **0 hits**. `env.json`, `android/key.properties`,
  `android/app/release-keystore.jks`, Gradle caches and `build/` remain ignored
  and untracked; no `git add -f` was used. The only key-like strings in tests
  are obvious placeholders (`AIzaSyAbCdEfGh1234567890`, `SECRET_KEY_VALUE`).
  Local absolute paths in `PROJECT_STATE.md` were replaced with generic
  `<project-root>` / `<backup-location>` placeholders.
- **APK:** Bumped `pubspec.yaml` to `1.2.0+3`; `flutter build apk --release`
  produced a universal signed APK at
  `build/app/outputs/flutter-apk/app-release.apk` (105,607,424 bytes).
  `apksigner verify --print-certs` confirmed a valid **v2** signature from the
  existing `CN=Workout Tracking` certificate (SHA-256 digest
  `c12b84b5dc519c096d3bf1aa3c70c88e747dd0a56c11cf6c0ffc962c7bd00c63`).
  `aapt2 dump badging` confirmed `versionCode=3`, `versionName=1.2.0`, app ID
  `com.insectcs.workoutapp`. APK SHA-256:
  `26a05c1f37801e663b190431e6cdd6989354c30d3816e3ab8465c6181618c885`.
- **Git/GitHub:** Local commit author was switched to
  `insect-cs@users.noreply.github.com` for this release. `main` and annotated
  tag **v1.2.0** were pushed. `gh` CLI is not installed, so the release and
  assets were published through the GitHub REST API using the cached git
  credential (token never printed or written to the repo). Release:
  https://github.com/insect-cs/Workout_Tracking_App/releases/tag/v1.2.0
- **Validation:** `flutter analyze lib test android` clean, `flutter test`
  **97/97 passed**, `flutter build apk --release` succeeded, strict secret scan
  of the fresh APK found 0 hits.
- **Status:** **Published**; only remaining work is the user's on-device
  verification pass.

### 2026-11-24 — Final end-of-day state checkpoint
- **Purpose:** Canonical resume point for the next session; supersedes the
  earlier "uncommitted" notes above. The working tree is clean.
- **Code state:** All 2026-11-24 fixes are in commit `7bfa403`
  (`Release v1.2.0: pose replay, diet/export, history and Android fixes`) on
  `main`, tag **v1.2.0**, `pubspec.yaml` version `1.2.0+3` (versionCode 3).
  `main` is in sync with `origin/main`; no staged or untracked changes remain.
  Release:
  https://github.com/insect-cs/Workout_Tracking_App/releases/tag/v1.2.0
- **Published assets:** `app-release.apk` (105,607,424 bytes) and
  `app-release.apk.sha256`. APK SHA-256:
  `26a05c1f37801e663b190431e6cdd6989354c30d3816e3ab8465c6181618c885`.
  The public release asset was downloaded and its hash re-verified against the
  local build; `apksigner` confirmed a valid v2 signature from the existing
  Workout Tracking certificate.
- **Validation:** `flutter analyze lib test android` clean, `flutter test`
  **97/97 passed**, `flutter build apk --debug` and `flutter build apk --release`
  both succeeded, strict secret scan found 0 real credentials in the diff,
  untracked files, tracked source or APKs.
- **Hygiene:** Commit authored as `insect-cs@users.noreply.github.com`; ignored
  secrets (`env.json`, `key.properties`, release JKS, `build/`) were never
  staged; local absolute paths in this document were replaced with generic
  placeholders.
- **Still open:** User on-device verification checklist is in §7 (live
  landmarks/angles/reps, diet colours/goals/units, Downloads exports, Calories
  History, YouTube links, return buttons, replay landmarks). Also open: move
  the keystore backup ZIP to durable offline storage, decide on a backend
  Gemini proxy, wire pose reps into `WorkoutState`, and the smaller backlog in
  §7.
- **Next session:** Start from §0 and this entry. There are no uncommitted
  changes to recover. If the device still reports no pose, use the on-screen
  detection badge text for the next diagnosis.

### 2026-11-25 — Android 16 still shows no live landmarks: MediaPipe path hardened
- **Reported by user:** After reviewing the project state, the Android 16
  device still showed no 3D landmarks during the live video stream. Stopping
  the session saved only a video-only entry whose message was
  “No live tracking happened”.
- **State finding:** `PROJECT_STATE.md` ended at the clean v1.2.0 checkpoint,
  but the working tree contained an uncommitted 2026-11-25 rewrite dated after
  that document: `pose_mediapipe_service.dart`, a native
  `PoseLandmarker` bridge, a bundled `pose_landmarker_lite.task`, and native
  video-frame decoding. The GitHub v1.2.0 APK does **not** contain that work.
- **Root causes addressed:**
  1. A single-plane NV21 buffer with row padding longer than
     `width × height × 1.5` was only truncated. That keeps padding bytes and
     drops the bottom rows, so MediaPipe/ML Kit receive a corrupted image.
     `packedNv21FromCameraImage()` now rebuilds a tight NV21 buffer using the
     Y and chroma row strides; exact-size buffers are still returned unchanged.
  2. MediaPipe IMAGE-mode landmarks often report 0 or very low visibility.
     `PoseMediapipeService` was discarding any point below 0.2, so a real pose
     could yield zero drawable landmarks. Low/zero values are now treated as
     unknown (confidence 1.0), and the same conversion is used when selecting
     the primary subject.
  3. If MediaPipe failed to load or found no pose, the app had no detector
     fallback and the saved History entry hid the real reason. Live frames now
     fall back to ML Kit, and the video-only feedback includes the actual
     detector message. Live session `engine` now reports
     “MediaPipe Pose Landmarker” on native, and the analyzing card no longer
     says “ML Kit”.
- **Files:** `lib/services/pose_analysis_service.dart`,
  `lib/services/pose_mediapipe_service.dart`,
  `lib/screens/pose_tracking_screen.dart`, `test/pose_frame_test.dart`,
  `test/pose_mediapipe_test.dart`, `PROJECT_STATE.md`.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **108/108 passed**, `flutter build apk --debug` succeeded and produced
  `build/app/outputs/flutter-apk/app-debug.apk` with the bundled MediaPipe task
  and JNI libraries.
- **Status:** Superseded by the next entry — the user reported no landmarks and
  no detector error even after installing that APK.

### 2026-11-25 — Root cause: video recording silently killed camera frame stream
- **Reported by user:** Installed the fresh debug APK, but live tracking still
  showed no 3D landmarks and no error/detection message at all.
- **Root cause:** In `camera_android_camerax` 0.6.30,
  `startVideoRecording()` calls `startVideoCapturing()` without a stream
  callback. On devices below CameraX `INFO_SUPPORTED_HARDWARE_LEVEL_3`, that
  method unbinds the `imageAnalysis` use case so a previously started
  `startImageStream()` stops silently. The app kept showing `CameraPreview`
  (preview use case still bound) and recorded a video, but the pose detector
  received **zero frames**, explaining both “no landmarks” and “no error”.
- **Fix (`lib/screens/pose_tracking_screen.dart`):**
  - On Android, start the recording with
    `startVideoRecording(onAvailable: _processLiveFrame)` instead of calling
    `startImageStream()` and then starting a plain recording. The callback is
    the only plugin-supported way to keep frames flowing during a recording.
  - Added a 3-second frame watchdog. If no frame arrives, it stops the stalled
    recording, switches to `startImageStream(_processLiveFrame)` so tracking
    still works, and shows “Recording blocked camera frames on this device;
    switched to tracking without video”. Non-recording stalls show an explicit
    “No camera frames received” message.
  - Added visible diagnostics: the live overlay badge now reads
    `N LANDMARKS · N FRAMES`, and the stats card reports the frame count and
    engine (`MediaPipe Pose Landmarker` / `MoveNet (TF.js)`) when there is no
    error. `_liveFrameCount` is reset per session.
- **Files:** `lib/screens/pose_tracking_screen.dart`, `PROJECT_STATE.md`.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **108/108 passed**, `flutter build apk --debug` succeeded and the APK was
  rebuilt at 17:46 local time.
- **Status:** Superseded by the next entry — frames now reached the detector,
  but the native visibility cast failed and the overlay was not tracking one
  subject stably.

### 2026-11-25 — Fix tracking accuracy, camera angle and MediaPipe cast errors
- **Reported by user:** The newest APK finally showed detector messages, but
  the camera capture still required manually adjusting the phone to get the
  correct angle, the 3D landmarks moved on their own and generated/recorded
  activity, and two errors appeared: `Detection issue: No pose landmarks in
  this camera frame` and `PlatformException(POSE_DETECTION_ERROR,
  java.util.optional cannot be cast to java.lang.Number, null, null)`.
- **Root causes addressed:**
  1. **Native cast bug:** MediaPipe 1.2.2 declares
     `NormalizedLandmark.visibility()`/`presence()` as `Optional<Float>`, not
     `Number`. `MainActivity.kt` cast visibility to `Number` for every
     landmark, so every successful detection threw before any landmark could
     cross the MethodChannel. It now reads `visibility().orElse(presence())`
     and infers safely.
  2. **Per-frame re-detection jitter:** The native landmarker ran in
     `RunningMode.IMAGE`, so each frame was treated as an unrelated still.
     It now uses `RunningMode.VIDEO` with strictly increasing timestamps and
     lower 0.35 detection/presence/tracking thresholds, letting MediaPipe keep
     the same person across frames. `MPImage` is closed after each inference.
  3. **Subject switching and false activity:** `PoseMediapipeService` now
     scores multiple poses with a continuity bonus toward the landmarks it is
     already tracking, rejects clearly upside-down full bodies (wrong camera
     rotation probe), and exponentially smooths the 13 drawn points. Sudden
     jumps snap to the new pose instead of drawing a skeleton between two
     people.
  4. **Held frames creating phantom reps:** Brief missed detections now reuse
     the last skeleton for up to 600 ms, but `PoseFrame.isStale` marks it so the
     live screen draws it while skipping knee/elbow counters, exercise
     classification and replay sampling. Real native exceptions are never
     hidden behind a held frame.
  5. **Camera-angle friction:** Live tracking now prefers the front camera
     when available (the switch button still shows the picker), and the
     feedback tells the user to frame head through feet. The rotation that
     actually finds a plausible upright subject is cached; changing rotation
     clears the smoothing history so two viewpoints are never blended.
- **Files:** `android/app/src/main/kotlin/com/insectcs/workoutapp/MainActivity.kt`,
  `lib/services/pose_mediapipe_service.dart`,
  `lib/services/pose_analysis_service.dart`,
  `lib/screens/pose_tracking_screen.dart`, `test/pose_mediapipe_test.dart`,
  `PROJECT_STATE.md`.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **108/108 passed**, `flutter build apk --debug` succeeded and rebuilt
  `build/app/outputs/flutter-apk/app-debug.apk` with the bundled MediaPipe task
  and JNI libraries.
- **Status:** Superseded by the next entry; the app still required manual camera
  adjustment and could count landmark jitter as activity.

### 2026-11-25 — Use all native cameras and stop landmark-generated activity
- **Reported by user:** The available stream still had to be adjusted many
  times, and 3D landmarks were still generating activity by themselves.
- **Root causes addressed:**
  1. **One camera was asked to do all the work:** live tracking now orders every
     camera returned by `availableCameras()` as front → back → external. If the
     active lens has frames but no stable person for five seconds, a watchdog
     switches to the next native camera automatically; the preview switch
     button still allows a manual choice. Switching now awaits release of the
     old controller (including stopping an active recording) so Android does
     not hit a "camera busy" race.
  2. **Drawing confidence leaked into counting confidence:** low/zero MediaPipe
     visibility is promoted to 1.0 only for drawing, while the original score
     is preserved as `PoseKeypoint.reliability`. Joint angles, exercise
     classification and counters require reliability ≥ 0.5 on the relevant
     landmarks instead of trusting the promoted overlay value.
  3. **Image-space angles distorted by viewpoint:** joint angles now prefer
     MediaPipe's metric world coordinates (`angleBetweenWorldKeypoints`) and
     fall back to aspect-corrected 2D only for ML Kit/web frames.
  4. **Jitter could still arm a rep:** activity is only accepted after at least
     six consecutive fresh, reliable frames whose tracked-body centre stays
     within 20% of the previous frame. Held/stale skeletons remain visible but
     never reach counters. A squat now needs <100° held for 250ms before a
     standing lockout can count; arm repetitions need <80° held for 250ms.
     Exercise labels also require the same deep excursion instead of
     classifying a single noisy frame.
- **Files:** `lib/screens/pose_tracking_screen.dart`,
  `lib/services/pose_analysis_service.dart`, `test/pose_frame_test.dart`,
  `PROJECT_STATE.md`.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **112/112 passed**, `flutter build apk --debug` succeeded and rebuilt
  `build/app/outputs/flutter-apk/app-debug.apk` at 18:16 local time.
- **Status:** **Uncommitted; no release APK built.** Install this newest debug
  APK and start live tracking; the app should try the device's cameras by
  itself, show "Stabilizing tracking on this person..." briefly, and only
  increment reps/name an exercise after sustained real movement. If landmarks
  still move independently, report the exact on-screen detector/status text.
- **State save:** Confirmed at 18:19 that this checkpoint matches the working
  tree; no code changes were made after the 18:16 APK build.

### 2026-11-26 — Restore verified camera path and layer MediaPipe 3D landmarks
- **Requested by user:** The 24 November released Android build had no camera
  issues and could use all cameras on the device. Use those camera properties,
  and on top of them put MediaPipe 3D landmarks that detect the person in real
  time in a guided, structured overlay, without stale movements or landmarks
  generating activity on their own.
- **Camera restored to the 2026-11-24 released code
  (`lib/screens/pose_tracking_screen.dart`):**
  - `availableCameras()` is enumerated and **every** returned camera is shown
    in the picker when there is more than one; a single camera starts directly.
    The automatic front→back→external failover watchdog, ordered candidate
    list and "Trying <camera>..." auto-switching were removed, so the detector
    no longer fights the user over framing/lens choice. The switch button still
    re-opens the full picker and now waits for the old lens to be released.
  - The verified controller properties are unchanged: `ResolutionPreset.medium`,
    `enableAudio: false`, NV21 on Android / BGRA on iOS / unknown on web and
    `FlashMode.off` on native. Web/iOS use a plain image stream with recording
    started afterwards without blocking it. Android uses the recording's
    `onAvailable` callback instead (see the follow-up entry below), because
    CameraX unbinds `ImageAnalysis` for a plain recording. The frame watchdog
    only recovers a stalled frame source; it never changes the selected camera.
  - Native mirroring stays off (the native `CameraPreview` is not mirrored);
    web front-camera mirroring is retained so the skeleton lines up with the
    preview.
- **MediaPipe layer kept on top:** Android still uses the native
  `PoseLandmarker` in VIDEO mode with strictly increasing timestamps, lower
  0.35 thresholds and metric world coordinates; ML Kit remains a fallback; web
  uses MoveNet. The structured 13-joint skeleton is smoothed, follows the
  nearest previously tracked subject, rejects wrong-rotation upside-down
  poses, and now colours nearer (negative z) joints brighter for a clearer 3D
  read. The live badge reads `N 3D LANDMARKS · N FRAMES` and the on-screen
  guidance asks the user to frame head through feet.
- **No self-generated activity:** held skeletons are still marked `isStale`
  and are drawn only; stale frames bypass counters, classification and replay
  sampling. Counters still require ≥6 consecutive fresh, reliable, same-subject
  frames, raw visibility ≥0.5 (not the promoted draw value), metric joint
  angles and 250 ms held squat/arm excursions. Structural plausibility now
  ignores joints with visibility ≤0.2 so an unreliable ankle cannot reject a
  valid standing subject.
- **Files:** `lib/screens/pose_tracking_screen.dart`,
  `lib/services/pose_mediapipe_service.dart`,
  `lib/widgets/pose_skeleton_painter.dart`, `test/pose_frame_test.dart`,
  `test/pose_mediapipe_test.dart`, `PROJECT_STATE.md`.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **114/114 passed** (new tests cover stale held skeletons and unreliable-joint
  structural checks), `flutter build apk --debug` succeeded and rebuilt
  `build/app/outputs/flutter-apk/app-debug.apk` (329,839,483 bytes, 11:11 local)
  with `assets/pose_landmarker_lite.task` and the MediaPipe JNI libraries
  verified inside it.
- **Status:** Superseded by the on-device camera-transport fix immediately
  below (the plain recording still unbound CameraX image analysis on the test
  device).

### 2026-11-26 — On-device fix: keep CameraX `ImageAnalysis` alive while recording
- **User report:** the Android 16 preview/video feed was smooth, but the amber
  badge read `Recording blocked camera frames on this device, tracking without
  video`. That message came from the frame watchdog, not the pose detector.
- **Root cause:** verified in `camera_android_camerax-0.6.30`
  (`android_camera_camerax.dart`, `startVideoCapturing()`): calling plain
  `startVideoRecording()` passes no stream callback, so the plugin calls
  `_unbindUseCaseFromLifecycle(imageAnalysis!)`. `Preview` and `VideoCapture`
  stay bound, so the camera looks healthy, but `_processLiveFrame` is never
  called and `_liveFrameCount` stays at zero. This is the same CameraX hardware
  limitation documented in the earlier 2026-11-25 entry; restoring the Nov 24
  plain-stream-plus-recording combination reintroduced it on this device.
- **Fix (`lib/screens/pose_tracking_screen.dart`):**
  - Android now starts recording with
    `controller.startVideoRecording(onAvailable: _processLiveFrame)`. The plugin
    rebinds `ImageAnalysis` through `onStreamedFrameAvailable()`, so the same
    frames feed the MP4 **and** MediaPipe. Web/iOS keep the plain image stream
    plus non-blocking recording.
  - Reintroduced `_recordingOwnsFrameStream` for watchdog recovery only: if a
    device still yields zero frames, the stalled recording is stopped and
    `_startImageStreamOnly()` retries without video. The old alarming message
    became `Tracking without video on this device`, and it clears on the next
    real frame. The watchdog never changes lenses or camera properties.
  - Teardown uses `controller.value.isStreamingImages` as the single source of
    truth so a callback-owned stream is not stopped twice, and the now-unused
    `_isStreamingLiveFrames` flag was removed.
  - Lens enumeration/picker, `ResolutionPreset.medium`, NV21 on Android,
    `enableAudio: false`, `FlashMode.off` and manual switching remain exactly as
    in the verified Nov 24 build.
- **Files:** `lib/screens/pose_tracking_screen.dart`, `PROJECT_STATE.md`.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **114/114 passed**, `flutter build apk --debug` succeeded and rebuilt
  `build/app/outputs/flutter-apk/app-debug.apk` (329,841,137 bytes, 11:48 local)
  with `assets/pose_landmarker_lite.task` and the MediaPipe JNI libraries
  verified inside the APK.
- **Status:** Superseded by the native-frame orientation fix immediately below.

### 2026-11-26 — Native camera frame orientation for live landmarks
- **User report:** 3D landmarks appeared, but the subject could only be framed
  by constantly changing the phone angle. The user asked for the live frame to
  look like a native Android camera video so the subject can be captured
  normally.
- **Root cause:** `_buildLiveTrackingPreview()` forced every live preview into
  `1 / controller.value.aspectRatio` (portrait) regardless of device
  orientation. `CameraPreview` itself uses `controller.value.aspectRatio` in
  landscape and rotates the texture with `RotatedBox`. The outer box therefore
  squeezed/letterboxed the native frame in landscape, so the landmark overlay
  (already in display-rotated coordinates from the native detector) no longer
  lined up with the subject and framing felt wrong.
- **Fix (`lib/screens/pose_tracking_screen.dart`):**
  - The preview box now mirrors the camera plugin's own orientation rules:
    `recordingOrientation` while recording, otherwise
    `previewPauseOrientation ?? lockedCaptureOrientation ?? deviceOrientation`.
    Landscape uses the sensor aspect ratio; portrait uses its inverse.
  - `ValueListenableBuilder<CameraValue>` rebuilds the preview when orientation
    or recording state changes, so the overlay keeps matching the native frame
    if the device is rotated.
  - The Android recording-owned frame path and Nov 24 lens/picker properties
    are unchanged; only the display box follows the native video frame.
- **Files:** `lib/screens/pose_tracking_screen.dart`, `PROJECT_STATE.md`.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **114/114 passed**, `flutter build apk --debug` succeeded and rebuilt
  `build/app/outputs/flutter-apk/app-debug.apk` (329,842,569 bytes, 12:08 local)
  with `assets/pose_landmarker_lite.task` and the MediaPipe JNI libraries
  verified inside the APK.
- **Status:** Superseded by the portrait-default stream fix immediately below.

### 2026-11-26 — Portrait-default live video/frame stream
- **User report:** after installing the orientation-fix APK, the Android device
  still opened the live video stream in landscape. The user wants the stream to
  be portrait by default so the subject can be framed normally.
- **Root cause:** the app never set a preferred Activity orientation, and the
  `CameraController` capture orientation was left unlocked. CameraX therefore
  took `deviceOrientation` from the physical device; when the phone was held in
  landscape, `recordingOrientation`, the preview texture and the analysis frame
  were all landscape. The previous fix only made the overlay match that
  landscape frame; it did not choose portrait as the default.
- **Fix (`lib/screens/pose_tracking_screen.dart`):**
  - On Android, the pose screen requests `DeviceOrientation.portraitUp` in
    `initState` and restores the platform default when disposed.
  - After `controller.initialize()` and before any stream/recording starts, the
    controller is locked with
    `lockCaptureOrientation(DeviceOrientation.portraitUp)`. This makes CameraX
    target portrait rotation for `VideoCapture`, `ImageCapture` and
    `ImageAnalysis`, so the saved video and MediaPipe frames are portrait even
    if the phone is physically landscape. A lock failure is logged and tracking
    continues with the previous behavior.
  - `_processLiveFrame` treats a successful portrait lock as display rotation
    0, overriding the physical `Display.getRotation()` value. This keeps
    MediaPipe/ML Kit landmark rotation consistent with the locked frame.
  - The preview box continues to mirror the camera plugin's applicable
    orientation; `lockedCaptureOrientation`/`recordingOrientation` are now
    portrait by default. Lens enumeration/picker, `ResolutionPreset.medium`,
    NV21, `enableAudio: false`, `FlashMode.off`, manual switching, the
    recording `onAvailable` frame callback and all anti-phantom gates are
    unchanged.
- **Files:** `lib/screens/pose_tracking_screen.dart`, `PROJECT_STATE.md`.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **114/114 passed**, `flutter build apk --debug` succeeded and rebuilt
  `build/app/outputs/flutter-apk/app-debug.apk` (329,844,390 bytes, 12:34 local)
  with `assets/pose_landmarker_lite.task` and the MediaPipe JNI libraries
  verified inside the APK.
- **Status:** Superseded by the native Activity orientation lock immediately
  below. The Flutter/Dart-only lock did not change the on-device stream.

### 2026-11-26 — Native Android Activity orientation lock for portrait stream
- **User report:** after installing the Flutter-locked APK, the live stream still
  opened in landscape. The user asked to use native Android camera/Activity
  properties because portrait is required.
- **Root cause:** `SystemChrome.setPreferredOrientations()` and
  `CameraController.lockCaptureOrientation()` are Dart/platform-channel calls
  made after the Activity and camera use cases have already been configured from
  the physical device orientation. On this device they did not take effect for
  the CameraX preview/video stream, so `recordingOrientation` and the visible
  frame stayed landscape.
- **Fix:**
  - `android/app/src/main/AndroidManifest.xml`: the launcher Activity now
    declares `android:screenOrientation="portrait"` and
    `android:resizeableActivity="false"` (with the lint suppression), so the
    native Activity starts in portrait before Flutter or CameraX asks for a
    rotation.
  - `android/app/src/main/kotlin/.../MainActivity.kt`: `onCreate()` sets
    `requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT` as a
    second native guarantee.
  - `lib/screens/pose_tracking_screen.dart`: still requests/locks portrait from
    Dart, but landmark detection no longer consults the physical
    `Display.getRotation()` on Android. Android frames are always rotated as
    portrait because the Activity/CameraX stream is now natively portrait.
  - Lens enumeration/picker, `ResolutionPreset.medium`, NV21, `enableAudio:
    false`, `FlashMode.off`, manual switching, the recording `onAvailable` frame
    callback and all anti-phantom gates remain unchanged.
- **Files:** `android/app/src/main/AndroidManifest.xml`,
  `android/app/src/main/kotlin/com/insectcs/workoutapp/MainActivity.kt`,
  `lib/screens/pose_tracking_screen.dart`, `PROJECT_STATE.md`.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **114/114 passed**, `flutter build apk --debug` succeeded and rebuilt
  `build/app/outputs/flutter-apk/app-debug.apk` (329,844,022 bytes, 12:48 local)
  with `assets/pose_landmarker_lite.task` and the MediaPipe JNI libraries
  verified inside the APK. `aapt2 dump xmltree` confirmed the packaged manifest
  has `screenOrientation=1` (portrait) and `resizeableActivity=false`.
- **Status:** Superseded by the landscape-default stream change below. The user
  tested the native portrait build and asked for landscape instead.

### 2026-11-26 — Landscape-default live video/frame stream
- **User report:** after testing the native portrait APK, the user asked to
  change the live video stream orientation to landscape by default.
- **Decision:** use the camera's natural landscape sensor frame and lock the
  Android Activity plus CameraX capture use cases to `landscapeLeft`. This keeps
  the preview, saved video and MediaPipe frame rotation consistent.
- **Fix:**
  - `android/app/src/main/AndroidManifest.xml`: Activity now declares
    `android:screenOrientation="landscape"` (still non-resizable).
  - `android/app/src/main/kotlin/.../MainActivity.kt`: `onCreate()` sets
    `requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE`.
  - `lib/screens/pose_tracking_screen.dart`: the Dart request is now
    `DeviceOrientation.landscapeLeft`, and `lockCaptureOrientation()` uses the
    same value before the stream/recording starts.
  - Android landmark detection now assumes `Surface.ROTATION_90` (display
    rotation step 1) for the locked landscapeLeft stream rather than portrait
    rotation 0. All other camera properties, the recording `onAvailable` frame
    callback and anti-phantom gates are unchanged.
- **Files:** `android/app/src/main/AndroidManifest.xml`,
  `android/app/src/main/kotlin/com/insectcs/workoutapp/MainActivity.kt`,
  `lib/screens/pose_tracking_screen.dart`, `PROJECT_STATE.md`.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **114/114 passed**, `flutter build apk --debug` succeeded and rebuilt
  `build/app/outputs/flutter-apk/app-debug.apk` (329,844,184 bytes, 13:00 local)
  with `assets/pose_landmarker_lite.task` and the MediaPipe JNI libraries
  verified inside the APK. `aapt2 dump xmltree` confirmed the packaged manifest
  has `screenOrientation=0` (landscape) and `resizeableActivity=false`.
- **Status:** Superseded by the live-stream-scoped lock below. The APK-wide
  landscape lock was rejected by the user.

### 2026-11-26 — Landscape only for the live squat video stream
- **User correction:** “don't make the whole apk landscape, in pose tracking in
  live tracking when live squat tracking is clicked the video stream appears
  so, make this video stream landscape.”
- **Root cause:** the previous fix set `android:screenOrientation="landscape"`
  in `AndroidManifest.xml` and `SCREEN_ORIENTATION_LANDSCAPE` in
  `MainActivity.onCreate()`, so every screen opened in landscape. The requested
  behavior is normal app orientation everywhere else and landscape only for the
  live camera stream.
- **Fix:**
  - `android/app/src/main/AndroidManifest.xml`: removed the global
    `screenOrientation`, `resizeableActivity` and `tools` entries; the Activity
    is back to the original unspecified orientation.
  - `android/app/src/main/kotlin/.../MainActivity.kt`: removed the `onCreate()`
    lock. The existing `com.insectcs.workoutapp/pose_video` channel now handles
    `lockLandscapeOrientation` and `restoreOrientation`; the native side saves
    `requestedOrientation` once and restores it when the live session ends.
  - `lib/services/pose_video_frame_io.dart` and `pose_video_frame_stub.dart`:
    expose the two new channel methods to Dart (stub is a no-op on web).
  - `lib/screens/pose_tracking_screen.dart`: `_startLiveWithCamera()` calls
    `_lockLiveLandscape()` before creating/initializing `CameraController`, then
    locks CameraX capture to `DeviceOrientation.landscapeLeft`.
    `_stopLiveTrackingSession()`, the camera-start error path, and `dispose()`
    restore the original app orientation after the camera is released.
  - Android landmark detection still treats the live frames as
    `Surface.ROTATION_90` (step 1) because the stream is locked landscapeLeft.
    Lens enumeration/picker, `ResolutionPreset.medium`, NV21, `enableAudio:
    false`, `FlashMode.off`, manual switching, the recording `onAvailable` frame
    callback and anti-phantom gates are unchanged.
- **Files:** `android/app/src/main/AndroidManifest.xml`,
  `android/app/src/main/kotlin/com/insectcs/workoutapp/MainActivity.kt`,
  `lib/services/pose_video_frame_io.dart`,
  `lib/services/pose_video_frame_stub.dart`,
  `lib/screens/pose_tracking_screen.dart`, `PROJECT_STATE.md`.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **114/114 passed**, `flutter build apk --debug` succeeded and rebuilt
  `build/app/outputs/flutter-apk/app-debug.apk` (329,845,003 bytes, 13:18 local)
  with `assets/pose_landmarker_lite.task` and the MediaPipe JNI libraries
  verified inside the APK. `aapt2 dump xmltree` confirmed the packaged manifest
  contains **no** `screenOrientation` or `resizeableActivity` entry, so the
  APK-wide landscape lock is gone.
- **Status:** Superseded by the native CameraX selector / stream-only fix below.
  The user reported that the whole app still rotated when live tracking opened.

### 2026-11-26 — Native CameraX camera selector, no Activity rotation
- **User report:** “whole app is getting rotated when clicked on live squat
  tracking. use native camera selector and back to ml kit by google.” Follow-up
  choices: keep MediaPipe for now (“use mediapipe for now”) and replace the
  Flutter camera picker with a native CameraX selector.
- **Root cause:** the scoped lock still changed `requestedOrientation`, so the
  Activity/window (not just the video stream) rotated when live tracking began.
  The user wants the app UI to stay in its normal orientation while only the
  live camera stream is landscape.
- **Fix:**
  - Removed every Activity orientation change: no manifest
    `screenOrientation`, no `onCreate()` lock, no
    `lockLandscapeOrientation`/`restoreOrientation` channel or Dart wrappers.
  - Added `android/app/src/main/kotlin/.../NativeCameraSelector.kt`: Android
    lists cameras through CameraX `ProcessCameraProvider.availableCameraInfos`,
    reading native id/lens/sensor rotation from Camera2 characteristics. A new
    `com.insectcs.workoutapp/native_camera_selector` channel requests the camera
    permission and returns every bindable lens, including multiple same-side
    cameras.
  - Added `lib/services/native_camera_selector.dart` with conditional IO/stub
    implementations. `pose_tracking_screen.dart` now uses that native list for
    the live picker and maps the selected id back to a `CameraDescription`, so
    the verified camera plugin still owns preview/video/frame transport.
  - `controller.lockCaptureOrientation(DeviceOrientation.landscapeLeft)` is the
    only landscape setting. CameraX target rotation rotates the preview texture,
    saved video and `ImageAnalysis` frames inside the unchanged Activity UI.
  - Android landmark detection keeps using `Surface.ROTATION_90` (step 1) for
    the locked landscape frames. MediaPipe remains the primary detector and ML
    Kit remains the fallback. Lens properties (`ResolutionPreset.medium`, NV21,
    `enableAudio: false`, `FlashMode.off`, manual switching), the recording
    `onAvailable` frame callback and anti-phantom gates are unchanged.
- **Files:** `android/app/build.gradle.kts`,
  `android/app/src/main/kotlin/com/insectcs/workoutapp/MainActivity.kt`,
  `android/app/src/main/kotlin/com/insectcs/workoutapp/NativeCameraSelector.kt`,
  `lib/services/native_camera_selector.dart`,
  `lib/services/native_camera_selector_io.dart`,
  `lib/services/native_camera_selector_stub.dart`,
  `lib/services/pose_video_frame_io.dart`,
  `lib/services/pose_video_frame_stub.dart`,
  `lib/screens/pose_tracking_screen.dart`, `PROJECT_STATE.md`.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **114/114 passed**. The first APK build failed because `ProcessCameraProvider`
  was imported from `androidx.camera.core`; it was corrected to
  `androidx.camera.lifecycle.ProcessCameraProvider`. The final
  `flutter build apk --debug` succeeded and rebuilt
  `build/app/outputs/flutter-apk/app-debug.apk` (329,846,846 bytes, 13:40 local)
  with `assets/pose_landmarker_lite.task` and the MediaPipe JNI libraries
  verified inside the APK. `aapt2 dump xmltree` confirmed the packaged manifest
  contains **no** `screenOrientation` or `resizeableActivity` entry.
- **Status:** Superseded by the camera-plugin priming fix below.

### 2026-11-26 — Fix `CameraInfo` cast error after native picker change
- **User report:** clicking Live Squat Tracking fails with
  `could not start live camera: type 'camerainfo' is not a subtype of type
  'camerainfo' in type cast where camerainfo is from
  package:camera_android_camerax/src/camerax_library.g.dart ... camerax_library.dart`.
- **Root cause:** the native CameraX selector replaced the app's only call to
  `availableCameras()`. In `camera_android_camerax` 0.6.30 the wrapper
  `CameraInfo`/`LiveData` Pigeon factories are registered by `setUpGenerics()`
  inside `availableCameras()`. `CameraController.initialize()` casts the
  `CameraInfo` returned by `Camera.getCameraInfo()` to the wrapper type, so
  without that priming call the generated Pigeon class cannot be cast.
- **Fix:** in `_startLiveWithCamera()` on Android, call `availableCameras()`
  before constructing/initializing `CameraController`. The returned list is
  ignored: the user-visible picker still comes from the native CameraX
  selector. The call registers the wrapper factories and also warms the
  plugin's exact-camera map with the same native camera ids used by the
  selector.
- **Files:** `lib/screens/pose_tracking_screen.dart`, `PROJECT_STATE.md`.
- **Validation:** `dart format lib test` clean,
  `flutter analyze lib test android` **No issues found**, `flutter test`
  **114/114 passed**, `flutter build apk --debug` succeeded. The rebuilt
  `build/app/outputs/flutter-apk/app-debug.apk` is 329,847,206 bytes (13:55
  local); `aapt2 dump xmltree` confirmed no `screenOrientation` or
  `resizeableActivity` entry, and the MediaPipe model/JNI libraries are still
  packaged.
- **Status:** Superseded by the revert to the 24 Nov release build below.

### 2026-11-26 — Revert live squat tracking to the 24 Nov release build
- **What:** Removed every post-`v1.2.0` live-squat-tracking change and restored
  the live-tracking code to tag **v1.2.0** (24 Nov release). Deleted the
  MediaPipe bridge/model, native CameraX selector, orientation channels,
  `PoseFrame` web/skeleton changes, and their extra tests.
- **Why:** The user asked to remove all live-squat-tracking changes and restore
  the camera-related properties to the 24 Nov release build.
- **Restored from `v1.2.0`:** `android/app/build.gradle.kts`,
  `android/app/proguard-rules.pro`,
  `android/app/src/main/kotlin/com/insectcs/workoutapp/MainActivity.kt`,
  `lib/screens/pose_tracking_screen.dart`,
  `lib/services/pose_analysis_service.dart`, `lib/web/web_pose_stub.dart`,
  `lib/web/web_pose_web.dart`, `lib/widgets/pose_skeleton_painter.dart`,
  `test/pose_frame_test.dart`.
- **Deleted (not in the release):** `android/app/src/main/assets/` (model),
  `NativeCameraSelector.kt`, `native_camera_selector*.dart`,
  `pose_mediapipe_service.dart`, `pose_video_frame*.dart`,
  `test/pose_mediapipe_test.dart`.
- **Camera properties now:** `availableCameras()` with the normal picker and
  manual switching, `ResolutionPreset.medium`, NV21 on Android, no audio,
  `FlashMode.off`, ML Kit detection, plain image stream and plain video
  recording; no Activity/capture orientation lock, no silent switching, no
  recording `onAvailable` workaround and no anti-phantom layer.
- **Files:** the restored/deleted files above and `PROJECT_STATE.md`.
- **Validation:** `git diff v1.2.0` over all live-tracking code files is empty
  (byte-for-byte release code); only `PROJECT_STATE.md` is modified in
  `git status`. `dart format lib test` reported only the pre-release-style
  `lib/web/web_pose_stub.dart`, which was restored byte-for-byte to `v1.2.0`
  afterward. `flutter analyze lib test android` **No issues found**,
  `flutter test` **97/97 passed** (the v1.2.0 baseline), and
  `flutter build apk --debug` succeeded. The rebuilt
  `build/app/outputs/flutter-apk/app-debug.apk` is 271,143,407 bytes (14:10
  local); `aapt2 dump xmltree` found no `screenOrientation` or
  `resizeableActivity`, and the APK contains no MediaPipe model or JNI library.
- **Status:** Superseded by the TFLite MoveNet change below.

### 2026-11-26 — Bring native Android live tracking to web-style MoveNet
- **What:** Added a bundled TensorFlow Lite MoveNet Lightning detector for
  native Android live squat tracking. It uses the same 17 COCO keypoints, crop
  centered single-pose preprocessing, 0.25 pose-score rejection, and front
  camera mirroring as the web TF.js MoveNet path.
- **Why:** The user asked for the native Android experience to match the web
  build, which uses MoveNet rather than ML Kit.
- **Files:** Added `lib/services/pose_movenet.dart`,
  `lib/services/pose_movenet_native.dart`, `lib/services/pose_movenet_stub.dart`,
  `assets/models/movenet_lightning.tflite`, `test/pose_movenet_test.dart`;
  updated `pubspec.yaml`, `pubspec.lock`, `android/gradle.properties`,
  `windows/flutter/generated_plugins.cmake`,
  `lib/services/pose_analysis_service.dart`,
  `lib/screens/pose_tracking_screen.dart`, and `PROJECT_STATE.md`.
- **Pipeline:** `PoseAnalysisService.detectFromCameraImage()` calls
  `PoseMoveNetService` on Android and returns immediately. There is no ML Kit
  fallback: a no-person frame or an engine error stays empty on Android. iOS
  and web are unchanged.
- **Runtime:** `tflite_flutter 0.12.1` with the XNNPACK delegate on Android.
  The model asset is 4,758,512 bytes and is declared in `pubspec.yaml`. Input is
  a `Uint8List` `[1,192,192,3]` tensor produced from packed NV21 through a
  rotation-aware bilinear crop sampler; output allocation follows the model's
  actual tensor shape, so both `[1,17,3]` and `[1,1,17,3]` are accepted.
- **Gradle note:** `android/gradle.properties` sets
  `kotlin.jvm.target.validation.mode=warning`. Newer Gradle hard-fails on
  `tflite_flutter`'s Java 11 / Kotlin JVM-target mismatch; this downgrades it to
  the documented warning without changing app or camera configuration.
- **Camera properties:** unchanged from the 24 Nov release: `availableCameras()`
  picker, manual switching, `ResolutionPreset.medium`, NV21 on Android, no
  audio, `FlashMode.off`, plain image stream and plain video recording, no
  Activity/capture orientation lock.
- **Validation:** `flutter analyze lib test android` reports no issues;
  `flutter test` passes **103/103** (six new MoveNet preprocessing tests);
  `flutter build apk --debug` succeeds. The debug APK is 271,316,294 bytes and
  contains `assets/models/movenet_lightning.tflite` plus TFLite JNI libraries for
  arm64-v8a, armeabi-v7a and x86_64. `aapt2 dump xmltree` finds no
  `screenOrientation` or `resizeableActivity`. No MediaPipe model or JNI library
  is bundled; the existing `mediapipe-internal.properties` from ML Kit is still
  present, exactly as in the 24 Nov release APK. `flutter build web` succeeds,
  and the web TF.js MoveNet path is unchanged (the new model asset is simply
  bundled but unused there).
- **Status:** Superseded by the depth-capture change below.

### 2026-11-26 — Capture relative 3D depth without slowing MoveNet
- **What:** Added a signed `z` value to live keypoints, last-pose snapshots and
  time-stamped replay frames. Android still runs TFLite MoveNet on every camera
  frame; a throttled ML Kit sample (4 Hz, one in flight) supplies experimental
  relative depth, which is cached and merged into the next MoveNet skeletons by
  landmark name. iOS live/video ML Kit paths now populate `z` directly, and web
  keeps `z == 0` because TF.js MoveNet is 2D-only.
- **Why:** The user reported that the now-smooth live squat stream captured no
  3D landmarks. ML Kit's z is in image-pixel units, normalized here by frame
  width (negative = toward the camera, clamped to -1..1); Google documents it
  as experimental and not a true calibrated 3D measurement.
- **Files:** Added `test/pose_depth_test.dart`; updated
  `lib/services/pose_analysis_service.dart`, `lib/models/pose_history_models.dart`,
  `lib/screens/pose_tracking_screen.dart`,
  `lib/screens/live_tracking_history_screen.dart`, `test/pose_replay_test.dart`,
  `test/local_persistence_test.dart`, and `PROJECT_STATE.md`.
- **Storage:** `PoseReplayFrame` now stores `[x, y, z, confidence]` per visualised
  landmark. Legacy three-value frames are still parsed and decoded with `z = 0`,
  so older history sessions keep loading.
- **Validation:** `flutter analyze lib test android` reports no issues;
  `flutter test` passes **106/106** (two new depth-helper tests plus updated
  replay/persistence coverage). `flutter build apk --debug` succeeds; the debug
  APK is 271,322,333 bytes and still contains the MoveNet model and TFLite JNI
  with no MediaPipe model/JNI and no `screenOrientation`/`resizeableActivity`.
  `flutter build web --no-wasm-dry-run` succeeds and the TF.js path is unchanged.
- **Status:** Superseded by the depth visualisation change below.

### 2026-11-26 — Visualize relative depth on live skeleton joints
- **What:** `PoseSkeletonPainter` now encodes each joint's `z` as colour and
  radius: blue/larger for landmarks closer to the camera, orange/smaller for
  landmarks farther away, and the original white/size-4 node when `z == 0`.
  The change applies to the live camera overlay, video tracking overlay, replay
  overlay and saved-session skeleton because depth rendering is enabled by
  default. The 2D connections and MoveNet stream are unchanged.
- **Why:** The depth value was stored but invisible, so live squat tracking
  still looked like a plain 2D skeleton. The user asked for 3D landmarks to be
  visible on the subject without sacrificing the now-smooth stream.
- **Files:** Added `test/pose_skeleton_depth_test.dart`; updated
  `lib/widgets/pose_skeleton_painter.dart` and `PROJECT_STATE.md`.
- **Validation:** `flutter analyze lib test android` reports no issues;
  `flutter test` passes **107/107** (one new depth-visualisation test).
  `flutter build apk --debug` succeeds (271,324,066 bytes) and
  `flutter build web --no-wasm-dry-run` succeeds. The TF.js path is unchanged.
- **Status:** Superseded by the skeleton visibility fix below.

### 2026-11-26 — Show low-confidence MoveNet joints in live overlay
- **What:** Lowered the live overlay's landmark threshold from 0.3 to 0.12.
  TFLite MoveNet often reports per-joint scores below ML Kit's likelihood, so a
  valid skeleton could be detected and counted while every joint was filtered
  out of the painter. Live camera/video overlays, replay overlay, and the saved
  session skeleton now use 0.12; replay frames also retain joints above 0.12.
- **Why:** The user reported that the Android debug APK tracked well but plotted
  no skeletal landmarks on the subject.
- **Files:** Updated `lib/widgets/pose_skeleton_painter.dart`,
  `lib/widgets/pose_replay_overlay.dart`, `lib/models/pose_history_models.dart`,
  `lib/screens/pose_tracking_screen.dart`,
  `lib/screens/live_tracking_history_screen.dart`, `test/pose_replay_test.dart`,
  and `PROJECT_STATE.md`.
- **Validation:** analyzer and tests passed at the time; final build validation
  is recorded by the following Android tracking fix.

### 2026-11-26 — Restore MoveNet tracking when no skeleton or reps appear
- **What:** Fixed three fallbacks that could leave the Android stream empty or
  blind: the TF.js crop clamp now uses the farthest frame edge instead of the
  nearest so off-centre hips no longer shrink the crop to the torso; MoveNet
  probes the other three frame rotations after repeated empty frames and locks
  in the working one (no Activity/capture orientation change and no camera
  switching); and knee/elbow angle, exercise classification and torso checks
  use the same 0.12 landmark threshold as the painter and replay overlay.
- **Why:** The user reported that the rebuilt Android debug APK plotted no
  skeletal landmarks and counted no reps. With a wrong image-analysis rotation
  or a crop collapsed around the hips, MoveNet returned a low pose score; with
  drawing lowered to 0.12 but counting still at 0.3/0.4, borderline joints
  could be visible yet never drive a rep.
- **Files:** Updated `lib/services/pose_movenet_native.dart`,
  `lib/screens/pose_tracking_screen.dart`, `test/pose_movenet_test.dart`, and
  `PROJECT_STATE.md`.
- **Validation:** `flutter analyze lib test android` clean; `flutter test`
  passes **110/110** (two new MoveNet preprocessing tests);
  `flutter build apk --debug` succeeds (`app-debug.apk`, 271,327,015 bytes) and
  `flutter build web --no-wasm-dry-run` succeeds. The rebuilt APK contains
  `assets/flutter_assets/assets/models/movenet_lightning.tflite` and TFLite JNI
  for arm64-v8a/armeabi-v7a/x86_64, has no MediaPipe model or JNI, and its
  manifest has no `screenOrientation`/`resizeableActivity` entries. Web TF.js
  MoveNet is unchanged.
- **Status:** Ready for on-device verification; still uncommitted.

### 2026-11-26 — Make silent MoveNet failures visible and protect the frame stream
- **What:** Restored the device-proven CameraX transport: Android live sessions
  start the recording with `onAvailable: _processLiveFrame`, so the image
  analysis use case is not unbound by a plain video recording. A 3-second
  watchdog drops video and restarts a plain frame stream if that callback stops
  delivering frames; it never switches cameras or changes orientation. If
  callback recording cannot start at all, the session keeps tracking and skips
  video rather than starting a plain recording that would unbind the stream.
  The badge now reads `N FRAMES · N LANDMARKS`, and a silent MoveNet rejection
  shows pose score, best joint score, count of joints above 0.20, selected
  rotation and camera frame format in the amber status line. Errors and
  reset/dispose paths clear the same diagnostics. Verified that `tflite_flutter`
  passes a `Uint8List`
  input straight to the uint8 tensor and decodes the nested float32 output into
  the exact allocated shape, so no dequantisation or output reshape is missing.
- **Why:** The user still reported “no skeleton appears in live squat tracking”
  with the badge showing `0 LANDMARKS` and the generic “No person detected”
  text. That single message hid two distinct causes: zero camera frames (the
  CameraX recording issue already diagnosed on this device before the
  `v1.2.0` revert) and a below-threshold pose score. Both now have an on-screen
  signature, so the next device report can distinguish them without logcat.
- **Files:** Updated `lib/screens/pose_tracking_screen.dart`,
  `lib/services/pose_analysis_service.dart`,
  `lib/services/pose_movenet_native.dart`,
  `lib/services/pose_movenet_stub.dart`, and `PROJECT_STATE.md`.
- **Validation:** `flutter analyze lib test android` clean; `flutter test`
  passes **110/110**; `flutter build apk --debug` succeeds (`app-debug.apk`,
  271,332,754 bytes) and `flutter build web --no-wasm-dry-run` succeeds. The APK
  contains `assets/flutter_assets/assets/models/movenet_lightning.tflite` and
  TFLite JNI for arm64-v8a/armeabi-v7a/x86_64, has no MediaPipe model or JNI,
  and its manifest has no `screenOrientation`/`resizeableActivity` entries. Web
  TF.js MoveNet is unchanged.
- **Status:** Needs on-device verification; still uncommitted.

### 2026-11-26 — Rotate the live camera stream 180° and stop phantom activity (superseded by the 270° entry below)
- **Requested by user:** "In pose tracking → live tracking → live squat
  tracking, rotate the live video stream to 180 degree. Avoid stale landmarks
  and random activity getting generated." Follow-up: "camera orientation also
  180 degree rotation" — the rotation must be on the camera capture, not just a
  painted overlay.
- **Camera rotation:** `_startLiveWithCamera()` now calls
  `CameraController.lockCaptureOrientation(DeviceOrientation.portraitDown)`
  on Android after initialization and before the frame stream/recording starts.
  CameraX applies this to preview, video and `ImageAnalysis` together, so the
  saved video and live preview are 180° while the Activity/app UI stays in its
  normal orientation. The lock is released through
  `unlockCaptureOrientation()` on stop, teardown and start errors because the
  plugin keeps the lock across controller instances. Camera switching awaits the
  old controller's release before locking the new one, so the shared CameraX
  lock cannot be cleared after the replacement camera starts. Lens enumeration,
  `availableCameras()` picker, manual switching, `ResolutionPreset.medium`, NV21,
  `enableAudio: false`, `FlashMode.off`, the recording `onAvailable` callback
  and the frame watchdog are unchanged.
- **Detector alignment:** the detector and its empty-frame rotation probe are
  deliberately unchanged — CameraX changes image-analysis rotation metadata but
  not the pixel buffer, so the existing probe still adapts to devices that
  deliver an already-rotated buffer. The new `PoseAnalysisService.rotate180()`
  helper flips keypoints only when drawing the live skeleton and recorded replay,
  leaving counters/classification in the detector's upright coordinates (a 180°
  turn does not change joint angles).
- **No stale landmarks / self-generated activity:** new
  `lib/services/live_pose_stability.dart` requires six consecutive fresh frames
  of the same body centre (≤0.12 normalized jump, ≤250 ms gap) before any
  counter, classifier or replay sample runs. Missed detections immediately clear
  `_liveKeypoints`, reset the gate and disarm squat/arm reps. Squat reps require
  a knee angle below 100° held 250 ms; arm reps require an elbow below 80° held
  250 ms. `_resetLiveTrackingState()` now clears landmarks and gate state too.
- **Replay:** `LiveTrackingSession.streamRotated180` persists the flag (legacy
  sessions default to false). The MP4 already carries 180° rotation metadata,
  which `video_player` applies itself, so no second `RotatedBox` is added; only
  `PoseReplayOverlay` gets `rotate180`, keeping recorded skeletons on the subject.
- **Files:** `lib/services/live_pose_stability.dart` (new),
  `test/live_pose_stability_test.dart` (new), `lib/screens/pose_tracking_screen.dart`,
  `lib/services/pose_analysis_service.dart`, `lib/models/pose_history_models.dart`,
  `lib/screens/live_tracking_history_screen.dart`, `lib/widgets/pose_replay_overlay.dart`.
- **Validation (2026-11-26):** `dart format lib test` clean,
  `flutter analyze lib test android` → **No issues found** (re-run after the
  final camera-switch teardown change), `flutter test` → **115/115 passed**
  (including the new 180° rotation, stability-gate, persistence and
  replay-overlay regressions), and `flutter build apk --debug` →
  `build\app\outputs\flutter-apk\app-debug.apk` built successfully. Gradle only
  emitted its existing JDK/native-access and KGP warnings.
- **Status:** Superseded by the 270° change below; the stability gate and
  phantom-activity fixes remain in effect.

### 2026-11-26 — Change the live camera rotation to 270° clockwise
- **Requested by user:** "in pose tracking in live tracking in live squad
  tracking rotate the live video stream to 270 degree, camera orentiation also
  270 degree. avoid stale landmarks and random activity getting generated."
  This supersedes the 180° iteration above; the freshness/continuity gate is kept.
- **Camera rotation:** `_startLiveWithCamera()` still calls
  `CameraController.lockCaptureOrientation(DeviceOrientation.landscapeLeft)` on
  Android so preview, image capture, image analysis and video are all locked to
  270° clockwise while the Activity/UI stays normal. This runs for every lens in
  `availableCameras()` — front, back and any extra lenses — both on initial
  selection and after `_switchCamera()` reopens the picker. The lock is released
  on stop, teardown and start errors, and camera switching waits for the old
  controller to release before locking the new one. Camera picker, manual
  switching, `ResolutionPreset.medium`, NV21, `enableAudio: false`,
  `FlashMode.off`, recording `onAvailable` and the frame watchdog are unchanged.
- **Preview box:** `_buildLiveTrackingPreview()` uses `CameraPreview` again so
  the plugin owns the texture rotation and aspect ratio; the custom
  `buildPreview()` + `RotatedBox()` + flipped-aspect code was removed because it
  stretched the stream. `_livePreviewAspectRatio()` mirrors `CameraPreview`'s
  rule (locked landscape uses `value.aspectRatio`, portrait uses its inverse) so
  the outer box matches the rotated texture exactly instead of letterboxing it.
- **Landmarks:** the detector returns upright keypoints, which are rotated into
  the preview's display space with `PoseAnalysisService.rotateStream(...)` at
  the same 270° as the texture. The skeleton is painted as `CameraPreview`'s
  child, so every fresh detection moves it with the human subject in real time
  while staying locked to the rotated video. Counters/classification keep
  detector coordinates because joint angles are rotation-invariant; the detector
  and its rotation probe are unchanged.
- **Persistence/replay:** `LiveTrackingSession.streamRotated180` became
  `streamRotationDegrees` (new sessions store 270; legacy `true` still maps to
  180). `PoseReplayOverlay` takes `rotationDegrees`. Replay videos continue to
  rely on `video_player`'s own MP4 rotation metadata; no second `RotatedBox` is
  added, so the skeleton is only rotated once.
- **Files:** `lib/screens/pose_tracking_screen.dart`,
  `lib/services/pose_analysis_service.dart`, `lib/models/pose_history_models.dart`,
  `lib/widgets/pose_replay_overlay.dart`,
  `lib/screens/live_tracking_history_screen.dart`,
  `test/live_pose_stability_test.dart`, `test/local_persistence_test.dart`,
  `test/pose_replay_test.dart`.
- **Validation (2026-11-26):** `dart format lib test` clean,
  `flutter analyze lib test android` → **No issues found**, `flutter test` →
  **118/118 passed** (including 180°/270° transforms, legacy migration,
  stability gate and replay overlay), and `flutter build apk --debug` rebuilt
  `build\app\outputs\flutter-apk\app-debug.apk` successfully.
- **Status:** Uncommitted; needs on-device verification that the live preview
  and saved video are 270° clockwise with the skeleton aligned, the app UI does
  not rotate, camera switching keeps the lock, and reps only change during
  sustained real movement.

### 2026-11-26 — Track the moving subject without stretching the live preview
- **Requested by user:** skeleton must move with the detected human subject in
  real time, and the live video must look like a normal Android camera stream
  instead of being visibly stretched.
- **Fix:** `_buildLiveTrackingPreview()` uses `CameraPreview` again (with the
  skeleton as its `child`) so the plugin owns the texture rotation and aspect
  ratio. The experimental `controller.buildPreview()` + `RotatedBox` + flipped
  outer aspect-ratio code was removed; it double-corrected the plugin's own
  rotation and stretched the stream. `_livePreviewAspectRatio()` follows the
  same locked-orientation rule as `CameraPreview`, so the box matches the video
  exactly.
- **Skeleton:** `_displayLiveKeypoints` rotates each fresh detection by
  `_liveStreamRotationDegrees` (270°: `x' = y`, `y' = 1 - x`) into the preview's
  display space. The overlay repaints on every new keypoint list, so it follows
  the subject continuously while staying locked to the rotated video.
- **Files:** `lib/screens/pose_tracking_screen.dart`, `PROJECT_STATE.md`.
- **Validation (2026-11-26):** `dart format lib test` clean,
  `flutter analyze lib test android` → **No issues found**, `flutter test` →
  **118/118 passed**, `flutter build apk --debug` succeeded.

### 2026-11-27 — Live Exercise Tracking, category-aware counting and skeleton lock
- **Requested by user:** "in pose tracking in live tracking change the name from
  \"live squat tracking\" to \"live exercise tracking\" in this live exercise
  tracking identify the exercise correctly whether its an upper body exercise or
  lower body exercise or core exercise and then accordingly update the exercise
  counter. skeleton markings are still unable to identify the human subject
  correctly in real time."
- **Rename:** the button, empty-state copy, `_startLiveSquatTracking()` →
  `_startLiveExerciseTracking()` and the widget test now say **LIVE EXERCISE
  TRACKING (PERSON IN FRONT OF CAMERA)**. The banner shows the detected family
  (`UPPER BODY`, `LOWER BODY`, `CORE`, or `ANALYSING`) above the movement name.
- **Classification/counters:** new `lib/services/live_exercise_classifier.dart`
  replaces the old screen-local classifier. It computes knee/elbow/hip angles in
  MoveNet's upright frame (rotation-invariant), picks one active movement from
  geometry — squat (lower), curl/push-up (upper), crunch/plank (core) — and only
  counts that movement. A 250 ms held-position gate plus a freshness/continuity
  gate prevent jitter, held poses and brief detection gaps from producing reps.
  A curl with slightly bent knees no longer increments the squat counter; a
  static straight-arm plank is core with no rep. The last identified exercise
  stays visible while the person rests so the counter does not vanish from the
  live UI or a saved session. `LiveTrackingSession` now saves
  `coreCount`; existing `squatCount`/`curlCount`/`pushupCount` and history JSON
  stay compatible.
- **Skeleton:** the overlay still rotates fresh keypoints by the capture lock
  (270°) with `PoseAnalysisService.rotateStream`. Reviewing `camera_preview.dart`
  and `camera_android_camerax.dart` showed the plugin first corrects its texture
  to the device's upright frame while MoveNet's rotation probe also produces an
  upright frame, so subtracting `camera.sensorOrientation` would double-correct
  front/back lenses. The single 270° lock rotation is used for every lens and is
  saved as `streamRotationDegrees` for replay.
- **Files:** `lib/screens/pose_tracking_screen.dart`,
  `lib/services/live_exercise_classifier.dart`,
  `lib/services/pose_analysis_service.dart`,
  `lib/models/pose_history_models.dart`, `test/widget_test.dart`,
  `test/live_exercise_classifier_test.dart`, `PROJECT_STATE.md`.
- **Validation (2026-11-27):** `dart format lib test` clean,
  `flutter analyze lib test android` → **No issues found**, `flutter test` →
  **126/126 passed** (including category routing, cross-counter isolation,
  plank/crunch detection, counter persistence and held-position gates).
- **Status:** Uncommitted. On-device verification is still required: preview and
  saved video must be 270° clockwise with the skeleton on the subject through
  movement and every lens switch, and the name/category/counter must only change
  during sustained real exercise.

### 2026-11-27 — Login/update fixes, palette relocation and Gemini presets
- **What:** Fixed the login "Check for updates" always offering `v1.2.0` by
  aligning `UpdateService.currentVersion` with `pubspec.yaml`. Added a **Resume
  saved session** button to the login gate that reopens the signed-out profile
  without deleting data or creating a new guest/new-user session. Removed the
  "Palette: …" label from Home, moved the Auto palette button to login, and made
  the sign-out icon and session cards use palette-derived colours instead of the
  fixed peach/red values. Removed the extra guest-card fill. Reworked the API key
  row so the key field flexes and the Validate button stays inside the dialog
  card. Replaced the 2.5/2.0 Gemini presets with 3.8 Flash and 3.5 Flash Lite
  (3.1 Flash Lite kept, Custom kept).
- **Why:** A stale build version made the app claim it was out of date; users
  also needed a way back into an existing session after signing out. Fixed
  colours ignored the active palette and cramped the key dialog.
- **Files:** `lib/services/update_service.dart`, `lib/state/session_state.dart`,
  `lib/screens/login_screen.dart`, `lib/screens/home_screen.dart`,
  `lib/services/api_key_service.dart`, `lib/widgets/api_key_dialog.dart`,
  `test/session_login_test.dart`, `test/update_service_test.dart`,
  `test/api_key_service_test.dart`, `test/theme_test.dart`.
- **Validation:** targeted `flutter analyze` clean; full `flutter analyze` clean;
  `flutter test` → **141/141 passed**.
- **Status:** Uncommitted. Existing saved keys keep their stored endpoint; only
  the preset list changed.

### 2026-11-27 — Diet nutrient graphs, date-range export, slot selection and workout overflow
- **What:** Saving an analysed food now opens a nutrient sheet with a bar chart
  for that food, the current week's aggregated nutrients and the top
  contributor foods. The diet summary gained a date-range selector (All time,
  custom range, last 7/30 days) that filters the daily breakdown, nutrient
  charts and CSV/PDF exports. Tapped time slots now switch to the palette
  primary colour, scale up, show a check icon and a "Selected HH:00" banner, and
  the editor moved directly below the grid. Fixed the 15 px right-edge overflow
  when viewing saved workouts by making the result header, routine title,
  section title, metric badges and bottom action buttons flexible/scale-down,
  and constraining the saved-card date row.
- **Why:** Users could see Gemini nutrients only as chips, could not choose how
  many days to export, could not tell which slot was open, and narrow phones
  overflowed the workout view.
- **Files:** `lib/services/nutrient_analysis.dart` (new),
  `lib/widgets/nutrient_chart.dart` (new), `lib/models/diet_models.dart`
  (reused), `lib/state/diet_state.dart`, `lib/screens/diet_screen.dart`,
  `lib/screens/workout_result_screen.dart`,
  `lib/screens/saved_workouts_screen.dart`, `test/nutrient_analysis_test.dart`
  (new), `test/workout_overflow_test.dart` (new), `test/diet_test.dart`.
- **Validation:** `flutter analyze` → **No issues found**; `flutter test` →
  **147/147 passed** (including nutrient parsing/normalisation, range filtering
  and 360 px overflow checks).
- **Status:** Committed and released as v1.3.0 (see release entry below).

### 2026-11-27 — Release v1.3.0: security review, signed APK and GitHub release
- **What:** Prepared all uncommitted 2026-11-25/26/27 work for release. Bumped
  the version from `1.2.0+3` to `1.3.0+4` in `pubspec.yaml` and aligned
  `UpdateService.currentVersion` to `1.3.0`. Ran a full secret scan of every
  modified and untracked file: no real credentials appear in the diff; the
  only API-key-like strings are obvious test/docs placeholders
  (`AIzaSyAbCdEfGh1234567890`, `SECRET_KEY_VALUE`), and the real Gemini key
  lives only in git-ignored `env.json`. Confirmed `.gitignore` excludes
  `env.json`, `android/key.properties`, signing keys, `.env*` and `*.secrets`.
  The git remote has no embedded credentials (HTTPS remote, credentials held
  by the Windows Credential Manager `manager` helper).
- **Validation:** `flutter pub get` succeeded; `flutter analyze lib test android`
  → **No issues found**; `flutter test` → **147/147 passed**;
  `flutter build apk --release` → signed release APK built.
- **Files:** version bump in `pubspec.yaml` and
  `lib/services/update_service.dart`; all prior uncommitted feature/fix files
  committed in this release.
- **Status:** Committed, tagged `v1.3.0`, pushed to `origin/main`, and published
  as a GitHub release with the signed `app-release.apk` plus SHA-256 checksum.

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
8. **`MediaStreamTrackProcessor` leaks VideoFrames** on camera stop in some
   Chromium builds; delete it from `window` before camera_web initialises so the
   plugin uses canvas capture instead.
9. **Gemini video uploads** (base64 whole file, no timeout) hang for minutes —
   never send videos; use local per-frame tracking for motion analysis.
10. **PowerShell + flutter CLI:** stderr on success trips PowerShell; buffer
    output to a file and grep it instead.
11. **Analyzer budget:** pre-existing `withOpacity` infos in other screens are
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
31. **ML Kit NV21 must be exact-size:** `InputImage.fromBytes` throws unless the
    buffer is exactly `width × height × 1.5`; CameraX can add Y-plane padding or
    hand back YUV_420_888 planes. Always repack streamed frames before passing
    them to ML Kit, and surface the native error in the UI — catching it and
    showing "no person detected" hides real device-specific failures.
32. **Android 16 exports must use MediaStore/SAF:** `getApplicationDocumentsDirectory()`
    is app-private and invisible to file managers; `WRITE_EXTERNAL_STORAGE` is
    useless for targetSdk 36. Writing app-created files through
    `MediaStore.Downloads` needs no storage permission and makes CSV/PDF
    exports visible in the device Downloads folder.
33. **Never put a YouTube ID in a URI host:** Dart lowercases `Uri.host`, and
    YouTube IDs are case-sensitive. `vnd.youtube://8iPEnn-ltC8` launches
    `8ipenn-ltc8` and shows “Video unavailable”. Keep the ID in the query string
    of a canonical `https://www.youtube.com/watch?v=<id>` URL (or use the opaque
    `vnd.youtube:<id>` form) to preserve case.
34. **Return buttons should use the result's own type:** generated results are
    in-screen overlays, not routes. When adding a “Go to previous screen” CTA,
    clear the persisted result first, then animate the existing `TabController`
    to the form matching the result (`plan.scope`, weekly vs BMI), not the
    currently selected tab. Otherwise a result reopened from History sends the
    user back to History because its controller index is 2.
35. **Replay landmarks need their own clock:** saved video and pose samples are
    captured by different async subsystems. Time each compact skeleton from
    `startVideoRecording()` completion, sample at ~5 fps with a hard cap, and
    select the nearest sample from `VideoPlayerController.position`. Do not
    store every ML Kit frame — it would bloat the single encrypted Hive JSON
    value and slow every history read.
36. **Padded NV21 cannot be fixed by truncation:** if `bytesPerRow > width`,
    the first `width × height × 1.5` bytes contain row padding and lose the
    bottom of the image. Rebuild the buffer row-by-row using the Y stride and
    the chroma stride; only trim when the buffer is already tightly packed.
37. **MediaPipe IMAGE-mode visibility is not a reliable draw gate:** the task
    bundle can emit 0 or very low visibility for visible landmarks. Treat
    `<= 0.2` as unknown instead of discarding points, or the detector can find
    a person while the painter draws nothing and History says “no tracking”.
38. **CameraX recording can silently stop image streaming:** on hardware below
    `LEVEL_3`, `startVideoRecording()` without an `onAvailable` callback unbinds
    `imageAnalysis` while leaving the preview alive. Use
    `startVideoRecording(onAvailable: callback)` for simultaneous recording and
    detection, and keep a frame-count watchdog to fall back to
    `startImageStream()` with no video when the device refuses.
39. **Check MediaPipe's Java signatures against the cached AAR:** 1.2.2 returns
    `Optional<Float>` for landmark visibility/presence. A cast to `Number`
    compiles only because Kotlin erases the generic, then throws on Android.
    Use `javap` on the Gradle-cached `tasks-core` / `tasks-vision` classes when
    upgrading the dependency.
40. **IMAGE mode re-detects a stranger every frame:** use `RunningMode.VIDEO`
    with strictly increasing timestamps for camera streams so MediaPipe can
    track one person temporally; reset the timestamp when the landmarker is
    recreated.
41. **A held skeleton must not become an athlete:** reusing the last pose after
    a missed frame prevents overlay flicker, but mark it stale and skip all
    counters/classifiers/replay sampling until a fresh detection arrives.
42. **Prefer the front camera for person-facing tracking:** defaulting to the
    first camera can pick a rear lens and force the user to re-aim the phone;
    keep a switch button so the choice is still explicit.
43. **Automatic camera failover must await release:** opening the next
    `CameraController` while the old recording/stream is still disposing makes
    cameras report as busy. Stop recording, stop analysis, dispose, then open
    the next lens.
44. **Separate draw confidence from counting reliability:** promoting 0/low
    MediaPipe visibility makes landmarks visible, but that same promoted value
    must not be used to count reps. Keep the raw visibility as `reliability`,
    use metric world angles, and require several consecutive same-subject
    frames with a held movement before any activity is recorded.
45. **Do not let the detector silently pick the camera:** the released
    2026-11-24 camera path (enumerate every lens, user picker, medium/NV21
    controller) was verified by the user; automatic lens failover to "find a
    pose" added framing friction. Layer MediaPipe on the verified stream
    instead, and never switch lenses or change camera properties to chase a
    pose.
46. **CameraX unbinds `ImageAnalysis` for a plain recording:** in
    `camera_android_camerax-0.6.30`, `startVideoRecording()` ->
    `startVideoCapturing()` calls `_unbindUseCaseFromLifecycle(imageAnalysis!)`
    whenever no frame callback is supplied (all hardware levels except LEVEL_3
    with a callback). The preview/video still looks smooth, so it looks like a
    detector bug, but MediaPipe receives zero frames. Start Android recording
    with `onAvailable: _processLiveFrame`; the plugin then rebinds analysis via
    `onStreamedFrameAvailable()`. Keep a plain image stream as fallback and
    stop the recording stream before disposing the controller.
47. **Never hard-code the inverse camera aspect ratio for the preview:** the
    camera reports a landscape sensor ratio (`width / height`). `CameraPreview`
    uses that ratio directly in landscape and its inverse only in portrait,
    while also rotating the Android texture. Wrapping it in a permanently
    inverted `AspectRatio` squeezes/letterboxes the native frame and pushes the
    landmark overlay off the subject. Mirror the plugin's orientation rules
    (`recordingOrientation` while recording, otherwise preview/locked/device
    orientation) and rebuild the box via `ValueListenableBuilder<CameraValue>`.
48. **Matching the frame is not the same as choosing its orientation:** after
    fixing the overlay box, a landscape-held device still produced landscape
    video because the Activity and `CameraController` capture orientation were
    unlocked. For a portrait-default stream, request portrait orientation for
    the live screen and call `lockCaptureOrientation(DeviceOrientation.portraitUp)`
    before starting the frame stream/recording; pass rotation 0 to the detector
    when that lock succeeds.
49. **Dart orientation locks can lose to native CameraX state:** on the Android
    16 test device, `SystemChrome.setPreferredOrientations()` plus
    `lockCaptureOrientation()` still produced a landscape stream. Lock the
    Activity natively in `AndroidManifest.xml`
    (`android:screenOrientation="portrait"`, `android:resizeableActivity="false"`)
    and in `MainActivity.onCreate()` before Flutter initializes the camera.
    Once the Activity is portrait, treat Android camera frames as portrait when
    rotating landmarks instead of trusting `Display.getRotation()`.
50. **Never rotate the Activity for the live stream:** the user rejected both
    APK-wide and live-session Activity locks. Keep the manifest/orientation
    unspecified, use only
    `CameraController.lockCaptureOrientation(DeviceOrientation.landscapeLeft)`,
    and rotate Android landmarks as `Surface.ROTATION_90`. CameraX rotates the
    preview/video buffers inside the unchanged app UI.
51. **Use the native CameraX selector for live lenses:** enumerate with
    `ProcessCameraProvider.availableCameraInfos` and Camera2 characteristics on
    Android, then map the chosen camera id back to a `CameraDescription` for the
    verified camera plugin. This preserves the native multi-lens picker without
    replacing the working preview/frame transport.
52. **Prime `camera_android_camerax` when bypassing `availableCameras()`:** its
    `CameraInfo`/`LiveData` Pigeon wrapper factories are registered only inside
    `availableCameras()`. If a native selector supplies the camera list, still
    call `availableCameras()` once before `CameraController.initialize()`,
    otherwise the plugin casts generated `camerax_library.g.dart.CameraInfo` to
    `camerax_library.dart.CameraInfo` and live startup fails.
53. **Mirror TF.js crop math exactly:** `determineNextCropRegion` clamps the
    half-size with `max(edge distances)`, not `min`. Using the nearest edge
    collapses an off-centre person into a tiny crop and MoveNet returns no pose.
    Probe the frame rotation when this happens; CameraX can deliver an
    already-rotated buffer while `CameraDescription.sensorOrientation` still
    reports the physical sensor angle. Keep the probe inside the detector so the
    verified camera picker and orientation stay untouched.
 54. **Rotate the camera, not the Activity, for a rotated live stream:** use
    `CameraController.lockCaptureOrientation(...)` — `portraitDown` for 180° or
    `landscapeLeft` for 270° clockwise — before starting frames so preview,
    video and analysis all rotate while the app UI stays put, and unlock
    explicitly on teardown because CameraX keeps the lock across controller
    instances. Leave the detector rotation probe alone: CameraX changes
    ImageAnalysis rotation metadata, not the pixel buffer, so the existing probe
    still handles devices that deliver rotated buffers. Rotate only the drawn
    skeleton/replay with `rotateStream(keypoints, degrees)`; counters keep using
    detector coordinates because joint angles are invariant under rotation.
    Mirror `CameraPreview`'s landscape/portrait aspect-ratio rule in the outer
    preview box or the rotated texture gets letterboxed.
 55. **A drawn skeleton is not a fresh skeleton:** clear landmarks when a frame
     returns no pose, and require several consecutive same-subject frames before
     feeding counters/classifiers. Otherwise a held or jumping skeleton becomes
     "random activity" with no athlete moving.
 56. **Do not subtract `camera.sensorOrientation` from the overlay rotation:**
     `camera_android_camerax` corrects its texture to the upright device frame and
     MoveNet's rotation probe independently outputs upright keypoints. The only
     remaining transform is `CameraPreview`'s locked rotation (270° for
     `landscapeLeft`). Subtracting the sensor angle makes front cameras skip the
     overlay turn and back cameras stop 90° early.

---

## 7. Next Steps / Backlog

- [ ] User verification: pose-tracking dynamic counter + elbow angle + continuous
      identification (video & live camera)
- [ ] User verification: logger set splits (weight/reps/time), graph
      visualizations (Bars/Line/Area/Pie), and timeframe-scoped CSV/PDF export
- [x] Web live camera: `camera` plugin handles getUserMedia/permission +
      enumerateDevices; user picks a detected camera and MoveNet runs on the
      streamed frames (ML Kit remains the native engine)
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
- [x] Commit/push v1.1.0, tag `v1.1.0`, and publish the GitHub release with the
      signed APK plus checksum (done 2026-11-23; see §5 release entry).
- [x] Commit/push the 2026-11-24 fixes, tag **v1.2.0**, and publish the signed
      APK plus checksum (done 2026-11-24; see §5 release entry).
- [ ] **Immediate:** verify the 270° live-camera change on the Android 16
      device: open live exercise tracking, confirm the whole app UI stays in its
      normal orientation while the camera preview/video is rotated 270° clockwise,
      switch through **every available lens** (front, back and any extra cameras)
      and confirm the lock and skeleton alignment survive each switch, check the
      skeleton stays on the subject in both live preview and replay, and confirm
      the exercise category, name and counter only change after sustained real
      movement (no activity when the person is still or briefly missing).
- [ ] **Immediate:** install the freshly rebuilt 2026-11-26 debug APK (not the
      GitHub v1.2.0 release) on the Android device. Confirm the whole app stays
      in its normal orientation, then start live tracking and choose any camera
      from the `availableCameras()` picker. Confirm the badge reports a rising
      frame count, the MoveNet skeleton and depth-coloured joints appear on the
      subject, the exercise name/counter and knee/elbow angles update during
      real squats, there are no silent lens switches, and the replay video shows
      the recorded skeleton. If the skeleton is still missing, share the exact
      badge and amber status text: `0 FRAMES` means the camera transport stalled;
      `N FRAMES` plus `MoveNet: pose …` means inference ran and the pose score
      was below 0.25. USB `logcat` is only needed if neither line appears; the
      v1.2.0 release APK cannot contain the TFLite MoveNet/depth layer.
- [ ] User verification on the Android 16 device: landmarks, exercise ID,
      knee/elbow angles and rep counts update live; diet slots show green/red
      correctly; Rest goals save; food units appear; CSV/PDF exports are
      visible in Downloads from a file manager; Calories/BMI results save to
      and reopen from the new History tab; YouTube demos open with the correct
      mixed-case video ID; **Go to previous screen** returns every generated
      result to the right edit form; and saved live-session videos replay their
      recorded landmarks. If the on-screen detection badge still shows an
      error, use that text to diagnose the remaining device-specific issue.
- [ ] Copy the keystore backup ZIP from `<backup-location>` to durable, offline
      storage (password manager or external drive).
- [ ] Revisit build workarounds (`kotlin.incremental=false`, explicit
      concurrent-futures dependency, R8 keeps) when Flutter/AGP versions move on.
