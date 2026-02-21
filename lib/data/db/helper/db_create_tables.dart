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
      bundle_id INTEGER NOT NULL
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

  await db.execute('''
    CREATE TABLE archives (
      id                INTEGER PRIMARY KEY AUTOINCREMENT,
      started_at        INTEGER NOT NULL,
      ended_at          INTEGER NOT NULL,
      duration_ms       INTEGER NOT NULL,
      sample_count      INTEGER NOT NULL,
      created_at        INTEGER NOT NULL,
      is_archive        INTEGER NOT NULL CHECK (is_archive IN (0, 1)),
      path              TEXT NOT NULL,
      is_synced         INTEGER NOT NULL CHECK (is_synced IN (0, 1)) DEFAULT 0,
      local_available   INTEGER NOT NULL DEFAULT 1
    )
  ''');
}
