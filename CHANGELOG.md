# JapMitra Corrected Changelog

## Android V1 → V2 migration
- Added required `flutterEmbedding` v2 metadata in AndroidManifest.
- Kept `MainActivity` on current `io.flutter.embedding.android.FlutterActivity`.
- Removed assumptions that would require manual plugin registration.
- Preserved package `com.vinayakamsolutions.japmitra`.

## Flutter 3.47.4 compatibility
- Replaced `CardTheme` with `CardThemeData` while preserving saffron, cream, brown, gold, rounded-card Material 3 styling.

## Jap counter reliability
- Removed the tap-losing `saving` guard.
- Added immediate in-memory increment and a persistence queue that batches pending taps without blocking later taps.
- Rapid taps are counted in UI immediately and flushed to SQLite exactly once per queued batch.

## Reset persistence
- Reset today now deletes only today's events for the selected mantra from SQLite.
- Previous days and other mantras remain untouched.
- Confirmation copy now accurately explains the destructive action.

## Mantra-wise counting
- Counts are now queried by selected mantra and date window.
- Changing mantra no longer shows another mantra's count.
- Repository supports mantra-specific lifetime and daily queries.

## Panchang handling
- Removed misleading fabricated values and the fake every-11th-day Ekadashi marker.
- Added a Panchang model/repository boundary that supports all required Panchang fields.
- UI clearly states verified Panchang data is unavailable until a legitimate data/calculation source is added.

## Rashifal data architecture
- Added a Rashifal model/repository boundary with required content categories.
- Removed hardcoded “Sample guidance” as if it were a real reading.
- UI clearly marks unavailable/development content.

## Numerology improvements
- Added DOB validation.
- Added extensible `NumerologyInsight` model for today number, lucky number, colour, and guidance.
- Kept deterministic birth number and life path calculations.

## Notifications/reminders
- Added `NotificationService` using local notifications and timezone scheduling.
- Settings can enable/disable daily Jap reminder and choose reminder time.
- Preferences persist locally and scheduling is local/offline.

## Launcher icon
- Added adaptive launcher icon XML resources using an original JapMitra placeholder mark.
- Fixed missing `@mipmap/ic_launcher` resource issue.

## Localization
- Expanded localization keys for reset, reminders, unavailable/sample states, mantra selection, and numerology.
- Preserved Hindi default and English support.

## Tests
- Improved Jap counter tests, rapid tap model test, goal progress test, numerology validation tests, and localization/navigation tests.
- Added repository contract coverage for the tap queue type.

## Build/test validation results
- Generation environment still does not include Flutter, so `flutter analyze`, `flutter test`, and `flutter build apk --debug` could not be executed here.
- User should run locally with Flutter 3.47.4:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug`
