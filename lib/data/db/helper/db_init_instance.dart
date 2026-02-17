import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'db_create_tables.dart';

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
      // onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await createTables(db);
  }

  // Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  //   if (oldVersion < 2) {
  //     await db.execute('''
  //       CREATE TABLE IF NOT EXISTS session_archives (
  //         id INTEGER PRIMARY KEY AUTOINCREMENT,
  //         bundle_id INTEGER,
  //         title TEXT NOT NULL,
  //         sample_count INTEGER NOT NULL DEFAULT 0,
  //         started_at INTEGER,
  //         ended_at INTEGER,
  //         duration_ms INTEGER NOT NULL DEFAULT 0,
  //         json_name TEXT NOT NULL,
  //         archive_path TEXT,
  //         sync_status TEXT NOT NULL DEFAULT 'pending',
  //         local_available INTEGER NOT NULL DEFAULT 1,
  //         is_exported INTEGER NOT NULL DEFAULT 0,
  //         created_at INTEGER NOT NULL
  //       )
  //     ''');
  //   }
  // }


  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
