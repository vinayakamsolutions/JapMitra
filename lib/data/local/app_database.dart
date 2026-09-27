import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();
  Database? _db;
  Future<Database> get db async => _db ??= await _open();
  Future<Database> _open() async =>
      openDatabase(join(await getDatabasesPath(), 'japmitra.db'), version: 1,
          onCreate: (d, v) async {
        await d.execute(
            'CREATE TABLE jap_events(id INTEGER PRIMARY KEY AUTOINCREMENT, mantra TEXT NOT NULL, count INTEGER NOT NULL, createdAt TEXT NOT NULL)');
        await d.execute(
            'CREATE TABLE custom_mantras(id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL UNIQUE, category TEXT NOT NULL)');
      });
}
