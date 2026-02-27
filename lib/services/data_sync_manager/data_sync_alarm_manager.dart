import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:asg/data/constants/config.dart';
import 'package:asg/data/hive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'data_sync_task_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

void dPrint(String message) {
  debugPrint(ColorCode.magenta('[DataSyncAlarmManager] $message', true));
}

Future<bool> hasInternet() async {
  final connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) return false;
  return await InternetConnectionChecker().hasConnection;
}

@pragma('vm:entry-point')
void _alarmCallback(int alarmId, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  dPrint(ColorCode.green('Alarm triggered with ID: $alarmId', true));
  final archiveId = params['archiveId'] as int?;
  if (archiveId == null) {
    dPrint('No archiveId provided in alarm callback params');
    return;
  }
  dPrint('Alarm triggered for archive ID: $archiveId');

  if (!await hasInternet()) {
    dPrint('No internet connection. Rescheduling alarm for archive ID: $archiveId');
    await DataSyncAlarmManagerService.scheduleArchiveUploadTask(archiveId);
    return;
  }

  dPrint('Checking if service is running...');
  // Confirming i can safley start a foreground task here, if not, reschedule for the next suitable time
  if (await FlutterForegroundTask.isRunningService) {
    await DataSyncAlarmManagerService.scheduleArchiveUploadTask(archiveId);
    dPrint('Service is already running. Rescheduling alarm for archive ID: $archiveId');
    return;
  }

  // same here
  dPrint('Checking schedules...');
  final schedules = await StateBox.instance.getSchedules();
  for (final entry in schedules.entries) {
    if (entry.value['enabled'] == true) {
      final timeStr = entry.value['time'] as String?;
      if (timeStr == null) continue;

      final parts = timeStr.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final originalTime = TimeOfDay(hour: hour, minute: minute);
      final executionTime = Config.toExecutionTime(originalTime);
      final now = DateTime.now();
      var scheduled = DateTime(now.year, now.month, now.day, executionTime.hour, executionTime.minute);
      final offset = scheduled.subtract(const Duration(minutes: 15));
      if (scheduled.isBefore(now) || now.isBefore(offset)) {
      } else {
        await DataSyncAlarmManagerService.scheduleArchiveUploadTask(archiveId);
        dPrint('Rescheduling alarm for archive ID: $archiveId at $scheduled because of alarm schedule overlap');
        return;
      }
    }
  }

  dPrint('Passing id $archiveId to Uploader Service');
  // If we reach here, it means it's a good time to start the upload task
  await StateBox.instance.currentUploadArchiveId(archiveId);
  configureForegroundTaskOptions();
  dPrint('Starting data sync task...');
  await FlutterForegroundTask.startService(
    notificationTitle: 'Uploading data...',
    notificationText: 'Your sensor data is being uploaded to the server.',
    callback: startDataSyncTask,
  );
  dPrint('Alarm callback completed.');
}

class DataSyncAlarmManagerService {
  /// Generate a unique alarm ID based on the schedule key
  static int _alarmIdFor(int key) => "data upload task: $key".hashCode & 0x7fffffff;

  static Future<void> scheduleArchiveUploadTask(int archiveId) async {
    final now = DateTime.now();
    final alarmId = _alarmIdFor(archiveId);
    DateTime scheduled = now.add(Duration(minutes: 15));
    await AndroidAlarmManager.oneShotAt(
      scheduled,
      alarmId,
      _alarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
      alarmClock: true,
      params: {"archiveId": archiveId},
    );
    debugPrint(ColorCode.cyan('Scheduled alarm: $alarmId at $scheduled', true));
  }

  static Future<void> scheduleArchiveUploadTasks(List<int> archiveIds) async {
    DateTime scheduled = DateTime.now();

    for (final archiveId in archiveIds) {
      final alarmId = _alarmIdFor(archiveId);
      // schedule the task to run after 1 hour
      scheduled = scheduled.add(Duration(minutes: 15));
      await AndroidAlarmManager.oneShotAt(
        scheduled,
        alarmId,
        _alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
        alarmClock: true,
        params: {"archiveId": archiveId},
      );
      debugPrint(ColorCode.cyan('Scheduled alarm: $alarmId at $scheduled', true));
    }
  }

  static Future<void> cancelArchiveUploadTask(int archiveId) async {
    final alarmId = _alarmIdFor(archiveId);
    await AndroidAlarmManager.cancel(alarmId);
    debugPrint(ColorCode.cyan('Cancelled alarm: $alarmId', true));
  }
}
