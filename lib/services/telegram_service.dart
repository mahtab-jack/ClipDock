import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/clip_item.dart';

class TelegramService {
  static Future<({bool success, String? error, String? botName})> testConnection({
    required String botToken,
    required String chatId,
  }) async {
    final token = botToken.trim();
    final chat = chatId.trim();

    if (token.isEmpty) {
      return (success: false, error: 'Telegram Bot Token is required', botName: null);
    }

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 12);

      // 1. Verify Bot Token with getMe
      final getMeUri = Uri.parse('https://api.telegram.org/bot$token/getMe');
      final getMeReq = await client.getUrl(getMeUri);
      final getMeResp = await getMeReq.close();
      final getMeBody = await getMeResp.transform(utf8.decoder).join();

      if (getMeResp.statusCode != 200) {
        try {
          final data = jsonDecode(getMeBody);
          final desc = data['description'] as String? ?? 'Invalid Bot Token (${getMeResp.statusCode})';
          return (success: false, error: desc, botName: null);
        } catch (_) {
          return (success: false, error: 'Invalid Bot Token (${getMeResp.statusCode})', botName: null);
        }
      }

      final dynamic getMeData = jsonDecode(getMeBody);
      final botResult = getMeData['result'] as Map<String, dynamic>?;
      final botUsername = botResult?['username'] as String? ?? 'Bot';

      // 2. If chat ID is provided, verify sending permissions with a test ping
      if (chat.isNotEmpty) {
        final sendUri = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
        final sendReq = await client.postUrl(sendUri);
        sendReq.headers.contentType = ContentType.json;

        final payload = jsonEncode({
          'chat_id': chat,
          'text': 'Connected to ClipDock. Test message verified.',
        });

        sendReq.write(payload);
        final sendResp = await sendReq.close();
        final sendBody = await sendResp.transform(utf8.decoder).join();

        if (sendResp.statusCode != 200) {
          try {
            final data = jsonDecode(sendBody);
            final desc = data['description'] as String? ?? 'Channel delivery failed (${sendResp.statusCode})';
            return (
              success: false,
              error: 'Bot valid (@$botUsername), but channel delivery failed: $desc',
              botName: botUsername,
            );
          } catch (_) {
            return (
              success: false,
              error: 'Bot valid (@$botUsername), but failed to message channel (${sendResp.statusCode})',
              botName: botUsername,
            );
          }
        }
      }

      return (success: true, error: null, botName: botUsername);
    } catch (e) {
      return (success: false, error: 'Connection failed: $e', botName: null);
    } finally {
      client?.close();
    }
  }

  static Future<({bool success, String? error})> sendMessage({
    required String botToken,
    required String chatId,
    required String text,
  }) async {
    final token = botToken.trim();
    final chat = chatId.trim();

    if (token.isEmpty || chat.isEmpty) {
      return (success: false, error: 'Bot Token or Channel ID is missing in Settings');
    }

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode({
        'chat_id': chat,
        'text': text,
      });

      request.write(payload);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        return (success: true, error: null);
      } else {
        try {
          final data = jsonDecode(body);
          final desc = data['description'] as String? ?? 'Telegram API error ${response.statusCode}';
          return (success: false, error: desc);
        } catch (_) {
          return (success: false, error: 'Telegram API status ${response.statusCode}');
        }
      }
    } catch (e) {
      return (success: false, error: e.toString());
    } finally {
      client?.close();
    }
  }

  static Future<({bool success, String? error})> sendPhoto({
    required String botToken,
    required String chatId,
    required String imagePath,
    String? caption,
    void Function(int sent, int total, double percent)? onProgress,
  }) async {
    final token = botToken.trim();
    final chat = chatId.trim();

    if (token.isEmpty || chat.isEmpty) {
      return (success: false, error: 'Bot Token or Channel ID is missing in Settings');
    }

    final file = File(imagePath);
    if (!file.existsSync()) {
      return (success: false, error: 'Image file does not exist on disk');
    }

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 60);
      final uri = Uri.parse('https://api.telegram.org/bot$token/sendPhoto');
      final request = await client.postUrl(uri);

      final boundary = 'ClipDockBoundary${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );

      final bytes = await file.readAsBytes();
      final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'photo.bmp';

      final buffer = BytesBuilder();

      // chat_id field
      buffer.add(utf8.encode('--$boundary\r\n'));
      buffer.add(utf8.encode('Content-Disposition: form-data; name="chat_id"\r\n\r\n'));
      buffer.add(utf8.encode('$chat\r\n'));

      // caption field (optional)
      if (caption != null && caption.trim().isNotEmpty) {
        buffer.add(utf8.encode('--$boundary\r\n'));
        buffer.add(utf8.encode('Content-Disposition: form-data; name="caption"\r\n\r\n'));
        buffer.add(utf8.encode('${caption.trim()}\r\n'));
      }

      // photo file field
      buffer.add(utf8.encode('--$boundary\r\n'));
      buffer.add(utf8.encode('Content-Disposition: form-data; name="photo"; filename="$fileName"\r\n'));
      buffer.add(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'));
      buffer.add(bytes);
      buffer.add(utf8.encode('\r\n'));

      // end boundary
      buffer.add(utf8.encode('--$boundary--\r\n'));

      final payloadBytes = buffer.toBytes();
      final totalBytes = payloadBytes.length;
      request.contentLength = totalBytes;

      // Stream payload in chunks to calculate and report accurate progress
      const chunkSize = 64 * 1024; // 64 KB
      int sentBytes = 0;

      for (int offset = 0; offset < totalBytes; offset += chunkSize) {
        final end = (offset + chunkSize < totalBytes) ? offset + chunkSize : totalBytes;
        request.add(payloadBytes.sublist(offset, end));
        await request.flush();
        sentBytes = end;
        if (onProgress != null) {
          final fraction = (sentBytes / totalBytes).clamp(0.0, 1.0);
          onProgress(sentBytes, totalBytes, fraction);
        }
      }

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        return (success: true, error: null);
      } else {
        try {
          final data = jsonDecode(body);
          final desc = data['description'] as String? ?? 'Telegram API error ${response.statusCode}';
          return (success: false, error: desc);
        } catch (_) {
          return (success: false, error: 'Telegram API status ${response.statusCode}');
        }
      }
    } catch (e) {
      return (success: false, error: e.toString());
    } finally {
      client?.close();
    }
  }

  static Future<({bool success, String? error})> sendClip({
    required String botToken,
    required String chatId,
    required ClipItem item,
    void Function(int sent, int total, double percent)? onProgress,
  }) async {
    if (item.isImage && item.imagePath != null && File(item.imagePath!).existsSync()) {
      final caption = item.title.isNotEmpty && item.title != 'Captured Image' ? item.title : null;
      return sendPhoto(
        botToken: botToken,
        chatId: chatId,
        imagePath: item.imagePath!,
        caption: caption,
        onProgress: onProgress,
      );
    } else {
      onProgress?.call(1, 1, 1.0);
      return sendMessage(
        botToken: botToken,
        chatId: chatId,
        text: item.content,
      );
    }
  }
}
