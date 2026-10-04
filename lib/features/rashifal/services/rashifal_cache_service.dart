import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_rashifal.dart';

/// Local store for a day's generated Rashifal payload.
///
/// The payload is kept as the exact JSON text that was fetched, so what is
/// cached is byte-for-byte what the generator wrote. Nothing is re-shaped on the
/// way in or out, which means a cached day can only ever be the published day.
abstract class RashifalCacheStore {
  /// Reads the cached payload for [dateKey], or `null` when nothing is stored.
  ///
  /// Returns `null` for unreadable or empty content as well, so a corrupt entry
  /// behaves exactly like a missing one.
  Future<String?> read(String dateKey);

  /// Stores [rawJson] under [dateKey] after confirming it is usable.
  ///
  /// Only complete, correctly dated payloads are cached: storing a partial file
  /// would risk it later being shown as a full day. Returns whether it was kept.
  Future<bool> write(String dateKey, String rawJson);

  /// Whether a usable payload is cached for [dateKey].
  Future<bool> has(String dateKey);

  /// The most recent date key that has a cached payload, newest first.
  ///
  /// Lets the UI offer the last available day when the network is down and today
  /// has never been fetched, without guessing.
  Future<String?> latestDateKey();
}

/// [RashifalCacheStore] backed by [SharedPreferences].
///
/// SharedPreferences survives an app restart and needs no extra dependency,
/// which is why it is the store rather than a database table.
class SharedPrefsRashifalCacheStore implements RashifalCacheStore {
  const SharedPrefsRashifalCacheStore();

  /// How many days to keep. The app can step back through history, so a small
  /// history is worth keeping; anything older is dropped on write.
  static const int maxCachedDays = 14;

  static const _prefix = 'rashifal_v1_';

  static String _key(String dateKey) => '$_prefix$dateKey';

  @override
  Future<String?> read(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key(dateKey));
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<bool> write(String dateKey, String rawJson) async {
    final parsed = DailyRashifal.tryParse(rawJson);
    if (parsed == null) return false;
    if (parsed.date != dateKey) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(dateKey), jsonEncode(parsed.toJson()));
    await _prune(prefs);
    return true;
  }

  @override
  Future<bool> has(String dateKey) async => await read(dateKey) != null;

  @override
  Future<String?> latestDateKey() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(_prefix))
        .map((k) => k.substring(_prefix.length))
        .where(isValidDateKey)
        .toList()
      ..sort();
    return keys.isEmpty ? null : keys.last;
  }

  /// Drops cached days that are no longer worth keeping.
  Future<void> _prune(SharedPreferences prefs) async {
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(_prefix))
        .map((k) => k.substring(_prefix.length))
        .where(isValidDateKey)
        .toList()
      ..sort();

    if (keys.length <= maxCachedDays) return;

    final overflow = keys.length - maxCachedDays;
    for (final key in keys.take(overflow)) {
      await prefs.remove(_key(key));
    }
  }
}
