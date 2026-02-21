import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileUtils {
  /// Create a ZIP archive containing a single JSON file
  /// Returns the path of the created ZIP file
  static Future<String> moveJsonToZipFile(String jsonPath, {String? zipPath}) async {
    final jsonFile = File(jsonPath);
    if (!await jsonFile.exists()) {
      throw Exception("JSON file does not exist: $jsonPath");
    }
    if (zipPath == null) {
      // Compute ZIP file path in the same directory
      final dir = p.dirname(jsonPath);
      final baseName = p.basenameWithoutExtension(jsonPath);
      zipPath = p.join(dir, '$baseName.zip');
    }
    final jsonBytes = await jsonFile.readAsBytes(); // Read JSON bytes
    final archive =
        Archive() // Create archive
          ..addFile(ArchiveFile(p.basename(jsonPath), jsonBytes.length, jsonBytes));
    // Encode and write ZIP
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive)!;
    await File(zipPath).writeAsBytes(zipData, flush: true);
    await jsonFile.delete(); // Delete original JSON
    return zipPath;
  }

  static Future<File?> loadZipFile(String path) async {
    try {
      final file = File(path);
      return await file.exists() ? file : null;
    } catch (e) {
      return null;
    }
  }

  /// Create a ZIP archive containing multiple JSON files
  /// Returns the path of the created ZIP file
  static Future<String> saveJsonToFile(dynamic jsonData, String fileName) async {
    try {
      final String jsonString = jsonEncode(jsonData); // Convert JSON map to string
      final Directory directory = await getApplicationDocumentsDirectory(); // Get the application documents directory
      final String filePath = '${directory.path}/$fileName'; // Create the file path
      final File file = File(filePath); // Create and write to file
      await file.writeAsString(jsonString);
      return filePath;
    } catch (e) {
      throw Exception('Failed to save JSON file: $e');
    }
  }
}
