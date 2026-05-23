# Sacred KG Flutter MVP

Sacred KG is a mock-data Flutter mobile prototype for exploring sacred places, petroglyphs, springs, and cultural routes in Kyrgyzstan. It is built for demo and hackathon use: there is no backend, no real authentication provider, no real booking system, and no real AI API yet.

The app currently includes:

- Mock login, register, guest mode, logout, and local session persistence.
- Home dashboard with Kyrgyz cultural UI motifs.
- Region selector for the seven regions of Kyrgyzstan.
- Sacred places catalog with search, filters, and sorting.
- Place detail screens with cultural notes, route guidance, reviews, favorites, and CTAs.
- Mock AI guide with Atashka and Apashka character modes.
- Community feed prototype and local post creation.
- Visit request / booking prototype with local booking history.
- Settings for theme, language, and music toggle.
- Account page with favorites, bookings, shortcuts, logout, and mock delete account.

## Tech Stack

- Flutter
- Dart
- Riverpod
- go_router
- shared_preferences
- intl
- flutter_animate

The app uses Flutter-native custom painters for the Kyrgyz-inspired visual motifs. No external image assets or backend services are required.

## Requirements

Install these on the new computer before running the project:

- Flutter SDK with Dart 3.9 compatible tooling.
- Android Studio or Android SDK command-line tools.
- Android emulator or physical Android device.
- Git.

Recommended check:

```bash
flutter doctor
```

Fix any missing Android licenses or SDK setup issues shown by Flutter:

```bash
flutter doctor --android-licenses
```

## Get Started On Another Computer

1. Clone or copy the project.

```bash
git clone <repo-url>
cd hack2026
```

If you are copying the folder manually, copy the project source files but do not rely on the old `build/` output. The build folder is generated locally.

2. Install Flutter dependencies.

```bash
flutter pub get
```

3. Check available devices.

```bash
flutter devices
```

4. If no Android emulator is running, list available emulators.

```bash
flutter emulators
```

5. Start an emulator.

```bash
flutter emulators --launch <emulator-id>
```

Example:

```bash
flutter emulators --launch Medium_Phone
```

6. Run the app on Android.

```bash
flutter run -d <device-id>
```

Example:

```bash
flutter run -d emulator-5554
```

For a one-shot build/install that exits the terminal after launch:

```bash
flutter run -d emulator-5554 --no-resident
```

## Run On Web

Web is useful for quick UI checks:

```bash
flutter run -d chrome
```

Or run a local web server:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 52026
```

Then open:

```text
http://127.0.0.1:52026
```

## Build Commands

Analyze the code:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Build Android debug APK:

```bash
flutter build apk --debug
```

Build Android release APK:

```bash
flutter build apk --release
```

Build web:

```bash
flutter build web
```

## Project Structure

This MVP currently keeps most prototype code in:

```text
lib/main.dart
```

Important generated/platform folders:

```text
android/    Android project files
ios/        iOS project files
web/        Web runner files
test/       Flutter widget tests
```

Planning document:

```text
plan.md
```

Dependency files:

```text
pubspec.yaml
pubspec.lock
```

## Mock Data And Local State

The app uses local mock models and lists for:

- Regions
- Places
- Reviews
- Feed posts
- Bookings
- AI characters
- AI mock responses

Some state is stored with `shared_preferences`, including:

- Login/session flag
- User name and email
- Favorites
- Theme mode
- Language
- Music toggle

If you want to reset local app state on an emulator, either clear app storage from Android settings or uninstall the app:

```bash
flutter clean
```

Then run again:

```bash
flutter pub get
flutter run -d emulator-5554
```

## Current Limitations

- No real backend.
- No real authentication provider.
- No real AI API.
- No real booking integration.
- No maps SDK.
- No real 3D model loading yet. The current 3D-like visuals are Flutter custom painter animations.

## Next Development Steps

Suggested next steps:

- Split `lib/main.dart` into feature-first folders.
- Move mock data into repository files.
- Add real localization files for EN/RU/KG.
- Add actual `.glb` or `.gltf` 3D models if model loading is required.
- Replace mock repositories with API-backed repositories.
- Add more widget tests for navigation, filters, favorites, bookings, and AI responses.
