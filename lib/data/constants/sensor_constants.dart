class SensorType {
  static const int accelerometer = 1;
  static const int userAccelerometer = 2;
  static const int gyroscope = 3;
  static const int magnetometer = 4;

  static const Map<int, String> toName = {
    1: 'ACC',
    2: 'UACC',
    3: 'GYR',
    4: 'MAG',
  };
}
