import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:asg/data/constants/sensor_constants.dart';
import 'package:asg/data/db/models/sensor_sample.dart';
import 'package:asg/services/sensor_foreground_task/sensor_buffer.dart';

class SensorManager {
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSub;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSub;
  StreamSubscription<MagnetometerEvent>? _magnetometerSub;

  late Duration _samplingPeriod;
  late SensorBuffer _buffer;

  /// Subscribe to all sensors
  void subscribeAll({
    required Duration samplingPeriod, // ~60Hz
    required SensorBuffer buffer
  }) {
    _samplingPeriod = samplingPeriod;
    _buffer = buffer;

    // Prevent duplicate subscriptions
    if (_hasActiveSubscriptions) return;

    // Accelerometer
    _accelerometerSub = accelerometerEventStream(
        samplingPeriod: _samplingPeriod).listen((e) {
      _handleSensorData(
        SensorType.accelerometer, e.x, e.y, e.z,
        DateTime.now().millisecondsSinceEpoch
      );
    });
    // User Accelerometer
    _userAccelerometerSub = userAccelerometerEventStream(
        samplingPeriod: _samplingPeriod).listen((e) {
      _handleSensorData(
        SensorType.userAccelerometer, e.x, e.y, e.z,
        DateTime.now().millisecondsSinceEpoch
      );
    });
    // Gyroscope
    _gyroscopeSub = gyroscopeEventStream(
        samplingPeriod: _samplingPeriod).listen((e) {
      _handleSensorData(
        SensorType.gyroscope, e.x, e.y, e.z,
        DateTime.now().millisecondsSinceEpoch
      );
    });
    // Magnetometer
    _magnetometerSub = magnetometerEventStream(
        samplingPeriod: _samplingPeriod).listen((e) {
      _handleSensorData(
        SensorType.magnetometer, e.x, e.y, e.z,
        DateTime.now().millisecondsSinceEpoch
      );
    });

  }

  /// Unsubscribe from all sensors
  Future<void> unsubscribeAll() async {
    await _accelerometerSub?.cancel();
    await _userAccelerometerSub?.cancel();
    await _gyroscopeSub?.cancel();
    await _magnetometerSub?.cancel();

    _accelerometerSub = null;
    _userAccelerometerSub = null;
    _gyroscopeSub = null;
    _magnetometerSub = null;
  }

  bool get _hasActiveSubscriptions =>
      _accelerometerSub != null ||
      _userAccelerometerSub != null ||
      _gyroscopeSub != null ||
      _magnetometerSub != null;

  // ─────────────────────────────
  // Sensor callbacks
  // ─────────────────────────────

  void _handleSensorData(
    int sensorType,   // now integer
    double x,
    double y,
    double z,
    int millisecondsSinceEpoch
  ) {
    double r3(double v) => (v * 1000).round() * 0.001;

    _buffer.add(
      SensorSample(
        timestamp: millisecondsSinceEpoch,
        sensorType: sensorType,
        x: r3(x),
        y: r3(y),
        z: r3(z),
        samplingPeriod: _samplingPeriod.inMilliseconds,
      ),
    );
  }


}
