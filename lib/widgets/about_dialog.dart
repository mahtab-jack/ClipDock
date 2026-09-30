import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dock_settings.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class AboutDialogWidget extends StatefulWidget {
  final bool isDark;
  final DockSettings settings;

  const AboutDialogWidget({
    super.key,
    required this.isDark,
    required this.settings,
  });

  @override
  State<AboutDialogWidget> createState() => _AboutDialogWidgetState();
}

class _AboutDialogWidgetState extends State<AboutDialogWidget> {
  bool _isCopied = false;
  bool _isCheckingUpdate = false;
  String? _statusMsg;

  static const String githubUrl = 'https://github.com/mahtab-jack';

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
      _statusMsg = 'Checking GitHub releases...';
    });

    final releaseInfo = await UpdateService.checkForUpdates();
    if (!mounted) return;

    setState(() {
      _isCheckingUpdate = false;
    });

    if (releaseInfo == null) {
      setState(() {
        _statusMsg = 'Could not reach GitHub releases';
      });
      return;
    }

    if (releaseInfo.isNewerThanCurrent) {
      setState(() {
        _statusMsg = null;
      });
      _showUpdateModal(releaseInfo);
    } else {
      setState(() {
        _statusMsg = 'Clip Dock is up to date (v${UpdateService.currentVersion})';
      });
    }
  }

  void _showUpdateModal(GitHubReleaseInfo releaseInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UpdateModal(
        releaseInfo: releaseInfo,
        isDark: widget.isDark,
        settings: widget.settings,
      ),
    );
  }

  void _openGithub() async {
    Clipboard.setData(const ClipboardData(text: githubUrl));
    setState(() {
      _isCopied = true;
      _statusMsg = 'Opening browser & copied link';
    });

    if (!kIsWeb && Platform.isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', '', githubUrl]);
      } catch (_) {}
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
          _statusMsg = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgAlpha = (widget.settings.opacity * 255).round().clamp(0, 255);
    final bgSurface = isDark
        ? Color.fromARGB(bgAlpha, 0, 0, 0)
        : Color.fromARGB(bgAlpha, 241, 245, 249);
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg = isDark
        ? Color.fromARGB((widget.settings.opacity * 220).round().clamp(0, 255), 14, 14, 14)
        : Color.fromARGB((widget.settings.opacity * 200).round().clamp(0, 255), 255, 255, 255);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.settings.blur,
            sigmaY: widget.settings.blur,
          ),
          child: Container(
            width: 375,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'About Clip Dock',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      icon: Icon(Icons.close_rounded, color: subtextColor),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // App Brand & Version Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    ),
                  ),
                  child: Column(
                    children: [
                      // App Name & Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Clip Dock',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.accentCyan.withAlpha(35) : AppColors.accentCyan.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark ? AppColors.accentCyan.withAlpha(120) : AppColors.accentCyan.withAlpha(120),
                              ),
                            ),
                            child: Text(
                              'v1.2.0',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Smart Edge Clipboard Manager for Windows',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: subtextColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                      ),
                      const SizedBox(height: 12),

                      // Developed By
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Developed by',
                            style: TextStyle(
                              fontSize: 11,
                              color: subtextColor,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Mahtab Jack',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Check for Updates Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.system_update_alt_rounded,
                        size: 20,
                        color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Software Updates',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Latest version from GitHub',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isCheckingUpdate ? null : _checkForUpdates,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkGlassSurface
                                  : AppColors.lightGlassSurface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.accentSilver.withAlpha(120)
                                    : AppColors.lightHandle.withAlpha(120),
                                width: 1,
                              ),
                            ),
                            child: _isCheckingUpdate
                                ? SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                    ),
                                  )
                                : Text(
                                    'Check Updates',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // GitHub Profile Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Vector GitHub Icon
                      GithubIcon(
                        size: 20,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      const SizedBox(width: 10),

                      // GitHub Profile Label
                      Expanded(
                        child: Text(
                          'GitHub',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),

                      // Visit Profile Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openGithub,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.accentCyan.withAlpha(35)
                                  : AppColors.accentCyan.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.accentCyan.withAlpha(140)
                                    : AppColors.accentCyan.withAlpha(140),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _isCopied ? 'Opening...' : 'Visit Profile',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Message Feedback
                if (_statusMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _statusMsg!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _statusMsg!.contains('error') || _statusMsg!.contains('failed')
                          ? const Color(0xFFFB7185)
                          : AppColors.accentEmerald,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GithubIcon extends StatelessWidget {
  final double size;
  final Color color;

  const GithubIcon({
    super.key,
    this.size = 20.0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GithubIconPainter(color),
    );
  }
}

class _GithubIconPainter extends CustomPainter {
  final Color color;

  _GithubIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    final path = Path();
    path.moveTo(12.0 * scaleX, 0.0 * scaleY);
    path.cubicTo(5.37 * scaleX, 0.0 * scaleY, 0.0 * scaleX, 5.37 * scaleY, 0.0 * scaleX, 12.0 * scaleY);
    path.cubicTo(0.0 * scaleX, 17.31 * scaleY, 3.44 * scaleX, 21.8 * scaleY, 8.21 * scaleX, 23.38 * scaleY);
    path.cubicTo(8.81 * scaleX, 23.49 * scaleY, 9.03 * scaleX, 23.12 * scaleY, 9.03 * scaleX, 22.8 * scaleY);
    path.cubicTo(9.03 * scaleX, 22.52 * scaleY, 9.02 * scaleX, 21.75 * scaleY, 9.01 * scaleX, 20.76 * scaleY);
    path.cubicTo(5.67 * scaleX, 21.49 * scaleY, 4.97 * scaleX, 19.16 * scaleY, 4.97 * scaleX, 19.16 * scaleY);
    path.cubicTo(4.42 * scaleX, 17.77 * scaleY, 3.63 * scaleX, 17.4 * scaleY, 3.63 * scaleX, 17.4 * scaleY);
    path.cubicTo(2.54 * scaleX, 16.66 * scaleY, 3.71 * scaleX, 16.67 * scaleY, 3.71 * scaleX, 16.67 * scaleY);
    path.cubicTo(4.92 * scaleX, 16.76 * scaleY, 5.55 * scaleX, 17.91 * scaleY, 5.55 * scaleX, 17.91 * scaleY);
    path.cubicTo(6.62 * scaleX, 19.74 * scaleY, 8.35 * scaleX, 19.21 * scaleY, 9.04 * scaleX, 18.9 * scaleY);
    path.cubicTo(9.15 * scaleX, 18.12 * scaleY, 9.46 * scaleX, 17.59 * scaleY, 9.8 * scaleX, 17.29 * scaleY);
    path.cubicTo(7.14 * scaleX, 16.99 * scaleY, 4.34 * scaleX, 15.96 * scaleY, 4.34 * scaleX, 11.37 * scaleY);
    path.cubicTo(4.34 * scaleX, 10.06 * scaleY, 4.81 * scaleX, 8.99 * scaleY, 5.58 * scaleX, 8.15 * scaleY);
    path.cubicTo(5.45 * scaleX, 7.85 * scaleY, 5.04 * scaleX, 6.63 * scaleY, 5.7 * scaleX, 4.98 * scaleY);
    path.cubicTo(5.7 * scaleX, 4.98 * scaleY, 6.71 * scaleX, 4.66 * scaleY, 9.0 * scaleX, 6.22 * scaleY);
    path.cubicTo(9.96 * scaleX, 5.95 * scaleY, 10.98 * scaleX, 5.82 * scaleY, 12.0 * scaleX, 5.81 * scaleY);
    path.cubicTo(13.02 * scaleX, 5.82 * scaleY, 14.04 * scaleX, 5.95 * scaleY, 15.0 * scaleX, 6.22 * scaleY);
    path.cubicTo(17.29 * scaleX, 4.66 * scaleY, 18.3 * scaleX, 4.98 * scaleY, 18.3 * scaleX, 4.98 * scaleY);
    path.cubicTo(18.96 * scaleX, 6.63 * scaleY, 18.55 * scaleX, 7.85 * scaleY, 18.42 * scaleX, 8.15 * scaleY);
    path.cubicTo(19.19 * scaleX, 8.99 * scaleY, 19.65 * scaleX, 10.06 * scaleY, 19.65 * scaleX, 11.37 * scaleY);
    path.cubicTo(19.65 * scaleX, 15.97 * scaleY, 16.84 * scaleX, 16.98 * scaleY, 14.17 * scaleX, 17.28 * scaleY);
    path.cubicTo(14.6 * scaleX, 17.65 * scaleY, 14.98 * scaleX, 18.38 * scaleY, 14.98 * scaleX, 19.5 * scaleY);
    path.cubicTo(14.98 * scaleX, 21.12 * scaleY, 14.97 * scaleX, 22.42 * scaleY, 14.97 * scaleX, 22.8 * scaleY);
    path.cubicTo(14.97 * scaleX, 23.13 * scaleY, 15.18 * scaleX, 23.5 * scaleY, 15.79 * scaleX, 23.38 * scaleY);
    path.cubicTo(20.56 * scaleX, 21.79 * scaleY, 24.0 * scaleX, 17.31 * scaleY, 24.0 * scaleX, 12.0 * scaleY);
    path.cubicTo(24.0 * scaleX, 5.37 * scaleY, 18.63 * scaleX, 0.0 * scaleY, 12.0 * scaleX, 0.0 * scaleY);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GithubIconPainter oldDelegate) => oldDelegate.color != color;
}

class _UpdateModal extends StatefulWidget {
  final GitHubReleaseInfo releaseInfo;
  final bool isDark;
  final DockSettings settings;

  const _UpdateModal({
    required this.releaseInfo,
    required this.isDark,
    required this.settings,
  });

  @override
  State<_UpdateModal> createState() => _UpdateModalState();
}

class _UpdateModalState extends State<_UpdateModal> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = 'Update available';
  File? _downloadedFile;

  Future<void> _startDownloadAndInstall() async {
    if (widget.releaseInfo.downloadUrl == null) {
      // Fallback: open release page in browser
      try {
        await Process.run('cmd', ['/c', 'start', '', widget.releaseInfo.htmlUrl]);
      } catch (_) {}
      return;
    }

    setState(() {
      _isDownloading = true;
      _statusText = 'Downloading update...';
      _progress = 0.0;
    });

    final fileName = widget.releaseInfo.downloadFileName ?? 'ClipDock-Setup-${widget.releaseInfo.version}.exe';
    final file = await UpdateService.downloadUpdate(
      downloadUrl: widget.releaseInfo.downloadUrl!,
      fileName: fileName,
      onProgress: (p, received, total) {
        if (mounted) {
          setState(() {
            _progress = p;
            if (total > 0) {
              final mbRec = (received / (1024 * 1024)).toStringAsFixed(1);
              final mbTot = (total / (1024 * 1024)).toStringAsFixed(1);
              _statusText = 'Downloading: $mbRec / $mbTot MB (${(p * 100).toInt()}%)';
            }
          });
        }
      },
    );

    if (!mounted) return;

    if (file != null && await file.exists()) {
      setState(() {
        _isDownloading = false;
        _downloadedFile = file;
        _progress = 1.0;
        _statusText = 'Download completed. Ready to install.';
      });
      // Automatically launch installer
      await UpdateService.launchInstaller(file);
    } else {
      setState(() {
        _isDownloading = false;
        _statusText = 'Download failed. Please check internet connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgAlpha = (widget.settings.opacity * 255).round().clamp(0, 255);
    final bgSurface = isDark
        ? Color.fromARGB(bgAlpha, 15, 23, 42)
        : Color.fromARGB(bgAlpha, 255, 255, 255);
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg = isDark
        ? Color.fromARGB((widget.settings.opacity * 220).round().clamp(0, 255), 30, 41, 59)
        : Color.fromARGB((widget.settings.opacity * 200).round().clamp(0, 255), 241, 245, 249);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.settings.blur,
            sigmaY: widget.settings.blur,
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.system_update_alt_rounded,
                          size: 18,
                          color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Update Available',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    if (!_isDownloading)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        icon: Icon(Icons.close_rounded, color: subtextColor),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Version Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Version',
                            style: TextStyle(fontSize: 10, color: subtextColor),
                          ),
                          Text(
                            'v${GitHubReleaseInfo.currentVersion}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: subtextColor,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: subtextColor,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Latest Release',
                            style: TextStyle(fontSize: 10, color: subtextColor),
                          ),
                          Text(
                            'v${widget.releaseInfo.version}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.accentEmerald : const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Release Notes
                Text(
                  'Release Notes',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.releaseInfo.releaseNotes,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Progress Indicator
                if (_isDownloading || _progress > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      minHeight: 6,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Status Text
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!_isDownloading)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: subtextColor,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isDownloading
                          ? null
                          : (_downloadedFile != null
                              ? () => UpdateService.launchInstaller(_downloadedFile!)
                              : _startDownloadAndInstall),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                        foregroundColor: isDark ? Colors.black87 : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text(
                        _downloadedFile != null ? 'Install Now' : 'Download & Install',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

