<<<<<<< HEAD
// lib\data\db\db_helper\db_tables.dart
=======
// lib/db/db_helper/db_tables.dart
>>>>>>> 05df9a8784000fe5cd4c6effe305385eb36d8d54
import 'package:sqflite/sqflite.dart';

class DBTables {
  DBTables._();

  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE sensor_samples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        type TEXT NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        z REAL NOT NULL,
        bundle_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE sensor_bundles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL,
        tag TEXT,
        json_data TEXT NOT NULL,
        timed_label TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE time_label (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bundle_id INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        label TEXT NOT NULL
      )
    ''');
  }
}
