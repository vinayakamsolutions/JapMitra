# JapMitra

**JapMitra** — आपका दैनिक आध्यात्मिक साथी / Your Daily Spiritual Companion  
Made by Vinayakam Solutions

A Flutter Android-first V1 MVP for Naam Jap, Digital Mala, Panchang, Rashifal, Numerology, reminders, and Hindi/English localization.

## Features
- Splash, onboarding, city setup, and bottom navigation
- Hindi default language with English switch in Settings
- Reliable offline Jap counter with 108-jap mala progress
- Built-in mantra catalog plus custom mantra create/edit/delete/select
- Daily goal options and basic history totals
- Panchang monthly calendar and daily detail using clearly marked sample/development data
- 12-rashi Rashifal UI using clearly marked sample content
- Basic numerology: birth number and life path number
- Local reminder preference UI and notification service abstraction
- Material 3 warm saffron/cream visual design

## Tech stack
- Flutter + Dart
- Material 3
- `sqflite` for Jap/custom mantra/history persistence
- `shared_preferences` for lightweight settings
- `flutter_local_notifications` for local reminders
- `vibration` for optional haptic feedback

## Folder structure
```text
lib/
  core/ constants, localization, services, theme, utils
  data/ local database, models, repositories
  features/ home, jap, panchang, rashifal, numerology, onboarding, settings
  shared/widgets
  main.dart
assets/data/ sample Panchang/Rashifal JSON
assets/icons/ original SVG placeholder icon
android/ Android build configuration
```

## Setup
```bash
flutter pub get
flutter run
```

## Build APK
```bash
flutter build apk --release
```
No signing keys or passwords are included. Add Play Store signing outside source control.

## Tests
```bash
flutter test
flutter analyze
```

## Change application name
Android label is in `android/app/src/main/AndroidManifest.xml`. Flutter title is in `lib/main.dart`.

## Localization
Strings are centralized in `lib/core/localization/app_localizations.dart`. Hindi is the default. Add a new language by adding a map and locale code.

## Local database
SQLite is managed by `lib/data/local/app_database.dart`. Repositories isolate data access from UI.

## Panchang data
Stored in `assets/data/panchang_sample.json` and loaded by `PanchangRepository`. It is marked sample/development data and must be replaced with verified location/date-specific production data before release.

## Rashifal data
Stored in `assets/data/rashifal_sample.json`. It is sample content, not verified astrological guidance. A remote repository can replace it later without changing UI.

## Numerology logic
Located in `lib/features/numerology/numerology_service.dart`.

## Future extension notes
The app is feature-based and repository-driven so Sankalp, streaks, achievements, group Jap, AI assistant, audio, premium, and cloud sync can be added later without rewriting core screens. These are intentionally not implemented in V1.

## Known limitations
- Flutter SDK was not available in the generation environment, so APK build and Flutter analyzer/test execution could not be run here.
- Panchang and Rashifal use clearly labeled sample/development data.
- Launcher icon is an original placeholder SVG; use `flutter_launcher_icons` or Android asset generation later for production densities.


## Corrected build notes
See `CHANGELOG.md` for Flutter 3.47.4 compatibility, Android V2 embedding, reliable Jap persistence, reminders, and data-honesty fixes.
