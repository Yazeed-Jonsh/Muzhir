# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

Muzhir is a Flutter mobile app for AI-powered plant disease detection, targeting Saudi Arabia. Currently only the Flutter frontend exists (in `mobile_app/`). The planned FastAPI backend and YOLOv8 AI model are not yet implemented.

### Running the app

- **Lint**: `flutter analyze` (from `mobile_app/`)
- **Test**: `flutter test` (from `mobile_app/`). Note: the default `test/widget_test.dart` is stale and references `MyApp` instead of `MuzhirApp`; it will fail to compile.
- **Build web**: `flutter build web` (from `mobile_app/`)
- **Run web dev server**: `flutter run -d chrome --web-port=8080` (from `mobile_app/`)
- **Serve production build**: `python3 -m http.server 8080` (from `mobile_app/build/web/`)

### Key gotchas

- `firebase_options.dart` is gitignored and must be created before the app can compile. A stub with dummy Firebase config values is sufficient for development/testing (Firebase Web SDK does not validate API keys at init time). Place it at `mobile_app/lib/firebase_options.dart`.
- `assets/icons/` directory is declared in `pubspec.yaml` but may not exist in the repo. Create it (with a `.gitkeep`) before running `flutter pub get`.
- The web platform must be scaffolded with `flutter create --platforms=web .` from inside `mobile_app/` if the `web/` directory doesn't exist yet.
- Flutter SDK 3.27+ is required (ships with Dart 3.6). Install to `/opt/flutter` and add `/opt/flutter/bin` to `PATH` via `~/.bashrc`.
- No Android SDK or emulator is available in the cloud VM; use Chrome (web) for testing.
