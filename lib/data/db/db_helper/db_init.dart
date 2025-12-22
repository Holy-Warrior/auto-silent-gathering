// lib/data/db/db_helper/db_init.dart
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
      version: 3, 
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await DBTables.createTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.transaction((txn) async {

      // ----------------------------
      // v1 → v2 : discard data
      // ----------------------------
      if (oldVersion < 2) {
        await txn.execute(
          'ALTER TABLE sensor_samples RENAME TO sensor_samples_old',
        );

        await txn.execute('''
          CREATE TABLE sensor_samples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            type TEXT NOT NULL,
            x REAL,
            y REAL,
            z REAL,
            bundle_id INTEGER
          )
        ''');

        await txn.execute('DROP TABLE sensor_samples_old');
      }

      // ----------------------------
      // v2 → v3 : preserve data
      // ----------------------------
      if (oldVersion < 3) {
        await txn.execute(
          'ALTER TABLE sensor_samples RENAME TO sensor_samples_v2',
        );

        await txn.execute('''
          CREATE TABLE sensor_samples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            type TEXT NOT NULL,
            x REAL,
            y REAL,
            z REAL,
            sampling_rate TEXT NOT NULL,
            bundle_id INTEGER
          )
        ''');

        await txn.execute('''
          INSERT INTO sensor_samples (
            id, timestamp, type, x, y, z, sampling_rate, bundle_id
          )
          SELECT
            id, timestamp, type, x, y, z, 'fastest', bundle_id
          FROM sensor_samples_v2
        ''');

        await txn.execute('DROP TABLE sensor_samples_v2');
      }
    });
  }


  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
