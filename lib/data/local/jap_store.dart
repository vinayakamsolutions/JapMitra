import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

/// One stored mutable Jap event row (a batched count written at a timestamp).
class JapEventRow {
  const JapEventRow({required this.count, required this.at});
  final int count;
  final DateTime at;
}

/// One stored custom mantra.
///
/// [text] is the identity, and is what every tap, statistic and baseline is
/// keyed on. [name] and [photo] are optional display metadata the user adds in
/// the mantra editor; when they are absent the mantra simply behaves exactly as
/// it did before they existed.
class CustomMantra {
  const CustomMantra({required this.text, this.name, this.photo});

  final String text;
  final String? name;

  /// Absolute path of the deity photo inside app-private storage, or null.
  final String? photo;

  /// What the UI shows for this mantra: the user's name when they set one,
  /// otherwise the mantra text itself.
  String get label {
    final n = name?.trim();
    return n == null || n.isEmpty ? text : n;
  }

  bool get hasPhoto {
    final p = photo?.trim();
    return p != null && p.isNotEmpty;
  }
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
  Future<List<CustomMantra>> listCustom();
  Future<void> addCustomMantra(String text, {String? name, String? photo});
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
  Future<List<CustomMantra>> listCustom() async {
    final d = await _db;
    final rows = await d.query('custom_mantras', orderBy: 'text');
    return [
      for (final e in rows)
        CustomMantra(
          text: e['text'] as String,
          name: e['name'] as String?,
          photo: e['photo'] as String?,
        )
    ];
  }

  @override
  Future<void> addCustomMantra(String text,
      {String? name, String? photo}) async {
    final d = await _db;
    final n = name?.trim();
    final p = photo?.trim();
    await d.insert('custom_mantras', {
      'text': text.trim(),
      'category': 'Custom',
      'name': n == null || n.isEmpty ? null : n,
      'photo': p == null || p.isEmpty ? null : p,
    });
  }

  @override
  Future<void> removeCustomMantra(String text) async {
    final d = await _db;
    await d.delete('custom_mantras', where: 'text=?', whereArgs: [text]);
  }
}
