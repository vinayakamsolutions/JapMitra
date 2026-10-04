import 'package:timezone/timezone.dart' as tz;

import '../models/daily_rashifal.dart';
import 'rashifal_bundled_service.dart';
import 'rashifal_cache_service.dart';
import 'rashifal_remote_service.dart';

/// A day's reading, plus where it came from.
///
/// The source matters to the user: a saved copy is worth labelling as such rather
/// than letting it pass for a fresh fetch.
class RashifalDayResult {
  const RashifalDayResult({required this.data, required this.fromCache});

  final DailyRashifal data;

  /// True when the reading came from local storage (bundled or cached) rather
  /// than the network.
  final bool fromCache;
}

/// Decides where a day's reading comes from.
///
/// The order is fixed and deliberate:
///
/// 1. a remote fetch, validated, cached, shown;
/// 2. otherwise the exact-date copy bundled in the APK, shown offline;
/// 3. otherwise the cached copy, shown;
/// 4. otherwise an honest "unavailable" state.
///
/// The class never invents content and never substitutes one day for another, so
/// a caller can trust that a non-null result really is the requested day.
class RashifalRepository {
  RashifalRepository({
    RashifalBundledSource? bundled,
    RashifalCacheStore? cache,
    RashifalRemoteSource? remote,
    DateTime Function()? now,
  })  : _bundled = bundled ?? const AssetRashifalBundledSource(),
        _cache = cache ?? const SharedPrefsRashifalCacheStore(),
        _remote = remote ?? const HttpRashifalRemoteSource(),
        _now = now ?? _nowInKolkata;

  final RashifalBundledSource _bundled;
  final RashifalCacheStore _cache;
  final RashifalRemoteSource _remote;

  /// Injectable clock so tests can pin "today".
  final DateTime Function() _now;

  /// "Today" in Asia/Kolkata, whatever timezone the device is set to.
  ///
  /// The reading is keyed on the Indian calendar day, so the day boundary has to
  /// be India's: a device set to another timezone would otherwise ask for the
  /// wrong day around midnight.
  static DateTime _nowInKolkata() {
    try {
      final kolkata = tz.getLocation('Asia/Kolkata');
      final now = tz.TZDateTime.now(kolkata);
      return DateTime(now.year, now.month, now.day);
    } catch (_) {
      // Timezone data unavailable (should not happen: the app initialises it):
      // fall back to the device's own calendar day rather than failing to open.
      final n = DateTime.now();
      return DateTime(n.year, n.month, n.day);
    }
  }

  /// Today as a calendar day, with the time of day discarded.
  ///
  /// Whole days are what the system is keyed on, so midnight is the honest
  /// comparison point.
  DateTime get today {
    final n = _now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Whether [date] is later than today.
  ///
  /// Such a day cannot have been generated yet, so the UI uses this to refuse to
  /// ask for it and to explain why.
  bool isFuture(DateTime date) => _dayOf(date).isAfter(today);

  /// The full reading for [date], or `null` when it is not available.
  ///
  /// A `null` result means the day could be found neither bundled, nor fetched,
  /// nor cached; the caller should say so rather than show anything else.
  Future<RashifalDayResult?> getForDate(DateTime date) async {
    final day = _dayOf(date);
    final key = dateKeyOf(day);

    // A future date is refused without a request: there is nothing to fetch, and
    // guessing would mean showing invented content.
    if (day.isAfter(today)) return null;

    // 1. Try the network first so an installed APK can receive newly published
    //    content without an APK update. A successful fetch is cached for later
    //    offline opens.
    final remote = await _remote.fetchDay(key);
    if (remote != null) {
      final parsed = _usable(remote, key);
      if (parsed != null) {
        await _cache.write(key, remote);
        return RashifalDayResult(data: parsed, fromCache: false);
      }
    }

    // 2. The exact-date bundled copy. It preserves offline support when the
    //    network is unavailable, but can never replace the requested date.
    final bundled = await _bundled.fetchDay(key);
    if (bundled != null) {
      final parsed = _usable(bundled, key);
      if (parsed != null) {
        return RashifalDayResult(data: parsed, fromCache: true);
      }
    }

    // 3. The cache, which can only contain a payload that already validated and
    //    matched this day.
    final cached = await _cache.read(key);
    if (cached == null) return null;
    final parsed = _usable(cached, key);
    if (parsed == null) return null;
    return RashifalDayResult(data: parsed, fromCache: true);
  }

  /// One sign's reading for [date], or `null` when the day or sign is unavailable.
  Future<SignRashifal?> getSign(
    DateTime date,
    String signKey, {
    String language = 'hi',
  }) async {
    final day = await getForDate(date);
    if (day == null) return null;
    return day.data.signsFor(language)[signKey];
  }

  /// Whether a usable copy of [date] is already cached.
  ///
  /// Lets the UI mark a day as available offline before it spends a request.
  Future<bool> isCached(DateTime date) => _cache.has(dateKeyOf(_dayOf(date)));

  /// Parses [raw] and confirms it is a complete reading for [key].
  ///
  /// The payload must name the day it was asked for, and it must be whole: a day
  /// with a sign or a language missing would leave the UI showing blank
  /// sections, which is worse than saying the day is unavailable.
  DailyRashifal? _usable(String raw, String key) {
    final parsed = DailyRashifal.tryParse(raw);
    if (parsed == null || parsed.date != key || !parsed.isComplete) return null;
    return parsed;
  }

  DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);
}
