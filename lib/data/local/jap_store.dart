import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

/// One stored mutable Jap event row (a batched count written at a timestamp).
class JapEventRow {
  const JapEventRow({required this.count, required this.at});
  final int count;
  final DateTime at;
}

/// Thin storage contract behind [JapRepository].
///
/// Kept independent of sqflite so production uses [SqfliteJapStore] while
/// tests can substitute an in-memory implementation without pulling in a
/// native database plugin.
abstract class JapStore {
  Future<void> insertEvent(String mantra, int count, DateTime at);
  Future<int> sumSince(String mantra, DateTime start, {DateTime? end});
  Future<int> sumAll();
  Future<void> deleteSince(String mantra, DateTime start, {DateTime? end});
  Future<List<JapEventRow>> events(String mantra,
      {DateTime? start, DateTime? end});
  Future<List<String>> listCustomMantras();
  Future<void> addCustomMantra(String text);
  Future<void> removeCustomMantra(String text);
}

/// sqflite-backed [JapStore].
class SqfliteJapStore implements JapStore {
  Future<Database> get _db => AppDatabase.instance.db;

  @override
  Future<void> insertEvent(String mantra, int count, DateTime at) async {
    final d = await _db;
    await d.insert('jap_events', {
      'mantra': mantra,
      'count': count,
      'createdAt': at.toIso8601String(),
    });
  }

  @override
  Future<int> sumSince(String mantra, DateTime start, {DateTime? end}) async {
    final d = await _db;
    final args = <Object>[mantra, start.toIso8601String()];
    var where = 'mantra = ? AND createdAt >= ?';
    if (end != null) {
      where += ' AND createdAt < ?';
      args.add(end.toIso8601String());
    }
    final r = await d.rawQuery(
        'SELECT COALESCE(SUM(count),0) c FROM jap_events WHERE $where', args);
    return (r.first['c'] as int?) ?? 0;
  }

  @override
  Future<void> deleteSince(String mantra, DateTime start,
      {DateTime? end}) async {
    final d = await _db;
    final args = <Object>[mantra, start.toIso8601String()];
    var where = 'mantra = ? AND createdAt >= ?';
    if (end != null) {
      where += ' AND createdAt < ?';
      args.add(end.toIso8601String());
    }
    await d.delete('jap_events', where: where, whereArgs: args);
  }

  @override
  Future<int> sumAll() async {
    final d = await _db;
    final r =
        await d.rawQuery('SELECT COALESCE(SUM(count),0) c FROM jap_events');
    return (r.first['c'] as int?) ?? 0;
  }

  @override
  Future<List<JapEventRow>> events(String mantra,
      {DateTime? start, DateTime? end}) async {
    final d = await _db;
    final args = <Object>[mantra];
    var where = 'mantra = ?';
    if (start != null) {
      where += ' AND createdAt >= ?';
      args.add(start.toIso8601String());
    }
    if (end != null) {
      where += ' AND createdAt < ?';
      args.add(end.toIso8601String());
    }
    final rows = await d.query('jap_events',
        columns: ['count', 'createdAt'], where: where, whereArgs: args);
    final out = <JapEventRow>[];
    for (final row in rows) {
      final at = DateTime.tryParse(row['createdAt'] as String? ?? '');
      if (at == null) continue;
      out.add(JapEventRow(count: (row['count'] as int?) ?? 0, at: at));
    }
    return out;
  }

  @override
  Future<List<String>> listCustomMantras() async {
    final d = await _db;
    final rows = await d.query('custom_mantras', orderBy: 'text');
    return rows.map((e) => e['text'] as String).toList();
  }

  @override
  Future<void> addCustomMantra(String text) async {
    final d = await _db;
    await d
        .insert('custom_mantras', {'text': text.trim(), 'category': 'Custom'});
  }

  @override
  Future<void> removeCustomMantra(String text) async {
    final d = await _db;
    await d.delete('custom_mantras', where: 'text=?', whereArgs: [text]);
  }
}
