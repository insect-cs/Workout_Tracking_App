# workout_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Configuration

The Gemini API key is **not** stored in this repository. Copy the template and
keep your real values local:

```bash
cp env.example.json env.json
# edit env.json and replace YOUR_GEMINI_API_KEY
```

Then pass the file when running or building:

```bash
flutter run --dart-define-from-file=env.json
flutter build web --release --dart-define-from-file=env.json
```

`env.json` (and other `.env`/secret files) is ignored by Git. Never commit real
API keys or credentials. Restrict the key in Google AI Studio to the APIs this
app uses.

