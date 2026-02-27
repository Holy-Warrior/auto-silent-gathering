import 'dart:io';
import 'package:asg/data/constants/config.dart';
import 'package:asg/data/db/helper/db_init_instance.dart';
import 'package:asg/data/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:asg/data/db/controllers/utils.dart';

class SupabaseController {
  static void _debugLog(String message) {
    debugPrint(ColorCode.cyan('[SupabaseController] $message', true));
  }

  static Future<void> uploadArchive(int id) async {
    final db = await DBInit.instance.database;

    String codename;
    codename = await StateBox.instance.getDeviceCodename();
    if (kDebugMode) codename = 'DEBUG';

    final archives = await db.query('archives', where: 'id = ?', whereArgs: [id]);
    final archive = archives.first;
    final file = File(archive['path'] as String);

    final supabase = Supabase.instance.client;
    final info = await ControllerUtils.deviceInfoString();
    final zipName = '${codename}_${info.deviceName}_${info.deviceModel}_${DateTime.now().millisecondsSinceEpoch}.zip';

    _debugLog('Uploading archive with ID: $id, file path: ${file.path}, zip name: $zipName');
    // Upload the file
    await supabase.storage.from('archives').upload(zipName, file);
    _debugLog('File uploaded successfully: $zipName');
    _debugLog('File URL: ${supabase.storage.from('archives').getPublicUrl(zipName)}');
    // Insert metadata row
    _debugLog('Inserting metadata for archive ID: $id');
    await supabase.from('archives').insert({
      'started_at': archive['started_at'] as int,
      'ended_at': archive['ended_at'] as int,
      'duration_ms': archive['duration_ms'] as int,
      'sample_count': archive['sample_count'] as int,
      'created_at': archive['created_at'] as int,
      'storage_path': zipName,
    });
    _debugLog('Metadata row inserted for archive ID: $id');

    await onArchiveSynced(archive['id'] as int);
  }

  static Future<void> onArchiveSynced(int archiveId) async {
    final db = await DBInit.instance.database;
    final result = await db.query('archives', where: 'id = ?', whereArgs: [archiveId]);
    final path = result.first['path'];
    // Delete the local file
    _debugLog('Deleting local file: $path');
    final file = File(path as String);
    if (await file.exists()) {
      await file.delete();
    }
    // Update the database
    _debugLog('Updating database for archive ID: $archiveId');
    await db.update('archives', {'is_synced': 1, 'local_available': 0}, where: 'id = ?', whereArgs: [archiveId]);
  }
}

