// lib\my_sensor_buffer.dart
import 'dart:async';
import 'db/model_sensor_sample.dart';

/// High-frequency safe sensor buffer using atomic swap.
class SensorBuffer<T extends SensorSample> {
  List<T> _buffer = [];

  SensorBuffer();

  /// Add sensor data (FIFO order preserved)
  void add(T item) {
    _buffer.add(item);
  }

  /// Atomically take all current data and clear the buffer.
  /// Waits a short delay before returning to ensure old references are not used.
  Future<List<T>> takeAll({Duration delay = const Duration(milliseconds: 50)}) async {
    final oldBuffer = _buffer;
    _buffer = <T>[]; // atomic swap

    // Wait a tiny cooldown to let any lingering references finish
    await Future.delayed(delay);

    return oldBuffer;
  }

  /// Peek current buffer size
  int get size => _buffer.length;

  /// Check if buffer is empty
  bool get isEmpty => _buffer.isEmpty;
}
