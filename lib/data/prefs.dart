// lib\data\prefs.dart
// ignore_for_file: unused_element
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/config.dart';
import 'package:motion_test/data/models/sensor_task_state.dart';

class Prefs {
  // ignore: library_private_types_in_public_api, non_constant_identifier_names
  static final _Alarms Alarms = _Alarms._();

  // ignore: library_private_types_in_public_api, non_constant_identifier_names
  static final _SensorTask SensorTask = _SensorTask._();
}

// ─────────────────────────────────────────────────────────────
// 🔒 Alarms Prefs Controller
// ─────────────────────────────────────────────────────────────
class _Alarms {
  const _Alarms._();

  final int alarmBaseId = 1000;
  static const String _key = 'daily_timings';
  static List<List<int>> get defaultTimings => Config.defaultTimings;

  Future<List<List<int>>> getTimings() async {
    final prefs = SharedPreferencesAsync();

    final jsonString = await prefs.getString(_key);
    if (jsonString == null) {
      await prefs.setString(_key, jsonEncode(defaultTimings));
      return Config.defaultTimings;
    }

    final decoded = jsonDecode(jsonString) as List;
    return decoded.map((e) => List<int>.from(e)).toList();
  }

  /// **`updateTimings()` expects exactly 5 timings**
  Future<void> updateTimings(List<List<int>> newTimings) async {
    if (newTimings.length != 5) {
      throw ArgumentError('updateTimings expects exactly 5 timings');
    }

    final prefs = SharedPreferencesAsync();
    await prefs.setString(_key, jsonEncode(newTimings));
  }
}

// ─────────────────────────────────────────────────────────────
// 🔒 Sensor Task State Controller (NOT a Prefs wrapper)
// ─────────────────────────────────────────────────────────────
class _SensorTask {
  const _SensorTask._();

  static const String _key = 'sensor_task_state_snapshot';

  /// Save task state as a single JSON blob
  Future<void> saveState({
    required String label,
    required DateTime plannedStopTime,
    int? bundleId,
  }) async {
    final prefs = SharedPreferencesAsync();

    final payload = {
      'label': label,
      'plannedStopTime': plannedStopTime.millisecondsSinceEpoch,
      if (bundleId != null) 'bundleId': bundleId,
    };

    await prefs.setString(_key, jsonEncode(payload));
  }

  /// Read stored task state.
  /// Returns defaults if nothing exists.
  /// ❗ Does NOT mutate storage.
  Future<SensorTaskState> getStateOrDefaults() async {
    final prefs = SharedPreferencesAsync();
    final jsonString = await prefs.getString(_key);

    if (jsonString == null) {
      return SensorTaskState.defaults();
    }

    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

    return SensorTaskState(
      label: decoded['label'] as String,
      plannedStopTime: DateTime.fromMillisecondsSinceEpoch(
        decoded['plannedStopTime'] as int,
      ),
      bundleId: decoded['bundleId'] as int?,
    );
  }

  /// Explicitly clears any stored task snapshot.
  /// Caller controls consume-once semantics.
  Future<void> clearState() async {
    final prefs = SharedPreferencesAsync();
    await prefs.remove(_key);
  }
}