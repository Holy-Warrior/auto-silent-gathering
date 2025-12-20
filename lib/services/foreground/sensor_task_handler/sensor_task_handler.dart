import 'dart:async';
import 'package:motion_test/data/models/sensor_sample.dart';
import 'package:motion_test/data/db/sensor_database.dart';
import 'package:motion_test/services/alarm_manager.dart';
import 'sensor_buffer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '_sub_functions.dart';

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
    _accSub = accelerometerEventStream(samplingPeriod: SensorInterval.fastestInterval)
            .listen((e) { buffer.add(SensorSample(timestamp: DateTime.now()
            .millisecondsSinceEpoch, type: 'ACC', x: e.x, y: e.y, z: e.z, ));});
    _gyroSub = gyroscopeEventStream(samplingPeriod: SensorInterval.fastestInterval)
            .listen((e) { buffer.add(SensorSample(timestamp: DateTime.now()
            .millisecondsSinceEpoch, type: 'GYR', x: e.x, y: e.y, z: e.z));});
    _userAccSub = userAccelerometerEventStream(samplingPeriod: SensorInterval.fastestInterval)
            .listen((e) { buffer.add(SensorSample(timestamp: DateTime.now()
            .millisecondsSinceEpoch, type: 'UACC', x: e.x, y: e.y, z: e.z));});
    _magSub = magnetometerEventStream(samplingPeriod: SensorInterval.fastestInterval)
            .listen((e) { buffer.add(SensorSample(timestamp: DateTime.now()
            .millisecondsSinceEpoch, type: 'MAG', x: e.x, y: e.y, z: e.z));});
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    final batch = await buffer.takeAll();
    if (batch.isNotEmpty) await SensorDatabase.insertBatch(batch, bundleId: _bundleId);

    if (minutesLeft(exceedingTimes['notify_loop']!, _currentTime) <=0 ) {
      FlutterForegroundTask.stopService();
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

