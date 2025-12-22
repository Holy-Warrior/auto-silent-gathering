// lib\services\foreground\foreground_service.dart
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'sensor_task_handler/sensor_task_handler.dart';


Future<void> askForegroundTaskPermissions() async {
  final NotificationPermission notificationPermission =
      await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }

  if (Platform.isAndroid) {
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    if (!await FlutterForegroundTask.canScheduleExactAlarms) {
      await FlutterForegroundTask.openAlarmsAndRemindersSettings();
    }
  }
}


Future<void> initForegroundService() async {
  // Foreground Notification Options
  AndroidNotificationOptions androidNotificationOptions = AndroidNotificationOptions
  (channelId: 'sensor_foreground_service', channelName: 'Sensor Service', 
  channelDescription: 'Service for gathering sensor data on set intervals', onlyAlertOnce: false, channelImportance: NotificationChannelImportance.HIGH, priority: NotificationPriority.HIGH);
  IOSNotificationOptions iosNotificationOptions = IOSNotificationOptions
  (showNotification: false, playSound: false);
  ForegroundTaskOptions foregroundTaskOptions = ForegroundTaskOptions
  (eventAction: ForegroundTaskEventAction.repeat(10000), // 10 seconds
  autoRunOnBoot: false, autoRunOnMyPackageReplaced: false,
  allowWakeLock: true, allowWifiLock: false);

  // Foreground Notification itself
  FlutterForegroundTask.init(
    androidNotificationOptions: androidNotificationOptions, 
    iosNotificationOptions: iosNotificationOptions, 
    foregroundTaskOptions: foregroundTaskOptions
  );

  // Now start the Foreground Task
  FlutterForegroundTask.startService(
    notificationTitle: 'Sensor Service', 
    notificationText: 'Recording Sensor Data',
    callback: startCallback, 
    notificationButtons: [
      NotificationButton(id: 'switch_label', text: 'Change Label'),
      ]
    );
}

Future<void> closeForegroundService() async {
  FlutterForegroundTask.stopService();
}








