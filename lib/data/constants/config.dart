import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class Config {
  static const String gitUser = 'Holy-Warrior';
  static const String gitRepo = 'auto-silent-gathering';
  static const String gitCurentRelease = "v3.0.0";
  static const bool gitFilterOutPrerelease = true;

  static const Duration samplingPeriod = Duration(milliseconds: 20);
  static const foregroundActionRepeatInterval = 10000; //10 seconds
  static const int executionOffsetMinutes = -10;

  // static const zipArchivePath = "archive.path";

  static Future<String> zipArchivePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, "archive.zip");
  }
  
  static TimeOfDay toExecutionTime(TimeOfDay time) {
    return convertTime(time, executionOffsetMinutes);
  }

  static TimeOfDay convertTime(TimeOfDay time, int offsetMinutes) {
    final totalMinutes = time.hour * 60 + time.minute + offsetMinutes;

    final normalized =
        (totalMinutes % (24 * 60) + (24 * 60)) % (24 * 60);

    final newHour = normalized ~/ 60;
    final newMinute = normalized % 60;

    return TimeOfDay(hour: newHour, minute: newMinute);
  }

}
// class SensorInterval {
//   static const normalInterval = Duration(milliseconds: 200);
//   static const uiInterval = Duration(milliseconds: 66, microseconds: 667);
//   static const gameInterval = Duration(milliseconds: 20);
//   static const fastestInterval = Duration.zero;
// }

// ignore_for_file: constant_identifier_names
class ColorCode {
  // Reset
  static const String reset = '\x1B[0m';

  // Standard foreground colors
  static const String raw_black = '\x1B[30m';
  static const String raw_red = '\x1B[31m';
  static const String raw_green = '\x1B[32m';
  static const String raw_yellow = '\x1B[33m';
  static const String raw_blue = '\x1B[34m';
  static const String raw_magenta = '\x1B[35m';
  static const String raw_cyan = '\x1B[36m';
  static const String raw_white = '\x1B[37m';

  // Default terminal foreground color
  static const String raw_defaultColor = '\x1B[39m';

  // ─────────────────────────────
  // Text helpers
  // ─────────────────────────────

  static String black(String text, bool? resetAtComplete) =>
      '$raw_black$text${resetAtComplete != null && resetAtComplete ? reset : ''}';

  static String red(String text, bool? resetAtComplete) =>
      '$raw_red$text${resetAtComplete != null && resetAtComplete ? reset : ''}';

  static String green(String text, bool? resetAtComplete) =>
      '$raw_green$text${resetAtComplete != null && resetAtComplete ? reset : ''}';

  static String yellow(String text, bool? resetAtComplete) =>
      '$raw_yellow$text${resetAtComplete != null && resetAtComplete ? reset : ''}';

  static String blue(String text, bool? resetAtComplete) =>
      '$raw_blue$text${resetAtComplete != null && resetAtComplete ? reset : ''}';

  static String magenta(String text, bool? resetAtComplete) =>
      '$raw_magenta$text${resetAtComplete != null && resetAtComplete ? reset : ''}';

  static String cyan(String text, bool? resetAtComplete) =>
      '$raw_cyan$text${resetAtComplete != null && resetAtComplete ? reset : ''}';

  static String white(String text, bool? resetAtComplete) =>
      '$raw_white$text${resetAtComplete != null && resetAtComplete ? reset : ''}';

  static String defaultColor(String text, bool? resetAtComplete) =>
      '$raw_defaultColor$text${resetAtComplete != null && resetAtComplete ? reset : ''}';
}
