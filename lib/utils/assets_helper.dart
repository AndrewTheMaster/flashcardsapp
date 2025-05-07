import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'log_interceptor.dart';

/// Helper class for managing assets in the app
class AssetsHelper {
  /// Check if a file exists in the local directory
  static Future<bool> fileExists(String filename) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/$filename';
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      LogInterceptor.error('Error checking if file exists: $e');
      return false;
    }
  }

  /// Get the local path for a file
  static Future<String> getLocalFilePath(String filename) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}/$filename';
    } catch (e) {
      LogInterceptor.error('Error getting local file path: $e');
      throw Exception('Error getting local file path: $e');
    }
  }

  /// Copy an asset file to the local directory
  static Future<File?> copyAssetToLocal(String assetPath, String localFilename) async {
    try {
      LogInterceptor.log('Copying asset $assetPath to local file $localFilename');
      
      // Get application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/$localFilename';
      final file = File(filePath);

      // Check if file already exists
      if (await file.exists()) {
        LogInterceptor.log('File already exists, not copying');
        return file;
      }

      // Load asset
      final ByteData data;
      try {
        data = await rootBundle.load(assetPath);
      } catch (e) {
        LogInterceptor.error('Error loading asset $assetPath: $e');
        return null;
      }

      // Write to file
      await file.writeAsBytes(data.buffer.asUint8List());
      LogInterceptor.log('Asset copied successfully');
      return file;
    } catch (e) {
      LogInterceptor.error('Error copying asset to local: $e');
      return null;
    }
  }
  
  /// Load a text file as string
  static Future<String?> loadTextFile(String path, {bool fromAssets = true}) async {
    try {
      if (fromAssets) {
        // Load from assets
        return await rootBundle.loadString(path);
      } else {
        // Load from local file
        final file = File(path);
        if (await file.exists()) {
          return await file.readAsString();
        } else {
          LogInterceptor.error('File not found: $path');
          return null;
        }
      }
    } catch (e) {
      LogInterceptor.error('Error loading text file: $e');
      return null;
    }
  }
  
  /// Load a JSON file and parse it
  static Future<Map<String, dynamic>?> loadJsonFile(String path, {bool fromAssets = true}) async {
    try {
      final String? content = await loadTextFile(path, fromAssets: fromAssets);
      if (content == null) return null;
      
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      LogInterceptor.error('Error loading JSON file: $e');
      return null;
    }
  }
  
  /// Convert a binary file to JSON and save it
  static Future<Map<String, dynamic>?> convertBinaryToJson(
    String binaryPath, 
    String jsonFileName,
    {bool overwrite = false}
  ) async {
    try {
      // Check if JSON file already exists
      final jsonPath = await getLocalFilePath(jsonFileName);
      final jsonFile = File(jsonPath);
      
      if (await jsonFile.exists() && !overwrite) {
        LogInterceptor.log('JSON file already exists, loading it');
        final content = await jsonFile.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
      
      // Load binary file
      final binaryFile = File(binaryPath);
      if (!await binaryFile.exists()) {
        LogInterceptor.error('Binary file not found: $binaryPath');
        return null;
      }
      
      // Try to read as text first
      try {
        final String content = await binaryFile.readAsString();
        
        // Try to parse as JSON
        try {
          final jsonData = jsonDecode(content) as Map<String, dynamic>;
          
          // Save JSON to file
          await jsonFile.writeAsString(jsonEncode(jsonData));
          
          LogInterceptor.log('Binary file successfully converted to JSON');
          return jsonData;
        } catch (e) {
          // Not valid JSON, try to create a simple structure
          LogInterceptor.log('Binary file is not valid JSON, creating simple structure');
          
          // For word frequency files or similar
          final lines = content.split('\n');
          final Map<String, dynamic> result = {};
          
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.isNotEmpty) {
              result[line] = 1.0;
            }
          }
          
          // Save JSON to file
          await jsonFile.writeAsString(jsonEncode(result));
          
          LogInterceptor.log('Created simple JSON structure from binary');
          return result;
        }
      } catch (e) {
        // Not a text file, must be actual binary
        LogInterceptor.error('File is true binary, cannot convert: $e');
        return null;
      }
    } catch (e) {
      LogInterceptor.error('Error converting binary to JSON: $e');
      return null;
    }
  }
  
  /// Get the size of a file
  static Future<int> getFileSize(String path, {bool fromAssets = true}) async {
    try {
      if (fromAssets) {
        // Get size from assets
        final ByteData data = await rootBundle.load(path);
        return data.lengthInBytes;
      } else {
        // Get size from local file
        final file = File(path);
        if (await file.exists()) {
          return await file.length();
        } else {
          LogInterceptor.error('File not found: $path');
          return 0;
        }
      }
    } catch (e) {
      LogInterceptor.error('Error getting file size: $e');
      return 0;
    }
  }
  
  /// Check if a directory exists in the app's documents directory
  static Future<bool> directoryExists(String dirName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dirPath = '${appDir.path}/$dirName';
      final dir = Directory(dirPath);
      return await dir.exists();
    } catch (e) {
      LogInterceptor.error('Error checking if directory exists: $e');
      return false;
    }
  }
  
  /// Create a directory in the app's documents directory
  static Future<Directory?> createDirectory(String dirName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dirPath = '${appDir.path}/$dirName';
      final dir = Directory(dirPath);
      
      if (await dir.exists()) {
        return dir;
      }
      
      return await dir.create(recursive: true);
    } catch (e) {
      LogInterceptor.error('Error creating directory: $e');
      return null;
    }
  }
  
  /// List files in a directory
  static Future<List<FileSystemEntity>> listDirectory(String dirName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dirPath = '${appDir.path}/$dirName';
      final dir = Directory(dirPath);
      
      if (!await dir.exists()) {
        LogInterceptor.error('Directory does not exist: $dirName');
        return [];
      }
      
      return dir.listSync();
    } catch (e) {
      LogInterceptor.error('Error listing directory: $e');
      return [];
    }
  }
} 