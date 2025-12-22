// lib/services/foreground/sensor_task_handler/_sub_functions.dart
import 'package:motion_test/data/prefs.dart';
import 'package:motion_test/data/models/sensor_sample.dart';
import 'dart:async';
import 'sensor_buffer.dart';
import 'package:sensors_plus/sensors_plus.dart';

Future<({String currentTag, DateTime startTime})>
identifyCurrentTagWithTime() async {
  final List<String> tags = ['Fajar', 'Zuhar', 'Asar', 'Magrib', 'Isha'];
  final List<List<int>> timings = await Prefs.Alarms.getTimings();

  final DateTime startTime = DateTime.now();
  final int nowMinutes = startTime.hour * 60 + startTime.minute;
  final timingMinutes = timings.map((t) => t[0] * 60 + t[1]).toList();

  int selectedIndex = -1;
  for (int i = 0; i < timingMinutes.length; i++) {
    if (timingMinutes[i] <= nowMinutes) {
      selectedIndex = i;
    } else {
      break;
    }
  }

  if (selectedIndex == -1) selectedIndex = timingMinutes.length - 1;

  return (currentTag: tags[selectedIndex], startTime: startTime);
}

Future<int> minutesUntilNextNimaz() async {
  final timings = await Prefs.Alarms.getTimings();
  final now = DateTime.now();
  final nowMinutes = now.hour * 60 + now.minute;

  for (final t in timings) {
    final m = t[0] * 60 + t[1];
    if (m > nowMinutes) return m - nowMinutes;
  }

  // wrap to tomorrow
  final first = timings.first;
  return (24 * 60 - nowMinutes) + (first[0] * 60 + first[1]);
}

int minutesLeft(int finishLineMinutes, DateTime startTime) {
  final DateTime finishLineTime = startTime.add(
    Duration(minutes: finishLineMinutes),
  );
  final Duration remaining = finishLineTime.difference(DateTime.now());
  return remaining.isNegative ? 0 : remaining.inMinutes;
}

// Generic triple-axis sensor binding
StreamSubscription bindTripleAxis<T>({
  required Stream<T> stream,
  required SensorBuffer<SensorSample> buffer,
  required String sensorType,
  required String samplingRate,
  required double Function(T) x,
  required double Function(T) y,
  required double Function(T) z,
}) {
  return stream.listen((e) {
    buffer.add(
      SensorSample(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: sensorType,
        samplingRate: samplingRate,
        x: x(e),
        y: y(e),
        z: z(e),
      ),
    );
  });
}

// Subscribe to all sensors at selected rates
Future<Map<String, Map<String, StreamSubscription>>> subscribeToAllSensors(
    SensorBuffer<SensorSample> buffer,
) async {
  final Map<String, Map<String, StreamSubscription>> subs = {};

  // Small helper to bind triple-axis streams
  StreamSubscription sub(
    String type,
    String rate,
    Stream stream,
    double Function(dynamic) x,
    double Function(dynamic) y,
    double Function(dynamic) z,
  ) =>
      bindTripleAxis(
        stream: stream,
        buffer: buffer,
        sensorType: type,
        samplingRate: rate,
        x: x,
        y: y,
        z: z,
      );

  // Only keep the two effective rates
  final Map<String, Duration> rateIntervals = {
    SamplingRates.fastest: SensorInterval.fastestInterval,
    SamplingRates.game: SensorInterval.gameInterval,
  };

  // Generate subscriptions for one sensor
  Map<String, StreamSubscription> generateSubs(
    String sensorType,
    Stream Function({Duration samplingPeriod}) streamFunc,
  ) {
    return {
      for (final rate in rateIntervals.keys)
        rate: sub(
          sensorType,
          rate,
          streamFunc(samplingPeriod: rateIntervals[rate]!),
          (e) => e.x,
          (e) => e.y,
          (e) => e.z,
        ),
    };
  }

  // Apply to all sensors
  subs[SensorType.accelerometer] =
      generateSubs(SensorType.accelerometer, accelerometerEventStream);
  subs[SensorType.gyroscope] =
      generateSubs(SensorType.gyroscope, gyroscopeEventStream);
  subs[SensorType.userAccelerometer] =
      generateSubs(SensorType.userAccelerometer, userAccelerometerEventStream);
  subs[SensorType.magnetometer] =
      generateSubs(SensorType.magnetometer, magnetometerEventStream);

  return subs;
}

// Cancel all subscriptions
Future<void> cancelAllSubscriptions(
  Map<String, Map<String, StreamSubscription>> subscriptions,
) async {
  for (final sensorMap in subscriptions.values) {
    for (final sub in sensorMap.values) {
      await sub.cancel();
    }
  }
}
