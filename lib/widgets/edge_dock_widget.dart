import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import '../data/sample_clips.dart';
import '../models/clip_item.dart';
import '../models/dock_settings.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'about_dialog.dart';
import 'add_clip_dialog.dart';
import 'clip_card.dart';
import 'edit_clip_dialog.dart';
import 'header_bar.dart';
import 'search_filter_bar.dart';
import 'settings_dialog.dart';
import '../services/telegram_service.dart';

enum ToastType {
  success,
  warning,
  info,
  error,
}

class EdgeDockWidget extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback? onMinimize;

  const EdgeDockWidget({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    this.onMinimize,
  });

  @override
  State<EdgeDockWidget> createState() => EdgeDockWidgetState();
}

class EdgeDockWidgetState extends State<EdgeDockWidget> {
  bool get isPinned => _isPinned;
  final TextEditingController _searchController = TextEditingController();
  List<ClipItem> _clips = [];
  List<ClipItem> _filteredClips = [];

  DockSettings _settings = DockSettings();
  ClipTab _activeTab = ClipTab.all;
  MediaFilter _activeMediaFilter = MediaFilter.all;

  bool _isExpanded = false;
  bool _isPinned = false;
  bool _isDialogOpen = false;

  Timer? _autoHideTimer;
  Timer? _startupTimer;
  Timer? _clipboardMonitorTimer;
  String? _lastMonitoredClipboard;
  String? _toastMessage;
  ToastType _toastType = ToastType.success;
  Timer? _toastTimer;
  double? _toastProgress;
  String? _sendingTelegramClipId;

  double get _panelWidth => _settings.panelWidth;
  static const double _windowHeight = 680.0;
  double _targetY = 80.0;
  bool _isAnimating = false;

