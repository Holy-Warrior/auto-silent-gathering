// lib\data\db\sensor_db_controller.dart
import 'package:sqflite/sqflite.dart';
import 'db_helper/db_init.dart';
import 'dart:convert';
import 'package:motion_test/data/models/sensor_sample.dart';

class SensorDbController {
  SensorDbController._();
  static final SensorDbController instance = SensorDbController._();
  static Future<Database> get _db async => await DBInit.instance.database;
  static Future<void> close() async => await DBInit.instance.close();


  static double? nanToNull(double v) {
    if (v.isNaN || v.isInfinite) return null;
    return v;
  }


  /// Insert a new time label
  static Future<void> insertTimeLabel({
    required int bundleId,
    required int timestamp,
    required String label,
  }) async {
    final database = await _db;
    await database.insert(
      'time_label',
      {
        'bundle_id': bundleId,
        'timestamp': timestamp,
        'label': label,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }



  /// Insert sensor samples with optional bundle_id
  static Future<void> insertBatch(List<SensorSample> samples, {int? bundleId}) async {
    if (samples.isEmpty) return;
    final database = await _db;

    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final s in samples) {
        batch.insert(
          'sensor_samples',
          {
            'timestamp': s.timestamp,
            'type': s.type,
            'sampling_rate': s.samplingRate,
            'x': nanToNull(s.x),
            'y': nanToNull(s.y),
            'z': nanToNull(s.z),
            'bundle_id': bundleId,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    });
  }



  /// Get next unused bundle_id from sensor_samples
  static Future<int> getNextBundleId() async {
    final database = await _db;
    final result = await database.rawQuery(
      'SELECT MAX(bundle_id) as max_id FROM sensor_samples',
    );
    return (result.first['max_id'] as int? ?? 0) + 1;
  }

  /// Bundle sensor samples by unique bundle_id into sensor_bundles
  /// Include associated time_label data as JSON
  static Future<void> bundleAndClearSamples({String? tag}) async {
    final database = await _db;
    await database.transaction((txn) async {
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
          conflictAlgorithm: ConflictAlgorithm.ignore,
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




}
