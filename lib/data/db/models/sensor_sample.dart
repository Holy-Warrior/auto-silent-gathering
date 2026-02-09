class SensorSample {
  final int timestamp;        // unix millis
  final int sensorType;       // changed from String to int
  final int samplingPeriod;
  final double x, y, z;

  SensorSample({
    required this.timestamp,
    required this.sensorType,
    required this.x,
    required this.y,
    required this.z,
    required this.samplingPeriod,
  });
}