  double get _visibleX => (Platform.isWindows ? -8.0 : 0.0) + _settings.edgeOffsetVisible;
  double get _hiddenX => -_panelWidth + _settings.edgeOffsetHidden;
  double get _ribbonWidth => _settings.ribbonWidth;
  double get _totalWidth => _panelWidth + _ribbonWidth;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndClips();
    _initScreenAndStart();
    _startClipboardMonitoring();
  }

  @override
  void didUpdateWidget(covariant EdgeDockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDark != oldWidget.isDark) {
      if (_settings.autoRibbonColor) {
        setState(() {
          _settings.ribbonColor = widget.isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
        });
        _persistSettings();
      }
    }
  }

  void updateSettingsFromExternal(DockSettings newSettings) {
    if (mounted) {
      setState(() {
        _settings = newSettings;
        _isPinned = newSettings.isPinned;
      });
      _syncWindowBlur();
    }
  }

  Future<void> _loadSettingsAndClips() async {
    final isFreshInstall = await DatabaseService.isFirstEverInstall();
    final loadedSettings = await DatabaseService.loadSettings();
    final loadedClips = await DatabaseService.loadAllClips();
    final bool retentionChanged = DatabaseService.applyRetentionPolicy(loadedSettings, loadedClips);
    if (retentionChanged) {
      DatabaseService.saveAllClips(loadedClips);
    }
    if (mounted) {
      setState(() {
        _settings = loadedSettings;
        _isPinned = loadedSettings.isPinned;
        if (loadedClips.isNotEmpty) {
          _clips = loadedClips;
        } else {
          _clips = List.from(initialClipItems);
        }
        _applyFilter();
      });
      try {
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          await windowManager.setSize(Size(_totalWidth, _windowHeight));
        }
      } catch (_) {}

      _syncWindowBlur();

      // ONLY show the import/start fresh modal if this is a first-ever install (never installed previously)
      if (isFreshInstall && !_settings.hasCompletedInitialSetup && loadedClips.isEmpty) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted && !_settings.hasCompletedInitialSetup) {
            _showFirstLaunchImportDialog();
          }
        });
      } else {
        if (!_settings.hasCompletedInitialSetup) {
          _settings.hasCompletedInitialSetup = true;
          _persistSettings();
        }
        DatabaseService.triggerAutoBackup(_settings, _clips);
      }
    }
  }

  Future<void> _syncWindowBlur() async {
    if (!kIsWeb && Platform.isWindows) {
      try {
        const channel = MethodChannel('cnote/drag_drop');
        final bool enableBlur = _settings.blur > 0 || _settings.transparency > 0;
        // Compute ABGR tint color for Windows Acrylic API
        // Higher transparency = lower alpha on tint = more see-through
        final int tintAlpha = ((1.0 - _settings.transparency) * 200).round().clamp(0, 200);
        final bool isDark = _settings.isDark;
        // ABGR format: 0xAABBGGRR
        final int tintColor = isDark
            ? (tintAlpha << 24) | 0x00000000  // black tint
            : (tintAlpha << 24) | 0x00FFFFFF; // pure white tint
        await channel.invokeMethod('setWindowBlur', {
          'enable': enableBlur,
          'tintColor': tintColor,
        });
      } catch (_) {}
    }
  }

  Future<void> _persistClips() async {
    await DatabaseService.saveAllClips(_clips);
    DatabaseService.triggerAutoBackup(_settings, _clips);
  }

  Future<void> _persistSettings() async {
    _settings.isPinned = _isPinned;
    await DatabaseService.saveSettings(_settings);
    DatabaseService.triggerAutoBackup(_settings, _clips);
    _syncWindowBlur();
  }

  Future<void> _initScreenAndStart() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        final Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
        final double screenHeight = primaryDisplay.size.height;
        _targetY = ((screenHeight - _windowHeight) / 2).clamp(20.0, screenHeight - _windowHeight);
      } catch (_) {
        _targetY = 80.0;
      }
    }

    // Start expanded for 2.5 seconds on launch, then slide leftward into the left edge
    setState(() {
      _isExpanded = true;
    });

    _startupTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && !_isPinned && !_isDialogOpen) {
        _collapseDock();
      }
    });
  }

  Future<void> _animateToX(double targetX) async {
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }
    _isAnimating = true;
    try {
      final currentPos = await windowManager.getPosition();
      final startX = currentPos.dx;
      const steps = 6;
      const stepDuration = Duration(milliseconds: 14);

      for (int i = 1; i <= steps; i++) {
        final t = Curves.easeOutCubic.transform(i / steps);
        final x = startX + (targetX - startX) * t;
        await windowManager.setPosition(Offset(x, _targetY));
        await Future.delayed(stepDuration);
      }
      await windowManager.setPosition(Offset(targetX, _targetY));
    } catch (_) {}
    _isAnimating = false;
  }

  Future<void> _expandDock() async {
    _autoHideTimer?.cancel();
    if (_isExpanded && !_isAnimating) {
      try {
        final pos = await windowManager.getPosition();
        if ((pos.dx - _visibleX).abs() < 5) return;
      } catch (_) {}
    }

    setState(() {
      _isExpanded = true;
    });
    await _animateToX(_visibleX);
  }

  Future<void> _collapseDock() async {
    if (_isPinned || _isDialogOpen) return;

    setState(() {
      _isExpanded = false;
    });
    await _animateToX(_hiddenX);
  }

  void toggleDock() {
    if (_isExpanded) {
      _collapseManual();
    } else {
      _expandDock();
    }
  }

  void _collapseManual() {
    setState(() {
      _isPinned = false;
    });
    _persistSettings();
    _collapseDock();
  }

  Future<void> _togglePin() async {
    setState(() {
      _isPinned = !_isPinned;
    });
    await _persistSettings();
    if (_isPinned) {
      await _expandDock();
    } else {
      _collapseDock();
    }
  }

  void minimizeToTray() {
    if (widget.onMinimize != null) {
      widget.onMinimize!();
    } else {
      windowManager.hide();
    }
  }

  void expandDockFromTray() {
    _expandDock();
  }

  void expandDockAndAddClip() {
    _expandDock();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _openAddDialog();
    });
  }

  void togglePinFromTray() {
    _togglePin();
  }

  void openSettingsFromTray() {
    _expandDock();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _openSettingsDialog();
    });
  }

  void openAboutFromTray() {
    _expandDock();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _openAboutDialog();
    });
  }

  void _onMouseEnterEdge() {
    _autoHideTimer?.cancel();
    try {
      windowManager.setAlwaysOnTop(true);
      const MethodChannel('cnote/drag_drop').invokeMethod('captureActiveWindow');
    } catch (_) {}
    _expandDock();
  }

  void _onMouseExitArea() {
    if (_isPinned || _isDialogOpen) return;
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && !_isPinned && !_isDialogOpen) {
        _collapseDock();
      }
    });
  }

  @override
  void dispose() {
    _clipboardMonitorTimer?.cancel();
    _startupTimer?.cancel();
    _searchController.dispose();
    _autoHideTimer?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _startClipboardMonitoring() {
    // Seed initial clipboard content so existing clipboard is not auto-saved unexpectedly
    Clipboard.getData(Clipboard.kTextPlain).then((data) {
      final text = data?.text?.trim();
      if (text != null && text.isNotEmpty) {
        _lastMonitoredClipboard = text;
      }
    }).catchError((_) {});

    // Periodic clipboard polling every 600ms
    _clipboardMonitorTimer = Timer.periodic(const Duration(milliseconds: 600), (_) async {
      await _checkClipboardChanges();
    });
  }

  static const MethodChannel _nativeChannel = MethodChannel('cnote/drag_drop');
  int? _lastClipboardSequence;
  int? _lastImageCheckTime;

  Future<void> _checkClipboardChanges() async {
    try {
      if (!_settings.autoCapture) return;

      // 1. Fast check for Windows: clipboard sequence number
      if (!kIsWeb && Platform.isWindows) {
        final seq = await _nativeChannel.invokeMethod<int>('getClipboardSequenceNumber');
        if (seq != null) {
          if (_lastClipboardSequence != null && seq == _lastClipboardSequence) {
            return;
          }
          _lastClipboardSequence = seq;
        }

        // Check for clipboard image
        final hasImage = await _nativeChannel.invokeMethod<bool>('hasClipboardImage') ?? false;
        if (hasImage) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          // Throttle repeated capture
          if (_lastImageCheckTime == null || (nowMs - _lastImageCheckTime!) > 800) {
            final imagesDir = await DatabaseService.getImagesDirectory();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final imageFilePath = '${imagesDir.path}\\img_$timestamp.png';
            final success = await _nativeChannel.invokeMethod<bool>('saveClipboardImage', {
              'filePath': imageFilePath,
            }) ?? false;

            if (success && File(imageFilePath).existsSync()) {
              final file = File(imageFilePath);
              final fileSize = file.lengthSync();
              // Check if already captured recently with identical size
              final exists = _clips.any((c) =>
                  c.isImage &&
                  c.imagePath != null &&
                  File(c.imagePath!).existsSync() &&
                  File(c.imagePath!).lengthSync() == fileSize);

              if (!exists && fileSize > 0) {
                _lastImageCheckTime = nowMs;
                await _autoCaptureImage(imageFilePath);
                return;
              } else {
                // Critical: delete duplicate image immediately so it never leaks onto disk
                try {
                  file.deleteSync();
                } catch (_) {}
              }
            }
          }
        }
      }

      // 2. Check for clipboard text
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return;

      if (text != _lastMonitoredClipboard) {
        _lastMonitoredClipboard = text;
        if (_settings.maxAutoChars > 0 && text.length > _settings.maxAutoChars) {
          return;
        }
        await _autoCaptureClip(text);
      }
    } catch (_) {}
  }

  Future<void> _autoCaptureImage(String imagePath) async {
    final newClip = ClipItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Captured Image',
      content: imagePath,
      createdAt: DateTime.now(),
      isDeleted: false,
      isAuto: true,
      isImage: true,
      imagePath: imagePath,
    );

    setState(() {
      _clips.insert(0, newClip);
      _applyFilter();
    });

    _showNotification('Auto-saved image to Auto tab', ToastType.info);
    await _persistClips();
  }

  Future<void> _autoCaptureClip(String text) async {
    final existingIndex = _clips.indexWhere((c) => !c.isImage && c.content == text);
    if (existingIndex >= 0) {
      final existing = _clips[existingIndex];
      // If the clip already belongs to the manual Clips tab, preserve it in Clips tab
      if (!existing.isAuto && !existing.isDeleted) {
        return;
      }
      // If it already exists in the Auto tab (or was in Trash), bring it to the top of Auto tab
      if (existing.isAuto) {
        setState(() {
          _clips.removeAt(existingIndex);
          existing.isDeleted = false;
          existing.deletedAt = null;
          existing.createdAt = DateTime.now();
          existing.updatedAt = DateTime.now();
          _clips.insert(0, existing);
          _applyFilter();
        });
        _showNotification('Auto-captured (moved to top)', ToastType.info);
        await _persistClips();
        return;
      }
      return;
    }

    String title = text.replaceAll('\n', ' ').trim();
    if (title.length > 120) {
      title = '${title.substring(0, 120)}...';
    }

    final newClip = ClipItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: text,
      createdAt: DateTime.now(),
      isDeleted: false,
      isAuto: true,
      isImage: false,
    );

    setState(() {
      _clips.insert(0, newClip);
      _applyFilter();
    });

    _showNotification('Auto-saved to Auto tab', ToastType.info);
    await _persistClips();
  }

  void _onCopyClip(ClipItem item, int serialNo) {
    _lastMonitoredClipboard = item.content.trim();
    _showNotification('Copied clip #$serialNo');
  }

  void _moveToAllTab(ClipItem item) {
    setState(() {
      _clips.remove(item);
      item.isAuto = false;
      item.createdAt = DateTime.now();
      item.updatedAt = DateTime.now();
      _clips.insert(0, item);
      _applyFilter();
    });
    _persistClips();
    _showNotification('Moved clip to Clips tab');
  }

  void _applyFilter() {
    final query = _searchController.text;
    setState(() {
      _filteredClips = _clips.where((clip) {
        bool matchesTab = false;
        switch (_activeTab) {
          case ClipTab.all:
            matchesTab = !clip.isDeleted && !clip.isAuto;
            break;
          case ClipTab.auto:
            matchesTab = !clip.isDeleted && clip.isAuto;
            break;
          case ClipTab.starred:
            matchesTab = !clip.isDeleted && clip.isStarred;
            break;
          case ClipTab.trash:
            matchesTab = clip.isDeleted;
            break;
        }

        if (!matchesTab) return false;

        // Media filter: All, Text, or Image
        if (_activeMediaFilter == MediaFilter.text && clip.isImage) {
          return false;
        }
        if (_activeMediaFilter == MediaFilter.image && !clip.isImage) {
          return false;
        }

        return clip.matchesSearch(query);
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    _applyFilter();
  }

  void _clearSearch() {
    _searchController.clear();
    _applyFilter();
  }

  void _toggleStar(String id) {
    setState(() {
      final index = _clips.indexWhere((c) => c.id == id);
      if (index >= 0) {
        _clips[index].isStarred = !_clips[index].isStarred;
        _applyFilter();
      }
    });
    _persistClips();
  }

  void _updateClipColor(ClipItem item, String? colorHex) {
    setState(() {
      item.labelColor = colorHex;
    });
    _persistClips();
  }

  void _showNotification(
    String message, [
    ToastType type = ToastType.success,
    int durationMs = 2200,
    double? progress,
  ]) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _toastType = type;
      _toastProgress = progress;
    });

    if (durationMs > 0) {
      _toastTimer = Timer(Duration(milliseconds: durationMs), () {
        if (mounted) {
          setState(() {
            _toastMessage = null;
            _toastProgress = null;
          });
        }
      });
    }
  }

  void _updateNotificationProgress(String message, double progress) {
    if (!mounted) return;
    setState(() {
      _toastMessage = message;
      _toastProgress = progress;
      _toastType = ToastType.info;
    });
  }

  Future<void> _saveClipText(String text, [String? customTitle]) async {
    _lastMonitoredClipboard = text.trim();
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    final existingIndex = _clips.indexWhere((c) => c.content == text);
    if (existingIndex >= 0) {
      final existing = _clips.removeAt(existingIndex);
      final wasDeleted = existing.isDeleted;
      final wasAuto = existing.isAuto;

      // Adding or pasting explicitly must always send to Clips tab (isAuto = false)
      existing.isAuto = false;
      existing.isDeleted = false;
      existing.deletedAt = null;
      existing.createdAt = DateTime.now();
      existing.updatedAt = DateTime.now();
      if (customTitle != null && customTitle.isNotEmpty) {
        existing.title = customTitle;
        existing.customTitle = customTitle;
      }

      // Bring repeated/existing clip to the top of Clips
      _clips.insert(0, existing);
      _activeTab = ClipTab.all;

      setState(() {
        _applyFilter();
      });

      if (wasDeleted) {
        _showNotification('Restored clip to Clips');
      } else if (wasAuto) {
        _showNotification('Moved to Clips (top)');
      } else {
        _showNotification('Clip moved to top');
      }

      await _persistClips();
      return;
    }

    String title = customTitle ?? text.replaceAll('\n', ' ').trim();
    if (title.length > 120) {
      title = '${title.substring(0, 120)}...';
    }

    final newClip = ClipItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: text,
      createdAt: DateTime.now(),
      isDeleted: false,
      isAuto: false,
      customTitle: (customTitle != null && customTitle.isNotEmpty) ? customTitle : null,
    );

    setState(() {
      _clips.insert(0, newClip);
      _activeTab = ClipTab.all;
      _applyFilter();
    });

    final activeCount = _clips.where((c) => !c.isDeleted && !c.isAuto).length;
    _showNotification('Saved clip #$activeCount');
    await _persistClips();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();

    if (text == null || text.isEmpty) {
      _showNotification('Clipboard is empty', ToastType.warning);
      return;
    }

    _lastMonitoredClipboard = text;
    await _saveClipText(text);
  }

  void _deleteClip(String id) {
    setState(() {
      final index = _clips.indexWhere((c) => c.id == id);
      if (index >= 0) {
        _clips[index].isDeleted = true;
        _clips[index].deletedAt = DateTime.now();
        _applyFilter();
      }
    });
    _persistClips();
    _showNotification('Moved clip to Trash');
  }

  void _restoreClip(String id) {
    setState(() {
      final index = _clips.indexWhere((c) => c.id == id);
      if (index >= 0) {
        _clips[index].isDeleted = false;
        _clips[index].deletedAt = null;
        _applyFilter();
      }
    });
    _persistClips();
    _showNotification('Restored clip to active list');
  }

  void _deletePermanently(String id) {
    setState(() {
      _clips.removeWhere((c) => c.id == id);
      _applyFilter();
    });
    _persistClips();
    _showNotification('Permanently deleted clip');
  }

  void _emptyTrash() {
    final trashCount = _clips.where((c) => c.isDeleted).length;
    if (trashCount == 0) return;

    setState(() {
      _clips.removeWhere((c) => c.isDeleted);
      _applyFilter();
    });
    _persistClips();
    _showNotification('Emptied $trashCount clips from Trash');
  }

  void _clearAutoClips() {
    final autoCount = _clips.where((c) => !c.isDeleted && c.isAuto).length;
    if (autoCount == 0) return;

    setState(() {
      for (final c in _clips) {
        if (!c.isDeleted && c.isAuto) {
          c.isDeleted = true;
          c.deletedAt = DateTime.now();
        }
      }
      _applyFilter();
    });
    _persistClips();
    _showNotification('Cleared $autoCount auto clips to Trash');
  }

  Future<void> _sendClipToTelegram(ClipItem item) async {
    final token = _settings.telegramBotToken.trim();
    final channelId = _settings.telegramChannelId.trim();

    if (token.isEmpty || channelId.isEmpty) {
      _showNotification('Configure Telegram Bot Token & Channel ID in Settings', ToastType.warning, 4000);
      return;
    }

    if (_sendingTelegramClipId != null) {
      return;
    }

    setState(() {
      _sendingTelegramClipId = item.id;
    });

    final isImg = item.isImage && item.imagePath != null;
    final initialMsg = isImg ? 'Sending image to Telegram... 0%' : 'Sending clip to Telegram...';
    _showNotification(initialMsg, ToastType.info, 0, isImg ? 0.0 : null);

    try {
      final result = await TelegramService.sendClip(
        botToken: token,
        chatId: channelId,
        item: item,
        onProgress: (sent, total, percent) {
          if (mounted && _sendingTelegramClipId == item.id) {
            final pctInt = (percent * 100).toInt().clamp(0, 100);
            final msg = percent >= 1.0
                ? 'Processing on Telegram...'
                : 'Sending image to Telegram... $pctInt%';
            _updateNotificationProgress(msg, percent);
          }
        },
      );

      if (result.success) {
        _showNotification(
          isImg ? 'Image sent to Telegram channel' : 'Clip sent to Telegram channel',
          ToastType.success,
          3500,
        );
      } else {
        _showNotification(
          result.error ?? 'Failed to send to Telegram',
          ToastType.error,
          5000,
        );
      }
    } catch (e) {
      _showNotification('Failed to send to Telegram: $e', ToastType.error, 5000);
    } finally {
      if (mounted) {
        setState(() {
          _sendingTelegramClipId = null;
        });
      }
    }
  }

  void _openAddDialog() {
    setState(() {
      _isDialogOpen = true;
    });

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Add Clip Dialog',
      barrierColor: Colors.black.withAlpha(190),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: _panelWidth,
            child: Center(
              child: AddClipDialog(
                isDark: widget.isDark,
                settings: _settings,
                onAdd: (title, content) {
                  _saveClipText(content, title.isEmpty ? null : title);
                },
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isDialogOpen = false;
        });
      }
    });
  }

  void _openEditDialog(ClipItem item) {
    setState(() {
      _isDialogOpen = true;
    });

    final itemIndex = _clips.indexWhere((c) => c.id == item.id);
    final serialNo = itemIndex >= 0 ? itemIndex + 1 : 1;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Edit Clip Dialog',
      barrierColor: Colors.black.withAlpha(190),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: _panelWidth,
            child: Center(
              child: EditClipDialog(
                isDark: widget.isDark,
                item: item,
                serialNo: serialNo,
                settings: _settings,
                onSave: (updatedTitle, updatedContent) {
                  setState(() {
                    final index = _clips.indexWhere((c) => c.id == item.id);
                    if (index >= 0) {
                      _clips[index].title = updatedTitle;
                      _clips[index].customTitle = updatedTitle.isNotEmpty ? updatedTitle : null;
                      _clips[index].content = updatedContent;
                      _clips[index].updatedAt = DateTime.now();
                      _applyFilter();
                    }
                  });
                  _persistClips();
                  _showNotification('Clip updated');
                },
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isDialogOpen = false;
        });
      }
    });
  }
  Future<void> _openSettingsDialog() async {
    setState(() {
      _isDialogOpen = true;
    });

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Settings Dialog',
      barrierColor: Colors.black.withAlpha(190),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: _panelWidth,
            child: Center(
              child: SettingsDialog(
                  isDark: widget.isDark,
                  clips: _clips.where((c) => !c.isDeleted).toList(),
                  settings: _settings,
                  onSettingsChanged: (updatedSettings) async {
                    setState(() {
                      _settings = updatedSettings;
                    });
                    await _persistSettings();
                    try {
                      await windowManager.setSize(Size(_totalWidth, _windowHeight));
                      final targetX = _isExpanded ? _visibleX : _hiddenX;
                      await windowManager.setPosition(Offset(targetX, _targetY));
                    } catch (_) {}
                  },
                  onRestoreBackup: (restoredSettings, restoredClips) async {
                    setState(() {
                      if (restoredSettings != null) {
                        _settings = restoredSettings;
                      }
                      if (restoredClips.isNotEmpty) {
                        _clips = restoredClips;
                      }
                      _applyFilter();
                    });
                    await _persistClips();
                    await _persistSettings();
                    try {
                      await windowManager.setSize(Size(_totalWidth, _windowHeight));
                      final targetX = _isExpanded ? _visibleX : _hiddenX;
                      await windowManager.setPosition(Offset(targetX, _targetY));
                    } catch (_) {}
                    _showNotification('Backup restored successfully');
                  },
                  onClearAll: () {
                    setState(() {
                      _clips.clear();
                      _applyFilter();
                    });
                    _persistClips();
                    _showNotification('All clips cleared');
                  },
                ),
              ),
            ),
          );
        },
      );

    if (mounted) {
      setState(() {
        _isDialogOpen = false;
      });
    }
  }

  Future<void> _importBackupFileDirectly() async {
    String? selectedPath;
    if (!kIsWeb && Platform.isWindows) {
      try {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          '''
Add-Type -AssemblyName System.Windows.Forms
\$ofd = New-Object System.Windows.Forms.OpenFileDialog
\$ofd.Filter = "JSON Backup (*.json)|*.json|Text files (*.*)|*.*"
\$ofd.Title = "Select Clip Dock Backup to Import"
if (\$ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  Write-Output \$ofd.FileName
}
''',
        ]);
        if (result.exitCode == 0) {
          final out = (result.stdout as String).trim();
          if (out.isNotEmpty && !out.contains('Error')) {
            selectedPath = out;
          }
        }
      } catch (_) {}
    }

    if (selectedPath != null && selectedPath.isNotEmpty) {
      try {
        final file = File(selectedPath);
        if (await file.exists()) {
          final content = await file.readAsString();
          final restored = DatabaseService.parseBackupJson(content);
          if (restored != null && (restored.clips.isNotEmpty || restored.settings != null)) {
            setState(() {
              if (restored.settings != null) {
                _settings = restored.settings!;
              }
              if (restored.clips.isNotEmpty) {
                _clips = restored.clips;
              }
              _settings.hasCompletedInitialSetup = true;
              _applyFilter();
            });
            await _persistClips();
            await _persistSettings();
            try {
              await windowManager.setSize(Size(_totalWidth, _windowHeight));
              final targetX = _isExpanded ? _visibleX : _hiddenX;
              await windowManager.setPosition(Offset(targetX, _targetY));
            } catch (_) {}
            _showNotification('Backup restored successfully');
            return;
          }
        }
      } catch (_) {}
    }
  }

  void _showFirstLaunchImportDialog() {
    setState(() {
      _isDialogOpen = true;
    });

    final isDark = widget.isDark;
    final bgAlpha = (_settings.opacity * 255).round().clamp(0, 255);
    final bgSurface = isDark
        ? Color.fromARGB(bgAlpha, 14, 14, 14)
        : Color.fromARGB(bgAlpha, 248, 250, 252);
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Welcome to Clip Dock',
      barrierColor: Colors.black.withAlpha(200),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: _panelWidth,
            child: Center(
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: bgSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(120),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDark ? AppColors.accentCyan : const Color(0xFF0284C7)).withAlpha(50),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.content_paste_rounded,
                                size: 26,
                                color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Welcome to Clip Dock',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Would you like to import an existing backup to restore your clips & settings, or start fresh?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color: subtextColor,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            // Left: Import Backup
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  Navigator.of(dialogCtx).pop();
                                  await _importBackupFileDirectly();
                                  setState(() {
                                    _settings.hasCompletedInitialSetup = true;
                                  });
                                  await _persistSettings();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.file_upload_outlined, size: 14),
                                label: const Text(
                                  'Import Backup',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Right: Start Fresh
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  Navigator.of(dialogCtx).pop();
                                  setState(() {
                                    _settings.hasCompletedInitialSetup = true;
                                  });
                                  await _persistSettings();
                                  _showNotification('Welcome to Clip Dock!');
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: BorderSide(color: borderColor),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  foregroundColor: textColor,
                                ),
                                child: Text(
                                  'Start Fresh',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: subtextColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isDialogOpen = false;
        });
      }
    });
  }

  Future<void> _openAboutDialog() async {
    setState(() {
      _isDialogOpen = true;
    });

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss About Dialog',
      barrierColor: Colors.black.withAlpha(190),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: _panelWidth,
            child: Center(
              child: AboutDialogWidget(
                isDark: widget.isDark,
                settings: _settings,
              ),
            ),
          ),
        );
      },
    );

    if (mounted) {
      setState(() {
        _isDialogOpen = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    final bgBase = isDark
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    // When transparency > 0, let the Windows acrylic show through
    // transparency 0 = fully opaque panel, transparency 1 = fully clear glass
    final int bgAlpha = ((1.0 - _settings.transparency) * 255).round().clamp(0, 255);
    final bgGlass = bgBase.withAlpha(bgAlpha);

    final handleColor = _settings.ribbonColor.withAlpha((_settings.ribbonOpacity * 255).round().clamp(0, 255));

    final allCount = _clips.where((c) => !c.isDeleted && !c.isAuto).length;
    final autoCount = _clips.where((c) => !c.isDeleted && c.isAuto).length;
    final starredCount = _clips.where((c) => !c.isDeleted && c.isStarred).length;
    final trashCount = _clips.where((c) => c.isDeleted).length;

    return Align(
      alignment: Alignment.topLeft,
      child: MouseRegion(
        onEnter: (_) => _onMouseEnterEdge(),
        onExit: (_) => _onMouseExitArea(),
        child: SizedBox(
          width: _totalWidth,
          height: _windowHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Main Drawer Panel Body (Adjustable width, with flat border)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _panelWidth,
                child: Opacity(
                  opacity: _settings.opacity.clamp(0.20, 1.0),
                  child: Container(
                      decoration: BoxDecoration(
                        color: bgGlass,
                        borderRadius: BorderRadius.zero,
                        border: Border(
                          right: BorderSide(
                            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            // Header Bar with Total Active Count
                            HeaderBar(
                              isDark: isDark,
                              isPinned: _isPinned,
                              totalClips: allCount,
                              onTogglePin: _togglePin,
                              onToggleTheme: widget.onToggleTheme,
                              onCollapse: _collapseManual,
                              onPaste: _pasteFromClipboard,
                              onAdd: _openAddDialog,
                              onMinimize: minimizeToTray,
                            ),

                            // Search & Actions Bar (Tabs [Clips, Starred, Auto, Trash] and Clear All / Empty button)
                            SearchFilterBar(
                              controller: _searchController,
                              isDark: isDark,
                              allCount: allCount,
                              autoCount: autoCount,
                              starredCount: starredCount,
                              trashCount: trashCount,
                              activeTab: _activeTab,
                              activeMediaFilter: _activeMediaFilter,
                              textCount: _clips.where((c) {
                                bool matchesTab = false;
                                switch (_activeTab) {
                                  case ClipTab.all: matchesTab = !c.isDeleted && !c.isAuto; break;
                                  case ClipTab.auto: matchesTab = !c.isDeleted && c.isAuto; break;
                                  case ClipTab.starred: matchesTab = !c.isDeleted && c.isStarred; break;
                                  case ClipTab.trash: matchesTab = c.isDeleted; break;
                                }
                                return matchesTab && !c.isImage;
                              }).length,
                              imageCount: _clips.where((c) {
                                bool matchesTab = false;
                                switch (_activeTab) {
                                  case ClipTab.all: matchesTab = !c.isDeleted && !c.isAuto; break;
                                  case ClipTab.auto: matchesTab = !c.isDeleted && c.isAuto; break;
                                  case ClipTab.starred: matchesTab = !c.isDeleted && c.isStarred; break;
                                  case ClipTab.trash: matchesTab = c.isDeleted; break;
                                }
                                return matchesTab && c.isImage;
                              }).length,
                              onTabChanged: (tab) {
                                setState(() {
                                  _activeTab = tab;
                                  final hasImages = _clips.any((c) {
                                    bool matchesTab = false;
                                    switch (tab) {
                                      case ClipTab.all: matchesTab = !c.isDeleted && !c.isAuto; break;
                                      case ClipTab.auto: matchesTab = !c.isDeleted && c.isAuto; break;
                                      case ClipTab.starred: matchesTab = !c.isDeleted && c.isStarred; break;
                                      case ClipTab.trash: matchesTab = c.isDeleted; break;
                                    }
                                    return matchesTab && c.isImage;
                                  });
                                  final hasText = _clips.any((c) {
                                    bool matchesTab = false;
                                    switch (tab) {
                                      case ClipTab.all: matchesTab = !c.isDeleted && !c.isAuto; break;
                                      case ClipTab.auto: matchesTab = !c.isDeleted && c.isAuto; break;
                                      case ClipTab.starred: matchesTab = !c.isDeleted && c.isStarred; break;
                                      case ClipTab.trash: matchesTab = c.isDeleted; break;
                                    }
                                    return matchesTab && !c.isImage;
                                  });
                                  if (_activeMediaFilter == MediaFilter.image && !hasImages) {
                                    _activeMediaFilter = MediaFilter.all;
                                  } else if (_activeMediaFilter == MediaFilter.text && !hasText) {
                                    _activeMediaFilter = MediaFilter.all;
                                  }
                                  _applyFilter();
                                });
                              },
                              onMediaFilterChanged: (filter) {
                                setState(() {
                                  _activeMediaFilter = filter;
                                  _applyFilter();
                                });
                              },
                              onChanged: _onSearchChanged,
                              onClear: _clearSearch,
                              onPaste: _pasteFromClipboard,
                              onEmptyTrash: _emptyTrash,
                              onClearAuto: _clearAutoClips,
                            ),

                            // Divider
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                            ),

                            // Clips List View
                            Expanded(
                              child: _filteredClips.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _activeTab == ClipTab.trash
                                                ? const Icon(
                                                    Icons.delete_outline_rounded,
                                                    size: 32,
                                                    color: Color(0xFFFB7185),
                                                  )
                                                : (_activeTab == ClipTab.auto
                                                    ? LightningBoltIcon(
                                                        size: 32,
                                                        color: isDark
                                                            ? AppColors.accentCyan.withAlpha(150)
                                                            : AppColors.accentCyan.withAlpha(180),
                                                      )
                                                    : Icon(
                                                        Icons.content_paste_outlined,
                                                        size: 32,
                                                        color: isDark
                                                            ? AppColors.darkTextSecondary.withAlpha(120)
                                                            : AppColors.lightTextSecondary.withAlpha(120),
                                                      )),
                                            const SizedBox(height: 10),
                                            Text(
                                              _activeTab == ClipTab.trash
                                                  ? 'Trash is empty.\nDeleted clips will appear here.'
                                                  : (_activeTab == ClipTab.auto
                                                      ? 'No auto-captured clips yet.\nCopy any text or image anywhere on your PC to auto-save it here.'
                                                      : (_activeTab == ClipTab.starred
                                                          ? 'No starred clips found.\nClick the star icon on any clip to pin it here.'
                                                          : (allCount == 0
                                                              ? 'No clips saved yet.\nClick "Paste" or "+ Add" to store clips.'
                                                              : 'No matching clips found.'))),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12,
                                                height: 1.4,
                                                color: isDark
                                                    ? AppColors.darkTextSecondary
                                                    : AppColors.lightTextSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      itemCount: _filteredClips.length,
                                      itemBuilder: (context, index) {
                                        final item = _filteredClips[index];
                                        final isTrash = _activeTab == ClipTab.trash;
                                        return ClipCard(
                                          key: ValueKey(item.id),
                                          serialNo: index + 1,
                                          item: item,
                                          isDark: isDark,
                                          isTrash: isTrash,
                                          isAuto: item.isAuto,
                                          displayLines: _settings.displayLines,
                                          clickRowToCopy: _settings.clickRowToCopy,
                                          clickRowToFill: _settings.clickRowToFill,
                                          showCopyButton: _settings.showCopyButton,
                                          dragToPaste: _settings.dragToPaste,
                                          isSendingTelegram: _sendingTelegramClipId == item.id,
                                          onCopy: () => _onCopyClip(item, index + 1),
                                          onNotify: (msg) {
                                            _lastMonitoredClipboard = item.content.trim();
                                            _showNotification(msg);
                                          },
                                          onEdit: isTrash ? null : () => _openEditDialog(item),
                                          onDelete: isTrash ? null : () => _deleteClip(item.id),
                                          onToggleStar: isTrash ? null : () => _toggleStar(item.id),
                                          onMoveToAll: isTrash ? null : () => _moveToAllTab(item),
                                          onRestore: isTrash ? () => _restoreClip(item.id) : null,
                                          onDeleteForever: isTrash ? () => _deletePermanently(item.id) : null,
                                          onSendTelegram: isTrash ? null : () => _sendClipToTelegram(item),
                                          onColorChanged: isTrash ? null : (colorHex) => _updateClipColor(item, colorHex),
                                        );
                                      },
                                    ),
                            ),

                            // Bottom Status and Settings Bar
                            Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF000000).withAlpha(230)
                                    : const Color(0xFFFFFFFF),
                                border: Border(
                                  top: BorderSide(
                                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Settings and About Buttons on Far Left
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Settings Button
                                      InkWell(
                                        onTap: _openSettingsDialog,
                                        borderRadius: BorderRadius.circular(5),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.settings_outlined,
                                                size: 13,
                                                color: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                'Settings',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 2),

                                      // About Button
                                      InkWell(
                                        onTap: _openAboutDialog,
                                        borderRadius: BorderRadius.circular(5),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.info_outline_rounded,
                                                size: 13,
                                                color: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                'About',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                // Status info on Far Right
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(
                                        _isPinned
                                            ? Icons.lock_outline_rounded
                                            : Icons.touch_app_outlined,
                                        size: 13,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          _isPinned
                                              ? 'Pinned: Always visible'
                                              : 'Touch left edge to open',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

              // 2. Ribbon Handle (Attached directly OUTSIDE on the right side of the panel)
              if (((_isExpanded && _settings.showRibbonWhenExpanded) ||
                      (!_isExpanded && _settings.showRibbonWhenCollapsed)) &&
                  _ribbonWidth > 0 &&
                  _settings.ribbonOpacity > 0.0)
                Positioned(
                  left: _panelWidth,
                  top: (1.0 - _settings.ribbonHeightPercent) * _windowHeight / 2,
                  height: _windowHeight * _settings.ribbonHeightPercent,
                  width: _ribbonWidth,
                  child: GestureDetector(
                    onTap: toggleDock,
                    child: Container(
                      decoration: BoxDecoration(
                        color: handleColor,
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Center(
                        child: CollapseChevronIcon(
                          color: isDark
                              ? AppColors.darkTextPrimary.withAlpha(200)
                              : AppColors.lightTextPrimary.withAlpha(200),
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Floating Toast Notification Chip
              if (_toastMessage != null)
                Positioned(
                  bottom: 40,
                  left: 20,
                  width: _panelWidth - 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _toastType == ToastType.error
                          ? (isDark ? const Color(0xFF450A0A) : const Color(0xFF7F1D1D)).withAlpha(240)
                          : (_toastType == ToastType.warning
                              ? (isDark ? const Color(0xFF291400) : const Color(0xFF451A03)).withAlpha(240)
                              : (_toastType == ToastType.info
                                  ? (isDark ? const Color(0xFF0B192C) : const Color(0xFF0F172A)).withAlpha(245)
                                  : (isDark ? const Color(0xFF052E16) : const Color(0xFF064E3B)).withAlpha(240))),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _toastType == ToastType.error
                            ? const Color(0xFFEF4444)
                            : (_toastType == ToastType.warning
                                ? AppColors.accentAmber
                                : (_toastType == ToastType.info
                                    ? const Color(0xFF2AABEE)
                                    : AppColors.accentEmerald)),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(80),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            if (_toastProgress != null && _toastProgress! < 1.0)
                              const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2AABEE)),
                                ),
                              )
                            else
                              Icon(
                                _toastType == ToastType.error
                                    ? Icons.error_outline_rounded
                                    : (_toastType == ToastType.warning
                                        ? Icons.warning_amber_rounded
                                        : (_toastType == ToastType.info
                                            ? Icons.info_outline_rounded
                                            : Icons.check_circle_rounded)),
                                color: _toastType == ToastType.error
                                    ? const Color(0xFFEF4444)
                                    : (_toastType == ToastType.warning
                                        ? AppColors.accentAmber
                                        : (_toastType == ToastType.info
                                            ? const Color(0xFF38BDF8)
                                            : AppColors.accentEmerald)),
                                size: 14,
                              ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                _toastMessage!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (_toastProgress != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2AABEE).withAlpha(50),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFF2AABEE).withAlpha(140),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  '${(_toastProgress! * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF38BDF8),
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                _toastTimer?.cancel();
                                setState(() {
                                  _toastMessage = null;
                                  _toastProgress = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 13,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_toastProgress != null) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: _toastProgress!.clamp(0.0, 1.0),
                              minHeight: 3.5,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2AABEE)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
