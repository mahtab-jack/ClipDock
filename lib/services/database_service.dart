import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/clip_item.dart';
import '../models/dock_settings.dart';

class DatabaseService {
  static const String _dbFileName = 'cnote.db';
  static const String _settingsFileName = 'settings.json';
  static File? _dbFile;
  static File? _settingsFile;

  static Future<Directory> getStorageDirectory() async {
    Directory directory;
    if (!kIsWeb && Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      final localAppData = Platform.environment['LOCALAPPDATA'];
      final userProfile = Platform.environment['USERPROFILE'];

      final basePath = appData ?? localAppData ?? userProfile ?? Directory.current.path;
      directory = Directory('$basePath\\Cnote');
    } else {
      directory = Directory('${Directory.current.path}/.cnote');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<File> getDatabaseFile() async {
    if (_dbFile != null) return _dbFile!;
    final directory = await getStorageDirectory();
    _dbFile = File('${directory.path}/$_dbFileName');
    return _dbFile!;
  }

  static Future<File> getSettingsFile() async {
    if (_settingsFile != null) return _settingsFile!;
    final directory = await getStorageDirectory();
    _settingsFile = File('${directory.path}/$_settingsFileName');
    return _settingsFile!;
  }

  /// Load all clips from the persistent database file (.db)
  static Future<List<ClipItem>> loadAllClips() async {
    try {
      final file = await getDatabaseFile();
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return [];
      }

      final dynamic decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded
            .map((item) => ClipItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error loading clips from database: $e');
      return [];
    }
  }

  /// Save all clips atomically to the database file (.db)
  static Future<void> saveAllClips(List<ClipItem> clips) async {
    try {
      final file = await getDatabaseFile();
      final jsonList = clips.map((c) => c.toJson()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

      // Write atomically to temporary file first then rename to prevent corruption
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonString, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (e) {
      debugPrint('Error saving clips to database: $e');
    }
  }

  /// Load persistent DockSettings
  static Future<DockSettings> loadSettings() async {
    try {
      final file = await getSettingsFile();
      if (!await file.exists()) {
        return DockSettings();
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return DockSettings();
      }

      final dynamic decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return DockSettings.fromJson(decoded);
      }
      return DockSettings();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return DockSettings();
    }
  }

  /// Save persistent DockSettings atomically
  static Future<void> saveSettings(DockSettings settings) async {
    try {
      final file = await getSettingsFile();
      final jsonString = const JsonEncoder.withIndent('  ').convert(settings.toJson());

      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonString, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }
}

