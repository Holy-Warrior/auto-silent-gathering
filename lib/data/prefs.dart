<<<<<<< HEAD
// lib\data\prefs.dart
=======
>>>>>>> 05df9a8784000fe5cd4c6effe305385eb36d8d54
// ignore_for_file: unused_element
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/config.dart';

class Prefs {
  // ignore: library_private_types_in_public_api, non_constant_identifier_names
  static final _Alarms Alarms = _Alarms._();
  
}

// 🔒 Private to this file only
class _Alarms {
  const _Alarms._();

  final int alarmBaseId = 1000;
  static const String _key = 'daily_timings';
  static List<List<int>> get defaultTimings => Config.defaultTimings;

  Future<List<List<int>>> getTimings() async {
    final prefs = SharedPreferencesAsync();
    
    final jsonString = await prefs.getString(_key);   // fetching values
    if (jsonString == null) {                         // if not found, saving and returning defaults
      await prefs.setString(_key, jsonEncode(defaultTimings));
      return Config.defaultTimings; 
    }
    final decoded = jsonDecode(jsonString) as List;   // if found, returning found
    return decoded.map((e) => List<int>.from(e)).toList();
  }

/// **`updateTimings()` expects exactly 5 timings**
  Future<void> updateTimings(List<List<int>> newTimings) async {
    if (newTimings.length != 5) throw ArgumentError('updateTimings expects exactly 5 timings');
    
    final prefs = SharedPreferencesAsync();
    final jsonString = jsonEncode(newTimings);
    await prefs.setString(_key, jsonString);
  }
}
