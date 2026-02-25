# Renthus Service - Agent Instructions

## Overview
Renthus is a local services marketplace (like GetNinjas/TaskRabbit) built with Flutter + Supabase. It connects clients who need services with service providers. See `README.md` and `docs/project-context.md` for full context.

## Cursor Cloud specific instructions

### Flutter SDK
- Flutter is installed at `/opt/flutter` (added to `PATH` via `~/.bashrc`).
- The project requires Flutter 3.38.x (specifically uses Dart SDK `>=3.3.0 <4.0.0` and `intl ^0.20.2` which requires Flutter 3.38+).
- Android SDK is at `/opt/android-sdk` with `ANDROID_HOME` and `ANDROID_SDK_ROOT` set in `~/.bashrc`.

### Environment File
- A `.env` file is required at the project root (listed in `pubspec.yaml` assets). It must contain `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- If `SUPABASE_URL` and `SUPABASE_ANON_KEY` environment variables are set (via Cursor secrets), generate the file:
  ```
  printf "SUPABASE_URL=%s\nSUPABASE_ANON_KEY=%s\nENVIRONMENT=development\nDEBUG_MODE=true\n" "$SUPABASE_URL" "$SUPABASE_ANON_KEY" > .env
  ```
- Fallback: restore from git history `git show ba0d6d0^:.env > .env`, or create from `.env.example`.
- `lib/firebase_options.dart` and `android/app/google-services.json` were also removed for security. Restore from git history if needed for builds: `git checkout ba0d6d0^ -- lib/firebase_options.dart android/app/google-services.json`.

### Key Commands
- **Install deps**: `flutter pub get`
- **Code generation**: `dart run build_runner build --delete-conflicting-outputs`
- **Lint**: `flutter analyze` (expects warnings/info only, no errors)
- **Test**: `flutter test` (pre-existing compatibility issue with `flutter_test_config.dart` and `Supabase.initialize()` outside test zone)
- **Build web**: `flutter build web` (requires patching `image_cropper_for_web` in pub cache — see below)
- **Run web**: Build, then `cd build/web && python3 -m http.server 8080`

### Known Issues
- **Web build**: `image_cropper_for_web 3.0.0` uses `dart:ui` `platformViewRegistry` which moved to `dart:ui_web` in Flutter 3.38+. The pub-cache file must be patched: replace `import 'dart:ui' as ui;` with adding `import 'dart:ui_web' as ui_web;` and change `ui.platformViewRegistry` to `ui_web.platformViewRegistry`. Also fix `UnmodifiableUint8ListView` in `image_cropper_platform_interface` by replacing with `Uint8List.fromList(...)`.
- **Android build**: `file_picker 6.2.1` uses removed v1 Android embedding (`PluginRegistry.Registrar`). Requires upgrading `file_picker` to a version compatible with Flutter 3.38+.
- **Tests**: `flutter_test_config.dart` calls `Supabase.initialize()` outside the test zone, causing `printOnFailure` errors on newer SDKs.
- These are pre-existing issues in the codebase, not environment problems.

### Project Structure
See `.cursorrules` for the migration guide and feature-based structure. The codebase is migrating from StatefulWidget to Riverpod 3.0 + ConsumerWidget.
