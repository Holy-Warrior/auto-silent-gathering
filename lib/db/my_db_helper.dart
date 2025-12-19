// lib\db\my_db_helper.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'model_sensor_sample.dart';

class SensorDatabase {
  static const _dbName = 'sensor_data.db';
  static const _dbVersion = 1;

  static Database? _db;

  static Future<Database> get _database async {
    if (_db != null) return _db!;

    final path = join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
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

  /// Insert sensor samples with optional bundle_id
  static Future<void> insertBatch(List<SensorSample> samples, {int? bundleId}) async {
    if (samples.isEmpty) return;
    final db = await _database;

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final s in samples) {
        batch.insert(
          'sensor_samples',
          {
            'timestamp': s.timestamp,
            'type': s.type,
            'x': s.x,
            'y': s.y,
            'z': s.z,
            'bundle_id': bundleId,
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Insert a new time label
  static Future<void> insertTimeLabel({
    required int bundleId,
    required int timestamp,
    required String label,
  }) async {
    final db = await _database;
    await db.insert(
      'time_label',
      {
        'bundle_id': bundleId,
        'timestamp': timestamp,
        'label': label,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Get next unused bundle_id from sensor_samples
  static Future<int> getNextBundleId() async {
    final db = await _database;
    final result = await db.rawQuery('SELECT MAX(bundle_id) as max_id FROM sensor_samples');
    final maxId = result.first['max_id'] as int?;
    return (maxId ?? 0) + 1;
  }

  /// Bundle sensor samples by unique bundle_id into sensor_bundles
  /// Include associated time_label data as JSON
  static Future<void> bundleAndClearSamples({String? tag}) async {
    final db = await _database;

    await db.transaction((txn) async {
      // Get unique bundle_ids
      final List<Map<String, dynamic>> ids = await txn.rawQuery(
        'SELECT DISTINCT bundle_id FROM sensor_samples WHERE bundle_id IS NOT NULL'
      );

      for (final row in ids) {
        final bundleId = row['bundle_id'] as int;

        // Fetch samples for this bundle_id
        final List<Map<String, dynamic>> rows = await txn.query(
          'sensor_samples',
          where: 'bundle_id = ?',
          whereArgs: [bundleId],
        );

        if (rows.isEmpty) continue;

        // Remove bundle_id before encoding JSON
        final sanitizedRows = rows.map((r) {
          final copy = Map<String, dynamic>.from(r);
          copy.remove('bundle_id');
          return copy;
        }).toList();

        final jsonString = jsonEncode(sanitizedRows);

        // Fetch associated time labels
        final List<Map<String, dynamic>> timeLabels = await txn.query(
          'time_label',
          where: 'bundle_id = ?',
          whereArgs: [bundleId],
        );

        final timeLabelJson = jsonEncode(timeLabels);

        // Insert into sensor_bundles
        await txn.insert(
          'sensor_bundles',
          {
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'tag': tag,
            'json_data': jsonString,
            'timed_label': timeLabelJson,
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        // Delete bundled samples and associated time labels
        await txn.delete(
          'sensor_samples',
          where: 'bundle_id = ?',
          whereArgs: [bundleId],
        );
        await txn.delete(
          'time_label',
          where: 'bundle_id = ?',
          whereArgs: [bundleId],
        );
      }
    });
  }

  static Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
