import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:asg/data/constants/config.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ControllerUtils {
  /// Verify or make a zip archive
  /// Append a json file to existing zip and remove it from original source
  static Future<void> addJsonToArchive(String jsonFilePath) async {
    final zipPath = await Config.zipArchivePath();
    final jsonFile = File(jsonFilePath);

    if (!await jsonFile.exists()) return;

    Archive archive;

    // Load or create archive
    if (await File(zipPath).exists()) {
      final bytes = await File(zipPath).readAsBytes();
      archive = ZipDecoder().decodeBytes(bytes);
    } else {
      archive = Archive();
    }

    final fileName = p.basename(jsonFilePath);
    final fileBytes = await jsonFile.readAsBytes();

    archive.addFile(ArchiveFile(fileName, fileBytes.length, fileBytes));

    // Write zip back
    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive)!;
    await File(zipPath).writeAsBytes(zipData, flush: true);

    // Remove original JSON (move semantics)
    await jsonFile.delete();
  }

  /// Get device info
  static Future<({String deviceName, String deviceModel})>
  deviceInfoString() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceName = 'Unknown';
    String deviceModel = 'Unknown';

    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceName = info.device;
        deviceModel = info.model;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceName = info.name;
        deviceModel = info.model;
      }
    } catch (_) {}

    return (deviceName: deviceName, deviceModel: deviceModel);
  }
}
