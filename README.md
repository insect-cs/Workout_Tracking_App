# Workout Tracking

A Flutter app for planning workouts, tracking exercises with on-device pose detection, and logging diet and calories. All everyday app data stays on the device; AI features use a key that **you** provide at runtime.

## Features

- **Plan** — generate weekly or single-day workout plans with AI, browse exercise demo videos, and save results to a per-session History tab.
- **Calories** — estimate BMR/TDEE (Mifflin–St Jeor) and BMI locally, then generate an AI narrative from those numbers.
- **Diet** — daily and weekly calorie/water goals with day status highlighting, 24 hourly slots, food entries with optional AI validation, water logging, Rest/sleep tracking, and a summary with CSV/PDF export.
- **Exercise logger** — saved workouts, current workout, and per-set logging.
- **Pose tracking** — on-device landmark tracking, rep counting, angles, and exercise identification. Uses TensorFlow.js MoveNet on web and Google ML Kit on Android/iOS. Live sessions record the camera stream; use **Save live tracking** to keep tracked sessions locally, then view metrics and replay the video in the **History** tab inside this screen. Stopping a session with no detected pose saves a video-only entry that says no live tracking happened.
- **Sessions** — start as a guest, or choose **Continue as new user** to enter your name on a welcome page (“Welcome, &lt;name&gt;” updates as you type) and continue. The name appears in the Home greeting and stays with the device-local profile across restarts.
- **Themes** — Material 3 light/dark mode plus six seeded color schemes, with animated navigation.
- **Updates** — **Check for updates** on the login screen queries GitHub Releases, shows the latest version and notes, and offers the APK download when a newer release exists.

## Install the APK

Download `app-release.apk` from the [Releases](https://github.com/insect-cs/Workout_Tracking_App/releases) page and install it on an Android 7.0 (API 24) or newer device. Android will ask you to allow installation from unknown sources for the app/file manager you use.

## AI keys (bring your own)

No API key is bundled in the app or stored in this repository. To use AI features:

1. Open the **Keys** page from Home, or tap any AI action for the first time.
2. Paste a Gemini-compatible key, choose a preset endpoint/model (or enter a custom base URL and model), and tap **Validate**.
3. The key is stored on-device in secure storage only after a successful test request.

Keys are displayed masked with no reveal option. You can switch endpoints, replace keys, or delete them; deleting the active key signs you out of AI features until a new one is validated. Restrict your key in Google AI Studio to only the APIs this app uses, and never commit it to a repository.

`env.json` / `env.example.json` remain in the repo as legacy local-run helpers, but are **not required** — the app no longer reads keys at build time.

## Privacy and data

- Ordinary app state is saved on-device in an encrypted Hive box. Its AES key is generated on first run and kept in secure storage.
- There is no account, backend, or server-side sync.
- Pose detection and video analysis run on-device; videos are never uploaded to Gemini.
- Network access is used only for: AI requests you initiate, YouTube thumbnails/video search, and links you open in a browser.
- Fonts, the pose model, and the TensorFlow.js runtime are bundled, so no font CDN requests are made.

## Build from source

Requires Flutter 3.47.9 / Dart 3.13.7 (see `pubspec.yaml`) and an Android SDK.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The output is `build/app/outputs/flutter-apk/app-release.apk`.

Notes for this repository's build setup:

- Release signing is configured in `android/app/build.gradle.kts` and reads credentials from `android/key.properties` (git-ignored). A fresh clone builds unsigned until you supply your own keystore.
- `kotlin.incremental=false` is set in `android/gradle.properties` to avoid a Kotlin cache bug when the project and pub cache are on different drives.
- `android/build.gradle.kts` explicitly adds `androidx.concurrent:concurrent-futures` to work around a CameraX 1.5 / Gradle 9 compile-classpath issue.
- On Windows, building with the `windows/` folder present requires symlink support (Developer Mode) or Flutter's Windows desktop feature temporarily disabled.

## Licensing

This project is licensed under the [MIT License](LICENSE). Third-party
components bundled with the app are listed in [NOTICE](NOTICE). The app bundles
no third-party photo or video assets; the sample media previously included in
the repository was unreferenced and had unverifiable redistribution terms, so
it was removed.
