// lib\my_alarm_manager_timings.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MyAlarmManagerData {

  // Varibales
  static int alarmBaseId = 1000;
  static const List<List<int>> _defaultTimings = [
    [6, 5], // [hour, minute]
    [13, 15],
    [15, 45],
    [16, 58],
    [19, 0],
  ];
  static const String _key = 'daily_timings';

  // static Future<List<List<int>>> dailyTimings() async { return _defaultTimings;}
  static Future<List<List<int>>> dailyTimings() async {
    final prefs = SharedPreferencesAsync();

    // fetching values
    final jsonString = await prefs.getString(_key);
    if (jsonString == null) { // if not found, saving and returning defaults
      await prefs.setString(_key, jsonEncode(_defaultTimings));
      return _defaultTimings; 
    }
    // if found, returning found
    final decoded = jsonDecode(jsonString) as List;
    return decoded
        .map((e) => List<int>.from(e))
        .toList();
  }

  static Future<void> dailyTimingsModify
  (List<List<int>> newTimings) async {

    if (newTimings.length != 5) throw ArgumentError('dailyTimingsModify expects exactly 5 timings');
    
    final prefs = SharedPreferencesAsync();
    final jsonString = jsonEncode(newTimings);
    await prefs.setString(_key, jsonString);
  }
}