import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'my_sensor_buffer.dart';
import 'db/model_sensor_sample.dart';
import 'db/my_db_helper.dart';


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

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
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

    await SensorDatabase.bundleAndClearSamples(tag: 'not_set');
  }

}
