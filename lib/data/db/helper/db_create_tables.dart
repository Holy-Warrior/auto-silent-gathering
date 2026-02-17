import 'package:sqflite/sqflite.dart';

Future<void> createTables(Database db) async {
  await db.execute('''
      CREATE TABLE sensor_samples (
        timestamp INTEGER NOT NULL,
        sensor_type INTEGER NOT NULL,       -- use small integer IDs for sensor types
        x REAL,                             -- consider rounding values in Dart before inserting
        y REAL,
        z REAL,
        sampling_rate SMALLINT NOT NULL,    -- 2 bytes enough for 0–65535 Hz
        bundle_id INTEGER
      )
    ''');

  await db.execute('''
      CREATE TABLE sensor_bundles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        timed_label TEXT,
        crash_recovery TEXT
      )
    ''');

  await db.execute('''
    CREATE TABLE time_label (
      bundle_id INTEGER NOT NULL,
      timestamp INTEGER NOT NULL,
      is_nimaz INTEGER NOT NULL CHECK (is_nimaz IN (0, 1))
    )
  ''');

  await db.execute('''
    CREATE TABLE crash_recovery (
      bundle_id INTEGER NOT NULL,
      timestamp INTEGER NOT NULL
    )
  ''');

  // await db.execute('''
  //   CREATE TABLE session_archives (
  //     id INTEGER PRIMARY KEY AUTOINCREMENT,
  //     bundle_id INTEGER,
  //     title TEXT NOT NULL,
  //     sample_count INTEGER NOT NULL DEFAULT 0,
  //     started_at INTEGER,
  //     ended_at INTEGER,
  //     duration_ms INTEGER NOT NULL DEFAULT 0,
  //     json_name TEXT NOT NULL,
  //     archive_path TEXT,
  //     sync_status TEXT NOT NULL DEFAULT 'pending',
  //     local_available INTEGER NOT NULL DEFAULT 1,
  //     is_exported INTEGER NOT NULL DEFAULT 0,
  //     created_at INTEGER NOT NULL
  //   )
  // ''');

}
