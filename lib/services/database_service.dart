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

  static Directory getStorageDirectorySync() {
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

    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  static Future<Directory> getImagesDirectory() async {
    final baseDir = await getStorageDirectory();
    final imagesDir = Directory('${baseDir.path}\\images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  static Directory getImagesDirectorySync() {
    final baseDir = getStorageDirectorySync();
    final imagesDir = Directory('${baseDir.path}\\images');
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }
    return imagesDir;
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
        final clips = decoded
            .map((item) => ClipItem.fromJson(item as Map<String, dynamic>))
            .toList();
        // Clean up leaked and orphaned image files in the background
        cleanupOrphanedImages(clips);
        return clips;
      }
      return [];
    } catch (e) {
      debugPrint('Error loading clips from database: $e');
      return [];
    }
  }

  /// Clean up orphaned image files that are not referenced by any clip in the database
  static Future<int> cleanupOrphanedImages(List<ClipItem> clips) async {
    try {
      final imagesDir = await getImagesDirectory();
      if (!await imagesDir.exists()) return 0;

      final activePaths = <String>{};
      for (final clip in clips) {
        if (clip.isImage && clip.imagePath != null && clip.imagePath!.isNotEmpty) {
          activePaths.add(clip.imagePath!.toLowerCase().replaceAll('/', '\\'));
        }
      }

      int deletedCount = 0;
      final entities = imagesDir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final normalized = entity.path.toLowerCase().replaceAll('/', '\\');
          // Preserve temp files in active use
          if (normalized.endsWith('temp_clip.bmp')) continue;
          if (!activePaths.contains(normalized)) {
            try {
              entity.deleteSync();
              deletedCount++;
            } catch (_) {}
          }
        }
      }
      if (deletedCount > 0) {
        debugPrint('Cleaned up $deletedCount orphaned image files from disk');
      }
      return deletedCount;
    } catch (e) {
      debugPrint('Error cleaning up orphaned images: $e');
      return 0;
    }
  }

  /// Enforces auto-clip retention and trash retention policy
  static bool applyRetentionPolicy(DockSettings settings, List<ClipItem> clips) {
    bool changed = false;
    final now = DateTime.now();

    // 1. Move old auto clips to trash if older than autoClipsRetentionDays
    if (settings.autoClipsRetentionDays > 0) {
      for (final clip in clips) {
        if (clip.isAuto && !clip.isDeleted && !clip.isStarred) {
          final ageDays = now.difference(clip.createdAt).inDays;
          if (ageDays >= settings.autoClipsRetentionDays) {
            clip.isDeleted = true;
            clip.deletedAt = now;
            changed = true;
          }
        }
      }
    }

    // 2. Permanently delete trash items older than trashRetentionDays
    if (settings.trashRetentionDays > 0) {
      clips.removeWhere((clip) {
        if (clip.isDeleted) {
          final deleteTime = clip.deletedAt ?? clip.createdAt;
          final ageDays = now.difference(deleteTime).inDays;
          if (ageDays >= settings.trashRetentionDays) {
            if (clip.isImage && clip.imagePath != null) {
              try {
                final f = File(clip.imagePath!);
                if (f.existsSync()) f.deleteSync();
              } catch (_) {}
            }
            changed = true;
            return true;
          }
        }
        return false;
      });
    }

    return changed;
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

  /// Generate a unified backup JSON string containing app version, timestamp, settings, and all clips (including embedded images)
  static String createBackupJsonString(DockSettings settings, List<ClipItem> clips) {
    final clipsJson = clips.map((c) {
      final json = c.toJson();
      if (c.isImage && c.imagePath != null && c.imagePath!.isNotEmpty) {
        try {
          final file = File(c.imagePath!);
          if (file.existsSync()) {
            final bytes = file.readAsBytesSync();
            json['imageBase64'] = base64Encode(bytes);
          }
        } catch (e) {
          debugPrint('Error serializing image for backup: $e');
        }
      }
      return json;
    }).toList();

    final backupData = {
      'app': 'ClipDock',
      'version': '1.2.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings.toJson(),
      'clips': clipsJson,
    };
    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  /// Parse unified backup JSON or legacy clip list JSON, restoring image files into local storage
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
          final imagesDir = getImagesDirectorySync();
          for (var entry in decoded['clips'] as List) {
            if (entry is Map<String, dynamic>) {
              final clip = ClipItem.fromJson(entry);
              if (clip.isImage) {
                final imageBase64 = entry['imageBase64'] as String?;
                if (imageBase64 != null && imageBase64.isNotEmpty) {
                  try {
                    bool fileExists = false;
                    if (clip.imagePath != null && clip.imagePath!.isNotEmpty) {
                      fileExists = File(clip.imagePath!).existsSync();
                    }
                    if (!fileExists) {
                      final ext = (clip.imagePath != null && clip.imagePath!.toLowerCase().endsWith('.png'))
                          ? 'png'
                          : 'bmp';
                      final targetFile = File('${imagesDir.path}\\img_${clip.id}.$ext');
                      final bytes = base64Decode(imageBase64);
                      targetFile.writeAsBytesSync(bytes, flush: true);
                      clip.imagePath = targetFile.path;
                      clip.content = targetFile.path;
                    }
                  } catch (e) {
                    debugPrint('Error restoring image file from backup: $e');
                  }
                }
              }
              restoredClips.add(clip);
            }
          }
        }

        return RestoredBackupData(
          settings: restoredSettings,
          clips: restoredClips,
        );
      } else if (decoded is List) {
        final imagesDir = getImagesDirectorySync();
        final List<ClipItem> legacyClips = [];
        for (var entry in decoded) {
          if (entry is Map<String, dynamic>) {
            final clip = ClipItem.fromJson(entry);
            if (clip.isImage) {
              final imageBase64 = entry['imageBase64'] as String?;
              if (imageBase64 != null && imageBase64.isNotEmpty) {
                try {
                  bool fileExists = false;
                  if (clip.imagePath != null && clip.imagePath!.isNotEmpty) {
                    fileExists = File(clip.imagePath!).existsSync();
                  }
                  if (!fileExists) {
                    final ext = (clip.imagePath != null && clip.imagePath!.toLowerCase().endsWith('.png'))
                        ? 'png'
                        : 'bmp';
                    final targetFile = File('${imagesDir.path}\\img_${clip.id}.$ext');
                    final bytes = base64Decode(imageBase64);
                    targetFile.writeAsBytesSync(bytes, flush: true);
                    clip.imagePath = targetFile.path;
                    clip.content = targetFile.path;
                  }
                } catch (e) {
                  debugPrint('Error restoring legacy image file from backup: $e');
                }
              }
            }
            legacyClips.add(clip);
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

