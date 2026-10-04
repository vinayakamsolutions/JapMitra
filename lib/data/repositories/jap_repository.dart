import 'dart:async';

import '../local/jap_store.dart';
import '../../features/jap/jap_stats.dart';

/// Repository for all Jap persistence. All reads are per-mantra so different
/// mantras never share totals.
class JapRepository {
  JapRepository({JapStore? store}) : store = store ?? SqfliteJapStore();

  final JapStore store;

  /// Batched async write of [amount] Jap for [mantra].
  Future<void> addJaps(String mantra, int amount, {DateTime? at}) async {
    if (amount <= 0) return;
    await store.insertEvent(mantra, amount, at ?? DateTime.now());
  }

  Future<void> addJap(String mantra, {DateTime? at}) =>
      addJaps(mantra, 1, at: at);

  Future<int> countForMantraSince(String mantra, DateTime start,
          {DateTime? end}) =>
      store.sumSince(mantra, start, end: end);

  Future<int> todayCountForMantra(String mantra, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final start = DateTime(n.year, n.month, n.day);
    return store.sumSince(mantra, start,
        end: start.add(const Duration(days: 1)));
  }

  Future<void> resetTodayForMantra(String mantra, {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final start = DateTime(n.year, n.month, n.day);
    final end = start.add(const Duration(days: 1));
    // Only clear persisted events; this mantra's earlier days stay untouched.
    await store.deleteSince(mantra, start, end: end);
  }

  Future<int> lifetime({String? mantra}) async {
    if (mantra == null) return store.sumAll();
    return store.sumSince(mantra, DateTime(1900));
  }

  /// Per-day totals (local calendar days) for the last [daysBack] days
  /// ending today, inclusive, oldest first.
  Future<List<DailyRecord>> dailyCounts(String mantra,
      {DateTime? now, int daysBack = 7}) async {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final start = today.subtract(Duration(days: daysBack - 1));
    final events = await store.events(mantra,
        start: start, end: today.add(const Duration(days: 1)));
    final byDay = <String, int>{};
    for (final e in events) {
      final day = DateTime(e.at.year, e.at.month, e.at.day);
      final key = day.toIso8601String().substring(0, 10);
      byDay[key] = (byDay[key] ?? 0) + e.count;
    }
    final result = <DailyRecord>[];
    for (var i = 0; i < daysBack; i++) {
      final day = start.add(Duration(days: i));
      final key = day.toIso8601String().substring(0, 10);
      result.add(DailyRecord(date: day, count: byDay[key] ?? 0));
    }
    return result;
  }

  /// All local days (ascending) with at least one Jap for this mantra.
  Future<List<DailyRecord>> historyDays(String mantra, {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final events =
        await store.events(mantra, end: today.add(const Duration(days: 1)));
    final byDay = <String, int>{};
    for (final e in events) {
      if (e.count <= 0) continue;
      final day = DateTime(e.at.year, e.at.month, e.at.day);
      final key = day.toIso8601String().substring(0, 10);
      byDay[key] = (byDay[key] ?? 0) + e.count;
    }
    final result = byDay.entries
        .map((e) => DailyRecord(
              date: DateTime.parse(e.key),
              count: e.value,
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  Future<StreakStats> streaks(String mantra, {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final days = await historyDays(mantra, now: n);
    return computeStreakStats(days.map((r) => r.date), n);
  }

  /// Every stored custom mantra, with the display metadata the editor collected.
  Future<List<CustomMantra>> custom() => store.listCustom();

  /// Just the mantra texts, for callers that key on identity alone.
  Future<List<String>> customMantras() async =>
      [for (final m in await store.listCustom()) m.text];

  /// Saves a custom mantra together with its optional name and deity photo.
  ///
  /// The text is the identity: it must stay stable across renames so that tap
  /// history, statistics and streaks keep matching the mantra the user already
  /// has counts for.
  Future<void> addCustom(String text, {String? name, String? photo}) async {
    if (text.trim().isEmpty) throw ArgumentError('Empty mantra');
    await store.addCustomMantra(text.trim(), name: name, photo: photo);
  }

  Future<void> deleteCustom(String text) => store.removeCustomMantra(text);
}

/// Serializes rapid taps into batched, debounced DB writes without losing a
/// single tap and without ever blocking the caller.
///
/// [recordTap] is synchronous and returns immediately. Pending counts are
/// accumulated and written as one row shortly after the tap burst stops, so a
/// burst of 50 taps performs a single cheap insert instead of 50.
class JapTapQueue {
  JapTapQueue(this.repository, this.mantra,
      {this.debounce = const Duration(milliseconds: 600)});
  final JapRepository repository;
  final String mantra;
  final Duration debounce;

  int _pending = 0;
  Timer? _timer;

  /// Call synchronously on every physical tap. Never blocks, never awaits I/O.
  void recordTap() {
    _pending++;
    _timer?.cancel();
    _timer = Timer(debounce, _flushPending);
  }

  Future<void> _flushPending() async {
    _timer = null;
    if (_pending == 0) return;
    final amount = _pending;
    _pending = 0;
    await repository.addJaps(mantra, amount);
  }

  /// Flush any pending tap immediately (used on dispose / session end).
  /// Safe to call any number of times.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_pending == 0) return;
    final amount = _pending;
    _pending = 0;
    await repository.addJaps(mantra, amount);
  }

  int get pending => _pending;
}
