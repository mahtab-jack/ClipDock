import 'dart:async';
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

  /// Check if this is a first-ever fresh install (no database or settings file previously existed on disk)
  static Future<bool> isFirstEverInstall() async {
    try {
      final db = await getDatabaseFile();
      final settings = await getSettingsFile();
      final hasDb = await db.exists();
      final hasSettings = await settings.exists();
      return !hasDb && !hasSettings;
    } catch (_) {
      return false;
    }
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

  static Timer? _autoBackupDebounceTimer;

  /// Get the standard user Documents backup directory: Documents\ClipDock\Backups\
  static Future<Directory> getAutoBackupDirectory() async {
    Directory directory;
    if (!kIsWeb && Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path;
      directory = Directory('$userProfile\\Documents\\ClipDock\\Backups');
    } else {
      directory = Directory('${Directory.current.path}/Documents/ClipDock/Backups');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Trigger debounced automatic backup to Documents\ClipDock\Backups\clipdock_autobackup.json
  static void triggerAutoBackup(DockSettings settings, List<ClipItem> clips) {
    if (!settings.autoBackup) return;
    _autoBackupDebounceTimer?.cancel();
    _autoBackupDebounceTimer = Timer(const Duration(milliseconds: 1000), () async {
      await performAutoBackup(settings, clips);
    });
  }

  /// Perform automatic backup atomically to Documents\ClipDock\Backups\
  static Future<File?> performAutoBackup(DockSettings settings, List<ClipItem> clips) async {
    try {
      if (!settings.autoBackup) return null;
      final dir = await getAutoBackupDirectory();
      final file = File('${dir.path}\\clipdock_autobackup.json');
      final jsonString = createBackupJsonString(settings, clips);

      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonString, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
      return file;
    } catch (e) {
      debugPrint('Error performing auto-backup: $e');
      return null;
    }
  }

  /// Generate a unified backup JSON string containing app version, timestamp, settings, and all clips
  static String createBackupJsonString(DockSettings settings, List<ClipItem> clips) {
    final backupData = {
      'app': 'ClipDock',
      'version': '1.1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings.toJson(),
      'clips': clips.map((c) => c.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  /// Parse unified backup JSON or legacy clip list JSON
  static RestoredBackupData? parseBackupJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        DockSettings? restoredSettings;
        if (decoded.containsKey('settings') && decoded['settings'] is Map<String, dynamic>) {
          restoredSettings = DockSettings.fromJson(decoded['settings'] as Map<String, dynamic>);
        }

        final List<ClipItem> restoredClips = [];
        if (decoded.containsKey('clips') && decoded['clips'] is List) {
          for (var entry in decoded['clips'] as List) {
            if (entry is Map<String, dynamic>) {
              restoredClips.add(ClipItem.fromJson(entry));
            }
          }
        }

        return RestoredBackupData(
          settings: restoredSettings,
          clips: restoredClips,
        );
      } else if (decoded is List) {
        final List<ClipItem> legacyClips = [];
        for (var entry in decoded) {
          if (entry is Map<String, dynamic>) {
            legacyClips.add(ClipItem.fromJson(entry));
          }
        }
        return RestoredBackupData(
          settings: null,
          clips: legacyClips,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing backup JSON: $e');
      return null;
    }
  }

  /// Open the Backup folder in Windows Explorer
  static Future<void> openBackupFolder() async {
    try {
      final dir = await getAutoBackupDirectory();
      if (!kIsWeb && Platform.isWindows) {
        await Process.run('explorer.exe', [dir.path]);
      }
    } catch (e) {
      debugPrint('Error opening backup folder: $e');
    }
  }
}

class RestoredBackupData {
  final DockSettings? settings;
  final List<ClipItem> clips;

  const RestoredBackupData({
    this.settings,
    required this.clips,
  });
}

