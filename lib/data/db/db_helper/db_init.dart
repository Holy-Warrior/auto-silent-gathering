// lib/db/db_helper/db_init.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'db_tables.dart';

class DBInit {
  DBInit._();
  static final DBInit instance = DBInit._();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    final path = join(await getDatabasesPath(), 'sensor_data.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await DBTables.createTables(db); // delegate to table definitions
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
