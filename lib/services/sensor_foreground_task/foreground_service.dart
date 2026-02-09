import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'task_handler.dart';
import "package:asg/data/constants/config.dart";



/// Initializes and starts the foreground service using `FlutterForegroundTask`.
///
/// ### Configuration
/// - Defines `AndroidNotificationOptions`:
///   - Uses channel ID `sensor_foreground_service`
///   - Sets `NotificationChannelImportance.HIGH` and `NotificationPriority.HIGH`
///   - Enables repeated alerts via `onlyAlertOnce: false`
///
/// - Defines `IOSNotificationOptions`:
///   - Disables notification display with `showNotification: false`
///   - Disables sound using `playSound: false`
///
/// - Defines `ForegroundTaskOptions`:
///   - Executes repeatedly using `ForegroundTaskEventAction.repeat(10000)`
///   - Disables auto-start on boot and package replacement
///   - Enables `allowWakeLock` for background execution
///
/// ### Initialization
/// - Calls `FlutterForegroundTask.init()` with the configured options
///
/// ### Service Start
/// - Starts the foreground service via `FlutterForegroundTask.startService()`
/// - Displays a persistent notification with:
///   - `notificationTitle` and `notificationText`
///   - A callback entry point `startSensorTaskCallback`
///   - A notification action button (`NotificationButton`)
///
/// Call this method after permissions are granted and before
/// background sensor collection is required.
Future<void> initForegroundService() async {
  // Foreground Notification Options
  AndroidNotificationOptions androidNotificationOptions = AndroidNotificationOptions
  (channelId: 'sensor_foreground_service', channelName: 'Sensor Service', 
  channelDescription: 'Service for gathering sensor data on set intervals', onlyAlertOnce: false, channelImportance: NotificationChannelImportance.HIGH, priority: NotificationPriority.HIGH);
  IOSNotificationOptions iosNotificationOptions = IOSNotificationOptions
  (showNotification: false, playSound: false);
  ForegroundTaskOptions foregroundTaskOptions = ForegroundTaskOptions
  (eventAction: ForegroundTaskEventAction.repeat(
    Config.foregroundActionRepeatInterval),
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
    notificationText: 'Starting Recording Session...',
    callback: startSensorTaskCallback, 
    );
}

/// Stops the currently running foreground service.
///
/// - Terminates the service started via `FlutterForegroundTask.startService()`
/// - Removes the persistent foreground notification
///
/// Call this method when foreground execution is no longer required.
Future<void> closeForegroundService() async {
  FlutterForegroundTask.stopService();
}
