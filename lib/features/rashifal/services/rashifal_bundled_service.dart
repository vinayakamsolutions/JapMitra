import 'package:flutter/services.dart' show rootBundle;

/// Reads a day's generated Rashifal payload from the assets bundled into the
/// APK.
///
/// This is the offline half of the system: the day files ship inside the app,
/// so a reading can be shown with no network at all. The files are the exact
/// JSON the generator wrote into `data/rashifal/`, copied verbatim into
/// `assets/data/rashifal/` at build time, so what is bundled is byte-for-byte
/// what the generator published.
///
/// A missing or unreadable asset is reported as `null`, exactly like a failed
/// network fetch, so the repository's fallback chain treats the two alike.
abstract class RashifalBundledSource {
  /// Loads the bundled payload for [dateKey], or `null` when the APK carries
  /// no file for that day.
  Future<String?> fetchDay(String dateKey);
}

/// [RashifalBundledSource] backed by `rootBundle`.
///
/// The asset path is fixed and public: `assets/data/rashifal/YYYY-MM-DD.json`.
/// Nothing here is secret and no key is involved, which keeps the feature
/// zero-cost.
class AssetRashifalBundledSource implements RashifalBundledSource {
  const AssetRashifalBundledSource();

  /// Where the bundled day files live inside the APK.
  static const String kAssetDir = 'assets/data/rashifal';

  @override
  Future<String?> fetchDay(String dateKey) async {
    try {
      final raw = await rootBundle.loadString('$kAssetDir/$dateKey.json');
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      // No such asset, or it could not be read: behave like any other source
      // that has nothing for this day.
      return null;
    }
  }
}
