// lib\data\db\db_helper\db_init.dart
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
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await DBTables.createTables(db); // delegate to table definitions
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        // Rename old table
        await txn.execute(
          'ALTER TABLE sensor_samples RENAME TO sensor_samples_old',
        );

        // Recreate table with nullable axes
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

        // Copy data
        await txn.execute('''
          INSERT INTO sensor_samples (id, timestamp, type, x, y, z, bundle_id)
          SELECT id, timestamp, type, x, y, z, bundle_id
          FROM sensor_samples_old
        ''');

        // Drop old table
        await txn.execute('DROP TABLE sensor_samples_old');
      });
    }
  }


  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
