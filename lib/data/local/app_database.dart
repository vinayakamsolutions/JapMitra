import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();
  Database? _db;
  Future<Database> get db async => _db ??= await _open();
  Future<Database> _open() async =>
      openDatabase(join(await getDatabasesPath(), 'japmitra.db'), version: 2,
          onCreate: (d, v) async {
        await d.execute(
            'CREATE TABLE jap_events(id INTEGER PRIMARY KEY AUTOINCREMENT, mantra TEXT NOT NULL, count INTEGER NOT NULL, createdAt TEXT NOT NULL)');
        await d.execute(
            'CREATE TABLE custom_mantras(id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL UNIQUE, category TEXT NOT NULL, name TEXT, photo TEXT)');
      }, onUpgrade: _upgrade);

  /// Adds the custom-mantra display columns.
  ///
  /// `text` deliberately stays the identity of a mantra: tap history, statistics,
  /// streaks and the day baseline are all keyed on it, so existing rows must keep
  /// matching after the upgrade. `name` and `photo` are purely additive and start
  /// out NULL, which every reader treats as "no custom name" and "no photo", so
  /// no existing mantra changes meaning.
  static Future<void> _upgrade(Database d, int from, int to) async {
    if (from < 2) {
      await d.execute('ALTER TABLE custom_mantras ADD COLUMN name TEXT');
      await d.execute('ALTER TABLE custom_mantras ADD COLUMN photo TEXT');
    }
  }
}
