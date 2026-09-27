/// Statistical helpers for Jap streaks and daily history. Pure functions —
/// no I/O — so they are trivially unit testable.
library;

class DailyRecord {
  const DailyRecord({required this.date, required this.count});
  final DateTime date;
  final int count;
}

class StreakStats {
  const StreakStats({required this.current, required this.best});
  final int current; // today-or-yesterday anchored consecutive days
  final int best; // longest consecutive run ever

  bool get isActive => current > 0;
}

/// Computes current and best streaks from the set of local dates that had at
/// least one Jap. The current streak counts consecutive days ending today;
/// if today has no Jap yet, a streak with counts up to yesterday is still
/// considered active.
StreakStats computeStreakStats(Iterable<DateTime> activeDays, DateTime now) {
  final n = DateTime(now.year, now.month, now.day);
  final today = n;
  final days = <DateTime>{
    for (final d in activeDays) DateTime(d.year, d.month, d.day)
  };
  if (days.isEmpty) return const StreakStats(current: 0, best: 0);

  final sorted = days.toList()..sort();
  // Best streak.
  var best = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    final diff = sorted[i].difference(sorted[i - 1]).inDays;
    if (diff == 1) {
      run++;
      if (run > best) best = run;
    } else {
      run = 1;
    }
  }

  // Current streak anchored at today or yesterday.
  var current = 0;
  var cursor = today;
  if (days.contains(cursor)) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while (days.contains(cursor)) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return StreakStats(current: current, best: best);
}
