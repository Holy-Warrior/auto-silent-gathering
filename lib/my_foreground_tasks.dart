// lib\my_foreground_tasks.dart
import 'dart:io';
// import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'my_sensor_buffer.dart';
import 'db/model_sensor_sample.dart';
import 'db/my_db_helper.dart';
import 'my_alarm_manager.dart';
import 'my_alarm_manager_timings.dart';


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
  channelDescription: 'Service for gathering sensor data on set intervals', onlyAlertOnce: true);
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
    notificationText: 'Recording [Random] Sensor Data',
    callback: startCallback, 
    notificationButtons: [
      NotificationButton(id: 'switch_label', text: 'Switch Label'),
      ]
    );
}

Future<void> closeForegroundService() async {
  FlutterForegroundTask.stopService();
}


@pragma('vm:entry-point')
void startCallback(){
    FlutterForegroundTask.setTaskHandler(SensorTaskHandler());
}

class SensorTaskHandler extends TaskHandler {
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<UserAccelerometerEvent>? _userAccSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  
  SensorBuffer<SensorSample> buffer = SensorBuffer<SensorSample>();
  final _labelRandom = 'Random', _labelNimaz = 'Nimaz';
  String _labelCurrent = 'Random';
  late final int _bundleId;
  bool _bundleIdAquired = false;
  String _currentTag = "not_set";
  late DateTime _currentTime;
  Map<String, int> exceedingTimes = {"notify_loop":40};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    scheduleDailyForegroundRuns();
    final result = await identifyCurrentTagWithTime();
    _currentTag = result.currentTag;
    _currentTime = result.now;
    _bundleId = await SensorDatabase.getNextBundleId();
    _bundleIdAquired = true;
  
    // Subscribe to sensors
    _accSub = accelerometerEventStream(samplingPeriod: SensorInterval.fastestInterval).listen((e) {
      buffer.add(SensorSample(timestamp: DateTime.now().millisecondsSinceEpoch, type: 'ACC', x: e.x, y: e.y, z: e.z, ));});
    _gyroSub = gyroscopeEventStream(samplingPeriod: SensorInterval.fastestInterval).listen((e) {
      buffer.add(SensorSample(timestamp: DateTime.now().millisecondsSinceEpoch, type: 'GYR', x: e.x, y: e.y, z: e.z));});
    _userAccSub = userAccelerometerEventStream(samplingPeriod: SensorInterval.fastestInterval).listen((e) {
      buffer.add(SensorSample(timestamp: DateTime.now().millisecondsSinceEpoch, type: 'UACC', x: e.x, y: e.y, z: e.z));});
    _magSub = magnetometerEventStream(samplingPeriod: SensorInterval.fastestInterval).listen((e) {
      buffer.add(SensorSample(timestamp: DateTime.now().millisecondsSinceEpoch, type: 'MAG', x: e.x, y: e.y, z: e.z));});
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    final batch = await buffer.takeAll();
    if (batch.isNotEmpty) {
      await SensorDatabase.insertBatch(batch, bundleId: _bundleId);
    }

    if (minutesLeft(exceedingTimes['notify_loop']!, _currentTime)<=0){
      closeForegroundService();
    }
  }

  @override
  void onNotificationButtonPressed(String id) async {
    super.onNotificationButtonPressed(id);

    if (id == 'switch_label'){
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      if(!_bundleIdAquired) return;
      if (_labelCurrent == _labelRandom) {_labelCurrent = _labelNimaz;}
      else {_labelCurrent = _labelRandom;}

      await FlutterForegroundTask.updateService(notificationText: 'Recording [$_labelCurrent] Sensor Data');
      await SensorDatabase.insertTimeLabel
      (bundleId: _bundleId, timestamp: timestamp, label: _labelCurrent,);

      if (_labelCurrent== _labelNimaz && minutesLeft(exceedingTimes['notify_loop']!, _currentTime) <= 20){
        exceedingTimes['notify_loop']= 20;
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _accSub?.cancel();
    await _gyroSub?.cancel();
    await _userAccSub?.cancel();
    await _magSub?.cancel();

    final batch = await buffer.takeAll();
    if (batch.isNotEmpty) {
      await SensorDatabase.insertBatch(batch, bundleId: _bundleId);
    }

    await SensorDatabase.bundleAndClearSamples(tag: _currentTag);
  }

}



int minutesLeft(int finishLineMinutes, DateTime currentTime) {
  final DateTime finishLineTime =
      currentTime.add(Duration(minutes: finishLineMinutes));

  final Duration remaining =
      finishLineTime.difference(DateTime.now());

  if (remaining.isNegative) {
    return 0;
  }

  return remaining.inMinutes;
}




Future<({String currentTag, DateTime now})> identifyCurrentTagWithTime() async {
  final List<String> tags = ['Fajar', 'Zuhar', 'Asar', 'Magrib', 'Isha'];
  final List<List<int>> timings =
      await MyAlarmManagerData.dailyTimings();

  final DateTime now = DateTime.now();
  final int nowMinutes = now.hour * 60 + now.minute;

  final timingMinutes = timings
      .map((t) => t[0] * 60 + t[1])
      .toList();

  int selectedIndex = -1;

  for (int i = 0; i < timingMinutes.length; i++) {
    if (timingMinutes[i] <= nowMinutes) {
      selectedIndex = i;
    } else {
      break;
    }
  }

  if (selectedIndex == -1) {
    selectedIndex = timingMinutes.length - 1;
  }

  return (
    currentTag: tags[selectedIndex],
    now: now,
  );
}

