import 'package:asg/data/constants/config.dart';
import 'package:asg/data/db/helper/db_init_instance.dart';
import 'package:asg/data/hive.dart';
import 'package:asg/data/supabase/controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startDataSyncTask() async {
  await Config.initilizeAllMainEntry();
  FlutterForegroundTask.setTaskHandler(DataSyncTaskHandler());
}

class DataSyncTaskHandler extends TaskHandler {
  void _debugLog(String message) {
    debugPrint(ColorCode.cyan('[DataSyncTaskHandler] $message', true));
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _debugLog('Starting Data Sync Task...');
    final currentArchiveUploadId = await StateBox.instance.currentUploadArchiveId(null);

    if (currentArchiveUploadId == null) {
      _debugLog('No current archive upload ID found. Exiting task.');
      await FlutterForegroundTask.stopService();
      return;
    }

    final db = await DBInit.instance.database;
    final result = await db.query('archives', where: 'id = ?', whereArgs: [currentArchiveUploadId]);
    if (result.isEmpty) {
      _debugLog('Archive with ID $currentArchiveUploadId not found in database. Exiting task.');
      await FlutterForegroundTask.stopService();
      return;
    }
    final archive = result.first;
    final id = archive['id'] as int;
    try {
      _debugLog('Processing archive ID: $id');
      await SupabaseController.uploadArchive(id).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _debugLog('Upload for archive ID $id timed out.');
          throw Exception('Upload exceeded 5 minutes timeout.');
        },
      );
      _debugLog('Successfully processed archive ID: $id');
    } catch (e) {
      _debugLog('Error processing archive ID $id: $e');
    }

    _debugLog('Data Sync Task Completed.');
    FlutterForegroundTask.stopService();
  }
}

void configureForegroundTaskOptions() {
  // Android Notification Options (Silent)
  final androidNotificationOptions = AndroidNotificationOptions(
    channelId: 'data_upload_service',
    channelName: 'Data Upload Service',
    channelDescription: 'Service for uploading sensor data to server',

    // Make it silent
    channelImportance: NotificationChannelImportance.LOW,
    priority: NotificationPriority.LOW,
    enableVibration: false,
    playSound: false,
    onlyAlertOnce: true,
    showWhen: false,
  );

  // iOS Notification Options (Already Silent)
  final iosNotificationOptions = IOSNotificationOptions(showNotification: false, playSound: false);

  final foregroundTaskOptions = ForegroundTaskOptions(
    eventAction: ForegroundTaskEventAction.repeat(0),
    autoRunOnBoot: false,
    autoRunOnMyPackageReplaced: false,
    allowWakeLock: true,
    allowWifiLock: true,
  );

  FlutterForegroundTask.init(
    androidNotificationOptions: androidNotificationOptions,
    iosNotificationOptions: iosNotificationOptions,
    foregroundTaskOptions: foregroundTaskOptions,
  );
}
