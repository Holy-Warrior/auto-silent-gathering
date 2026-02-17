import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../helper/db_init_instance.dart';
import 'dart:convert';
import '../models/sensor_sample.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:asg/data/constants/config.dart';
import 'utils.dart';

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
    required bool isNimaz,
  }) async {
    final database = await _db;
    await database.insert('time_label', {
      'bundle_id': bundleId,
      'timestamp': timestamp,
      'is_nimaz': isNimaz ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Insert a new crash recovery record
  static Future<void> insertCrashRecoveryRecord({
    required int bundleId,
    required int timestamp,
  }) async {
    final database = await _db;
    await database.insert('crash_recovery', {
      'bundle_id': bundleId,
      'timestamp': timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Insert sensor samples
  static Future<void> insertBatch(
    List<SensorSample> samples, {
    required int bundleId,
  }) async {
    if (samples.isEmpty) return;
    final database = await _db;

    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final s in samples) {
        batch.insert('sensor_samples', {
          'timestamp': s.timestamp,
          'sensor_type': s.sensorType, // was s.sensor
          'sampling_rate': s.samplingPeriod,
          'x': nanToNull(s.x),
          'y': nanToNull(s.y),
          'z': nanToNull(s.z),
          'bundle_id': bundleId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Get next unused bundle_id from sensor_samples
  static Future<int> getNextBundleId({
    bool recoverPreviouslyUsedId = false,
  }) async {
    final db = await _db;

    final r1 = await db.rawQuery(
      'SELECT MAX(bundle_id) as max_id FROM sensor_samples',
    );
    final maxSamples = r1.first['max_id'] as int?;

    if (maxSamples != null) {
      return recoverPreviouslyUsedId ? maxSamples : maxSamples + 1;
    }

    final r2 = await db.rawQuery(
      'SELECT MAX(id) as max_id FROM sensor_bundles',
    );
    final maxBundles = r2.first['max_id'] as int? ?? 0;
    return recoverPreviouslyUsedId ? maxBundles : maxBundles + 1;
  }

  /// Bundle sensor samples by unique bundle_id into sensor_bundles
  /// Include associated time_label data as JSON
  static Future<void> bundleAndClearSamples() async {
    final database = await _db;
    final dir = await getApplicationDocumentsDirectory();

    await database.transaction((txn) async {
      final ids = await txn.rawQuery(
        'SELECT DISTINCT bundle_id FROM sensor_samples WHERE bundle_id IS NOT NULL',
      );

      for (final row in ids) {
        final int bundleId = row['bundle_id'] as int;

        final rows = await txn.query(
          'sensor_samples',
          where: 'bundle_id = ?',
          whereArgs: [bundleId],
        );

        if (rows.isEmpty) continue;

        // final timestamps = rows
        //     .map((r) => r['timestamp'])
        //     .whereType<int>()
        //     .toList(growable: false);
        // final int? startedAt = timestamps.isEmpty
        //     ? null
        //     : timestamps.reduce((a, b) => a < b ? a : b);
        // final int? endedAt = timestamps.isEmpty
        //     ? null
        //     : timestamps.reduce((a, b) => a > b ? a : b);
        // final int durationMs = (startedAt != null && endedAt != null)
        //     ? endedAt - startedAt
        //     : 0;

        // Make mutable copy and remove bundle_id
        final sanitizedRows = rows
            .map(
              (r) => {
                't': r['timestamp'],
                's': r['sensor_type'],
                'v': [r['x'], r['y'], r['z']],
              },
            )
            .toList();

        // Write JSON file
        final jsonString = jsonEncode(sanitizedRows);
        final now = DateTime.now().millisecondsSinceEpoch;
        // final jsonFileName = 'bundle_$now.json';
        // final file = File('${dir.path}/$jsonFileName');
        final file = File('${dir.path}/bundle_$now.json');
        await file.writeAsString(jsonString);

        // Time labels
        final timeLabels = await txn.query(
          'time_label',
          where: 'bundle_id = ?',
          whereArgs: [bundleId],
        );

        // Time labels
        final crashRecovery = await txn.query(
          'crash_recovery',
          where: 'bundle_id = ?',
          whereArgs: [bundleId],
        );

        // Insert into sensor_bundles
        await txn.insert('sensor_bundles', {
          'created_at': now,
          'file_path': file.path,
          'timed_label': jsonEncode(timeLabels),
          'crash_recovery': jsonEncode(crashRecovery),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        // await txn.insert('session_archives', {
        //   'bundle_id': bundleId,
        //   'title': 'Session $bundleId',
        //   'sample_count': rows.length,
        //   'started_at': startedAt,
        //   'ended_at': endedAt,
        //   'duration_ms': durationMs,
        //   'json_name': jsonFileName,
        //   'archive_path': null,
        //   'sync_status': 'pending',
        //   'local_available': 1,
        //   'is_exported': 0,
        //   'created_at': now,
        // }, conflictAlgorithm: ConflictAlgorithm.replace);

        // Clear original samples
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
        await txn.delete(
          'crash_recovery',
          where: 'bundle_id = ?',
          whereArgs: [bundleId],
        );
      }
    });
  }

  static Future<File?> bundleAndExportZip() async {
    final db = await _db;

    // Step 1: bundle new samples
    await bundleAndClearSamples();

    final bundles = await db.query('sensor_bundles');

    final dir = await getApplicationDocumentsDirectory();
    final zipFile = File(await Config.zipArchivePath());

    if (bundles.isEmpty) {
      return await zipFile.exists() ? zipFile : null;
    }

    final List<int> archivedBundleIds = [];

    final info = await ControllerUtils.deviceInfoString();

    for (final bundle in bundles) {
      final filePath = bundle['file_path'] as String?;
      final bundleId = bundle['id'] as int?;

      if (filePath == null || bundleId == null) continue;

      final file = File(filePath);
      if (!await file.exists()) continue;

      try {
        // Read original JSON
        final jsonStr = await file.readAsString();
        final jsonData = jsonDecode(jsonStr);

        // Build final wrapped JSON
        final wrappedJson = {
          "created_at": bundle['created_at'],
          "timed_label": (bundle['timed_label'] != null 
                          && (bundle['timed_label'] as String).isNotEmpty)
                            ? jsonDecode(bundle['timed_label'] as String)
                            : [],
          "crash_recovery": (bundle['crash_recovery'] != null 
                          && (bundle['crash_recovery'] as String).isNotEmpty)
                            ? jsonDecode(bundle['crash_recovery'] as String)
                            : [],
          "samplingPeriod": Config.samplingPeriod.inMilliseconds,
          "device_name": info.deviceName,
          "device_model": info.deviceModel,
          "json": jsonData,
        };

        // Write temporary file to pass to archive
        final tempFilePath = p.join(dir.path, 'temp_bundle_$bundleId.json');
        final tempFile = File(tempFilePath);
        await tempFile.writeAsString(jsonEncode(wrappedJson));

        await ControllerUtils.addJsonToArchive(tempFilePath);

        // delete original bundle JSON
        await file.delete();

        // await db.update(
        //   'session_archives',
        //   {
        //     'archive_path': zipFile.path,
        //     'json_name': 'temp_bundle_$bundleId.json',
        //     'is_exported': 1,
        //   },
        //   where: 'bundle_id = ?',
        //   whereArgs: [bundleId],
        // );

        archivedBundleIds.add(bundleId);
      } catch (_) {
        continue;
      }
    }

    if (archivedBundleIds.isEmpty) {
      return await zipFile.exists() ? zipFile : null;
    }

    // Clean DB
    await db.transaction((txn) async {
      final ids = archivedBundleIds.join(',');
      await txn.rawDelete('DELETE FROM sensor_bundles WHERE id IN ($ids)');
    });

    return await zipFile.exists() ? zipFile : null;
  }

  /// Get database statistics and bundle table schema (excluding JSON blobs)
  static Future<Map<String, dynamic>> getDatabaseStats() async {
    final database = await _db;

    // Row counts
    Future<int> count(String table) async {
      final r = await database.rawQuery('SELECT COUNT(*) as c FROM $table');
      return r.first['c'] as int;
    }

    final tableCounts = {
      'sensor_samples': await count('sensor_samples'),
      'sensor_bundles': await count('sensor_bundles'),
      'time_label': await count('time_label'),
      // 'session_archives': await count('session_archives'),
    };

    // Bundle table schema (exclude json_data)
    final List<Map<String, dynamic>> pragma = await database.rawQuery(
      'PRAGMA table_info(sensor_bundles)',
    );

    final schema = pragma
        .where((c) => c['name'] != 'json_data')
        .map(
          (c) => {
            'name': c['name'],
            'type': c['type'],
            'nullable': c['notnull'] == 0,
          },
        )
        .toList();

    // final currentSamples = tableCounts['sensor_samples'] as int;
    // final pendingBundles = tableCounts['sensor_bundles'] as int;

    // final String sessionSource;
    // if (currentSamples > 0) {
    //   sessionSource = 'current';
    // } else if (pendingBundles > 0) {
    //   sessionSource = 'previous';
    // } else {
    //   sessionSource = 'none';
    // }

    // final recentArchives = await database.query(
    //   'session_archives',
    //   orderBy: 'created_at DESC',
    //   limit: 10,
    // );

    // return {
    //   'tables': tableCounts,
    //   'sensor_bundles_schema': schema,
    //   'session_summary': {
    //     'source': sessionSource,
    //     'current_samples': currentSamples,
    //     'pending_previous_session_bundles': pendingBundles,
    //     'archives_total': tableCounts['session_archives'],
    //   },
    //   'recent_archives': recentArchives,
    // };
    return {'tables': tableCounts, 'sensor_bundles_schema': schema};
  }
}
