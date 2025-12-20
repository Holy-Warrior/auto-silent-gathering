// lib\data\models\sensor_sample.dart
class SensorSample {
  final int timestamp; // unix millis
  final String type;
  final double x, y, z;

  SensorSample({
    required this.timestamp,
    required this.type,
    required this.x,
    required this.y,
    required this.z,
  });
}
