import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import '../helper/db_init_instance.dart';
import 'dart:convert';
import '../models/sensor_sample.dart';
import 'dart:io';
import 'package:asg/data/constants/config.dart';
import 'utils.dart';
import 'utils/file_controllers.dart';
import 'package:intl/intl.dart';

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
  static Future<void> insertTimeLabel({required int bundleId, required int timestamp, required bool isNimaz}) async {
    final database = await _db;
    await database.insert('time_label', {
      'bundle_id': bundleId,
      'timestamp': timestamp,
      'is_nimaz': isNimaz ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Insert a new crash recovery record
  static Future<void> insertCrashRecoveryRecord({required int bundleId, required int timestamp}) async {
    final database = await _db;
    await database.insert('crash_recovery', {
      'bundle_id': bundleId,
      'timestamp': timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Insert sensor samples
  static Future<void> insertBatch(List<SensorSample> samples, {required int bundleId}) async {
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

  /// Get next unused bundle_id
  static Future<int> getNextBundleId({bool recoverPreviouslyUsedId = false}) async {
    final db = await _db;
    var r = await db.rawQuery('SELECT COUNT(*) AS count FROM time_label');
    if (r.first['count'] as int > 0) {
      return 1;
    } else {
      r = await db.rawQuery('SELECT MAX(bundle_id) as max_id FROM time_label');
      final maxBundles = r.first['max_id'] as int? ?? 1;
      return recoverPreviouslyUsedId ? maxBundles : maxBundles + 1;
    }
  }

  /// Bundle sensor samples by unique bundle_id into sensor_bundles
  /// Include associated time_label data as JSON
  static Future<void> _bundleAndClearSamples() async {
    final database = await _db;

    await database.transaction((txn) async {
      final ids = await txn.rawQuery('SELECT DISTINCT bundle_id FROM sensor_samples WHERE bundle_id IS NOT NULL');
      if (ids.isEmpty) return;

      for (final row in ids) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final int bundleId = row['bundle_id'] as int;
        final rows = await txn.query('sensor_samples', where: 'bundle_id = ?', whereArgs: [bundleId]);
        if (rows.isEmpty) continue;
        // compute metadata
        final stats = await txn.rawQuery(
          'SELECT MIN(timestamp) AS start, MAX(timestamp) AS end, COUNT(*) AS count FROM sensor_samples WHERE bundle_id = ?',
          [bundleId],
        );
        final rowStats = stats.first;
        final int? startedAt = (rowStats['start'] as int?);
        final int? endedAt = (rowStats['end'] as int?);
        final int sampleCount = (rowStats['count'] as int?) ?? 0;
        final int durationMs = (startedAt != null && endedAt != null) ? endedAt - startedAt : 0;

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
        final [
          timeLabels as List<Map<String, Object?>>,
          crashRecovery as List<Map<String, Object?>>,
          info as ({String deviceModel, String deviceName}),
        ] = await Future.wait([
          txn.query('time_label', where: 'bundle_id = ?', whereArgs: [bundleId]),
          txn.query('crash_recovery', where: 'bundle_id = ?', whereArgs: [bundleId]),
          ControllerUtils.deviceInfoString(),
        ]);

        // finalize json data
        final jsonPath = await FileUtils.saveJsonToFile({
          "created_at": now,
          "timed_label": jsonEncode(timeLabels),
          "crash_recovery": jsonEncode(crashRecovery),
          "samplingPeriod": Config.samplingPeriod.inMilliseconds,
          "device_name": info.deviceName,
          "device_model": info.deviceModel,
          "json": jsonEncode(sanitizedRows),
        }, 'bundle_$now.json');

        await txn.insert('archives', {
          'started_at': startedAt,
          'ended_at': endedAt,
          'duration_ms': durationMs,
          'sample_count': sampleCount,
          'created_at': now,
          'is_archive': 0,
          'path': jsonPath,
          'is_synced': 0,
          'local_available': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        // Clear original samples
        await txn.delete('sensor_samples', where: 'bundle_id = ?', whereArgs: [bundleId]);
        await txn.delete('time_label', where: 'bundle_id = ?', whereArgs: [bundleId]);
        await txn.delete('crash_recovery', where: 'bundle_id = ?', whereArgs: [bundleId]);
      }
    });
  }

  static Future<void> delteArchive(int id) async {
    final db = await _db;
    final rows = await db.query('archives', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final row = rows.first;
    final path = row['path'] as String?;
    // deleting the file
    try {
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      // ignore: empty_catchess
    } catch (e) {
      debugPrint(ColorCode.red('[SensorDbController::deleteArchive]$e', true));
    }
    await db.delete('archives', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<int>> bundleAndZipAllData() async {
    final database = await _db;
    final List<int> archiveIds = [];
    await _bundleAndClearSamples(); // making sure bundles are ready

    var rows = await database.query('archives', where: 'is_archive = ?', whereArgs: [0]);
    if (rows.isNotEmpty) {
      for (final bundle in rows) {
        final zipPath = await FileUtils.moveJsonToZipFile(bundle['path'] as String);
        await database.update(
          'archives',
          {'path': zipPath, 'is_archive': 1},
          where: 'id = ?',
          whereArgs: [bundle['id']],
        );
        archiveIds.add(bundle['id'] as int);
      }
    }
    return archiveIds;
  }

  /// Returns a list of metadata for all archived ZIP files.
  /// Each item contains:
  /// - id: archive ID
  /// - createdAt: timestamp of archive creation
  /// - path: local path to the ZIP
  /// - localAvailable: whether the ZIP file exists locally
  /// - sampleCount, durationMs: optional info for display
  static Future<List<({int id, String startedAt, String path, bool localAvailable, int sampleCount, int durationMs})>>
  getZipMetaData() async {
    final db = await _db;
    // Query all archives where ZIP is ready
    final rows = await db.query('archives', where: 'is_archive = ?', whereArgs: [1], orderBy: 'created_at ASC');
    if (rows.isEmpty) return [];
    // Map results to a clean list for the widget
    final result = <({int id, String startedAt, String path, bool localAvailable, int sampleCount, int durationMs})>[];
    for (final row in rows) {
      final path = row['path'] as String;
      final file = File(path);
      final startedAt = DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int);
      result.add((
        id: row['id'] as int,
        // createdAt: createdAt.toIso8601String(),
        startedAt: DateFormat('MMM d – hh:mm a').format(startedAt),
        path: path,
        localAvailable: file.existsSync(),
        sampleCount: row['sample_count'] as int,
        durationMs: row['duration_ms'] as int,
      ));
    }
    return result;
  }

  static Future<File?> getZipFile(int id) async {
    final database = await _db;
    final row = await database.query('archives', where: 'id = ?', whereArgs: [id]);
    if (row.isEmpty) return null;
    final archivePath = row.first['path'] as String?;
    if (archivePath == null) return null;
    final zipFile = await FileUtils.loadZipFile(archivePath);
    return zipFile;
  }

  /// Get database statistics and bundle table schema (excluding JSON blobs)
  static Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await _db;
    int intValue(List<Map<String, Object?>> r) => (r.first.values.first as int?) ?? 0;
    // ---- Raw pipeline state ----
    final rawSamples = intValue(await db.rawQuery('SELECT COUNT(*) FROM sensor_samples'));
    final pendingJson = intValue(await db.rawQuery('SELECT COUNT(*) FROM archives WHERE is_archive = 0'));
    final zipped = intValue(await db.rawQuery('SELECT COUNT(*) FROM archives WHERE is_archive = 1'));
    final unsynced = intValue(await db.rawQuery('SELECT COUNT(*) FROM archives WHERE is_synced = 0'));
    final totalArchivedSamples = intValue(await db.rawQuery('SELECT COALESCE(SUM(sample_count), 0) FROM archives'));
    // ---- Time diagnostics ----
    final timeStats = await db.rawQuery('SELECT MIN(created_at) as oldest, MAX(created_at) as newest FROM archives');
    final oldest = timeStats.first['oldest'];
    final newest = timeStats.first['newest'];
    // ---- Database size ----
    final dbFile = File(db.path);
    final dbSizeBytes = await dbFile.exists() ? await dbFile.length() : 0;
    // ---- Archive disk usage ----
    final archiveRows = await db.query('archives', columns: ['path'], where: 'local_available = 1');
    int totalArchiveBytes = 0;

    for (final row in archiveRows) {
      final path = row['path'] as String?;
      if (path == null) continue;
      final f = File(path);
      if (await f.exists()) {
        totalArchiveBytes += await f.length();
      }
    }

    return {
      'pipeline': {
        'raw_samples_in_db': rawSamples,
        'json_waiting_for_zip': pendingJson,
        'zipped_archives': zipped,
        'unsynced_archives': unsynced,
        'total_samples_archived_lifetime': totalArchivedSamples,
      },
      'timeline': {'oldest_archive_created_at': oldest, 'newest_archive_created_at': newest},
      'storage': {'database_bytes': dbSizeBytes, 'archives_total_bytes': totalArchiveBytes},
    };
  }
}
