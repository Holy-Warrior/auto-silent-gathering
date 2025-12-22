// lib\data\models\sensor_sample.dart
class SensorSample {
  final int timestamp; // unix millis
  final String type, samplingRate;
  final double x, y, z;

  SensorSample({
    required this.timestamp,
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    required this.samplingRate
  });
}
class SamplingRates {
  static const fastest = 'fastest';
  static const game = 'game';
}
class SensorType {
  static const String 
    accelerometer = 'ACC',
    gyroscope = 'GYR',
    userAccelerometer = 'UACC',
    magnetometer = 'MAG';
}