import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class GitHubReleaseInfo {
  final String tagName;
  final String version;
  final String releaseNotes;
  final String htmlUrl;
  final String? downloadUrl;
  final String? downloadFileName;
  final int? fileSize;

  const GitHubReleaseInfo({
    required this.tagName,
    required this.version,
    required this.releaseNotes,
    required this.htmlUrl,
    this.downloadUrl,
    this.downloadFileName,
    this.fileSize,
  });

  bool get isNewerThanCurrent {
    return _compareVersions(version, currentVersion) > 0;
  }

  static const String currentVersion = '1.2.0';

  static int _compareVersions(String v1, String v2) {
    final clean1 = v1.replaceAll('v', '').replaceAll('V', '').trim();
    final clean2 = v2.replaceAll('v', '').replaceAll('V', '').trim();
    final p1 = clean1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final p2 = clean2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = p1.length > p2.length ? p1.length : p2.length;
    for (int i = 0; i < maxLen; i++) {
      final a = i < p1.length ? p1[i] : 0;
      final b = i < p2.length ? p2[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }
}

class UpdateService {
  static const String repoOwner = 'mahtab-jack';
  static const String repoName = 'ClipDock';
  static const String currentVersion = '1.2.0';

  /// Check GitHub releases for latest version
  static Future<GitHubReleaseInfo?> checkForUpdates() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(
        Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest'),
      );
      request.headers.set('User-Agent', 'ClipDock-App');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      client.close();

      final dynamic data = jsonDecode(body);
      if (data is! Map<String, dynamic>) return null;

      final tagName = data['tag_name'] as String? ?? '';
      final version = tagName.startsWith('v') || tagName.startsWith('V')
          ? tagName.substring(1)
          : tagName;
      final releaseNotes = data['body'] as String? ?? 'No release notes provided.';
      final htmlUrl = data['html_url'] as String? ?? 'https://github.com/$repoOwner/$repoName/releases';

      String? downloadUrl;
      String? downloadFileName;
      int? fileSize;

      if (data['assets'] is List) {
        for (var asset in data['assets'] as List) {
          if (asset is Map<String, dynamic>) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.exe')) {
              downloadUrl = asset['browser_download_url'] as String?;
              downloadFileName = asset['name'] as String?;
              fileSize = (asset['size'] as num?)?.toInt();
              break;
            }
          }
        }
      }

      return GitHubReleaseInfo(
        tagName: tagName,
        version: version,
        releaseNotes: releaseNotes,
        htmlUrl: htmlUrl,
        downloadUrl: downloadUrl,
        downloadFileName: downloadFileName,
        fileSize: fileSize,
      );
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  /// Download installer .exe file with live progress (0.0 to 1.0)
  static Future<File?> downloadUpdate({
    required String downloadUrl,
    required String fileName,
    required Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    HttpClient? client;
    try {
      final tempDir = Directory.systemTemp;
      final targetFile = File('${tempDir.path}\\$fileName');
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }

      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(Uri.parse(downloadUrl));
      request.headers.set('User-Agent', 'ClipDock-App');
      final response = await request.close();

      if (response.statusCode != 200) {
        client.close();
        return null;
      }

      final totalBytes = response.contentLength;
      int receivedBytes = 0;
      final sink = targetFile.openWrite();

      await for (var chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final p = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          onProgress(p, receivedBytes, totalBytes);
        } else {
          onProgress(0.0, receivedBytes, 0);
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      return targetFile;
    } catch (e) {
      client?.close();
      debugPrint('Error downloading update: $e');
      return null;
    }
  }

  /// Launch the installer .exe to install the update
  static Future<bool> launchInstaller(File installerFile) async {
    try {
      if (!await installerFile.exists()) return false;
      await Process.start(
        installerFile.path,
        ['/SILENT', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (_) {
      try {
        await Process.start(
          'cmd',
          ['/c', 'start', '', installerFile.path],
          mode: ProcessStartMode.detached,
        );
        return true;
      } catch (e) {
        debugPrint('Error launching installer: $e');
        return false;
      }
    }
  }
}
