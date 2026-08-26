import 'dart:async';
import 'dart:io';
import 'dart:ui';
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

enum ToastType {
  success,
  warning,
  info,
}

class EdgeDockWidget extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const EdgeDockWidget({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<EdgeDockWidget> createState() => EdgeDockWidgetState();
}

class EdgeDockWidgetState extends State<EdgeDockWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<ClipItem> _clips = [];
  List<ClipItem> _filteredClips = [];

  DockSettings _settings = DockSettings();
  ClipTab _activeTab = ClipTab.all;

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

  static const double _panelWidth = 400.0;
  static const double _windowHeight = 680.0;
  double _targetY = 80.0;
  bool _isAnimating = false;

  double get _leftEdgeOffset => (Platform.isWindows ? -8.0 : 0.0) + _settings.edgeOffset;
  double get _ribbonWidth => _settings.ribbonWidth;
  double get _totalWidth => _panelWidth + _ribbonWidth;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndClips();
    _initScreenAndStart();
    _startClipboardMonitoring();
  }

  Future<void> _loadSettingsAndClips() async {
    final loadedSettings = await DatabaseService.loadSettings();
    final loadedClips = await DatabaseService.loadAllClips();
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
          final newTotalWidth = _panelWidth + _settings.ribbonWidth;
          await windowManager.setSize(Size(newTotalWidth, _windowHeight));
        }
      } catch (_) {}
    }
  }

  Future<void> _persistClips() async {
    await DatabaseService.saveAllClips(_clips);
  }

  Future<void> _persistSettings() async {
    _settings.isPinned = _isPinned;
    await DatabaseService.saveSettings(_settings);
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
    if (_isExpanded && !_isAnimating) return;

    setState(() {
      _isExpanded = true;
    });
    await _animateToX(_leftEdgeOffset);
  }

  Future<void> _collapseDock() async {
    if (_isPinned || _isDialogOpen) return;

    setState(() {
      _isExpanded = false;
    });
    final hiddenX = -_panelWidth + _leftEdgeOffset;
    await _animateToX(hiddenX);
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

  void _onMouseEnterEdge() {
    _autoHideTimer?.cancel();
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

  Future<void> _checkClipboardChanges() async {
    try {
      if (!_settings.autoCapture) return;
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return;

      if (text != _lastMonitoredClipboard) {
        _lastMonitoredClipboard = text;
        await _autoCaptureClip(text);
      }
    } catch (_) {}
  }

  Future<void> _autoCaptureClip(String text) async {
    final existingIndex = _clips.indexWhere((c) => c.content == text);
    if (existingIndex >= 0) {
      // Clip already exists, preserve its current position in the list
      return;
    }

    String title = text.replaceAll('\n', ' ').trim();
    if (title.length > 40) {
      title = '${title.substring(0, 40)}...';
    }

    final newClip = ClipItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: text,
      createdAt: DateTime.now(),
      isDeleted: false,
      isAuto: true,
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
      item.isAuto = false;
      item.updatedAt = DateTime.now();
      _applyFilter();
    });
    _persistClips();
    _showNotification('Moved clip to All tab');
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
        return matchesTab && clip.matchesSearch(query);
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

  void _showNotification(String message, [ToastType type = ToastType.success]) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _toastType = type;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  Future<void> _saveClipText(String text, [String? customTitle]) async {
    _lastMonitoredClipboard = text.trim();
    final existingIndex = _clips.indexWhere((c) => c.content == text);
    if (existingIndex >= 0) {
      final existing = _clips[existingIndex];
      if (existing.isDeleted) {
        existing.isDeleted = false;
        existing.deletedAt = null;
        if (customTitle != null && customTitle.isNotEmpty) {
          existing.title = customTitle;
        }
        setState(() {
          _applyFilter();
        });
        await _persistClips();
        _showNotification('Restored existing clip');
      } else {
        _showNotification('Clip already in library');
      }
      return;
    }

    String title = customTitle ?? text.replaceAll('\n', ' ').trim();
    if (title.length > 40) {
      title = '${title.substring(0, 40)}...';
    }

    final newClip = ClipItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: text,
      createdAt: DateTime.now(),
      isDeleted: false,
      isAuto: false,
    );

    setState(() {
      _clips.insert(0, newClip);
      _applyFilter();
    });

    await _persistClips();
    final activeCount = _clips.where((c) => !c.isDeleted && !c.isAuto).length;
    _showNotification('Saved clip #$activeCount');
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

  void _openAddDialog() {
    setState(() {
      _isDialogOpen = true;
    });

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Add Clip Dialog',
      barrierColor: Colors.black.withAlpha(120),
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
      barrierColor: Colors.black.withAlpha(120),
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
      barrierColor: Colors.black.withAlpha(120),
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
                    final newTotalWidth = _panelWidth + updatedSettings.ribbonWidth;
                    await windowManager.setSize(Size(newTotalWidth, _windowHeight));
                    final targetX = _isExpanded ? _leftEdgeOffset : (-_panelWidth + _leftEdgeOffset);
                    await windowManager.setPosition(Offset(targetX, _targetY));
                  } catch (_) {}
                },
                onImportClips: (imported) {
                  setState(() {
                    final existingContents = _clips.map((c) => c.content).toSet();
                    final newUniqueClips = imported.where((c) => !existingContents.contains(c.content)).toList();
                    _clips.insertAll(0, newUniqueClips);
                    _applyFilter();
                  });
                  _persistClips();
                  _showNotification('Imported ${imported.length} clips');
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

  Future<void> _openAboutDialog() async {
    setState(() {
      _isDialogOpen = true;
    });

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss About Dialog',
      barrierColor: Colors.black.withAlpha(120),
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
        : const Color(0xFFF8FAFC);
    final bgGlass = bgBase.withAlpha((_settings.opacity * 255).round().clamp(20, 255));

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
              // 1. Main Drawer Panel Body (Fixed 400px wide, with rounded right corners)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _panelWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _settings.blur,
                      sigmaY: _settings.blur,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onSecondaryTap: () {
                        if (_settings.rightClickToPaste) {
                          _pasteFromClipboard();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgGlass,
                          borderRadius: BorderRadius.zero,
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
                              onAdd: _openAddDialog,
                            ),

                            // Search & Actions Bar (Tabs [All, Auto, Starred, Trash] and Paste / Empty button)
                            SearchFilterBar(
                              controller: _searchController,
                              isDark: isDark,
                              allCount: allCount,
                              autoCount: autoCount,
                              starredCount: starredCount,
                              trashCount: trashCount,
                              activeTab: _activeTab,
                              onTabChanged: (tab) {
                                setState(() {
                                  _activeTab = tab;
                                  _applyFilter();
                                });
                              },
                              onChanged: _onSearchChanged,
                              onClear: _clearSearch,
                              onPaste: _pasteFromClipboard,
                              onEmptyTrash: _emptyTrash,
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
                                                      ? 'No auto-captured clips yet.\nCopy any text anywhere on your PC to auto-save it here.'
                                                      : (_activeTab == ClipTab.starred
                                                          ? 'No starred clips found.\nClick the star icon on any clip to pin it here.'
                                                          : (allCount == 0
                                                              ? 'No manual clips saved yet.\nClick "Paste" or "+ Add" to store clips.'
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
                                          clickRowToCopy: _settings.clickRowToCopy,
                                          showCopyButton: _settings.showCopyButton,
                                          dragToPaste: _settings.dragToPaste,
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
                                    : const Color(0xFFF1F5F9).withAlpha(200),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _toastType == ToastType.warning
                          ? (isDark ? const Color(0xFF291400) : const Color(0xFF451A03)).withAlpha(240)
                          : (_toastType == ToastType.info
                              ? (isDark ? const Color(0xFF000000) : const Color(0xFF0F172A)).withAlpha(240)
                              : (isDark ? const Color(0xFF052E16) : const Color(0xFF064E3B)).withAlpha(240)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _toastType == ToastType.warning
                            ? AppColors.accentAmber
                            : (_toastType == ToastType.info
                                ? AppColors.accentSilver
                                : AppColors.accentEmerald),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _toastType == ToastType.warning
                              ? Icons.warning_amber_rounded
                              : (_toastType == ToastType.info
                                  ? Icons.info_outline_rounded
                                  : Icons.check_circle_rounded),
                          color: _toastType == ToastType.warning
                              ? AppColors.accentAmber
                              : (_toastType == ToastType.info
                                  ? AppColors.accentSilver
                                  : AppColors.accentEmerald),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
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
