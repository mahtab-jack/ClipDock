import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';
import 'widgets/edge_dock_widget.dart';

final GlobalKey<EdgeDockWidgetState> dockKey = GlobalKey<EdgeDockWidgetState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    const double windowWidth = 424.0;
    const double windowHeight = 680.0;
    final double leftEdgeOffset = Platform.isWindows ? -8.0 : 0.0;

    const WindowOptions windowOptions = WindowOptions(
      size: Size(windowWidth, windowHeight),
      minimumSize: Size(320.0, windowHeight),
      maximumSize: Size(1200.0, windowHeight),
      center: false,
      backgroundColor: Colors.transparent,
      skipTaskbar: true, // Hidden from Windows Taskbar and Alt+Tab
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: true,
      title: 'Clip Dock',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      try {
        final Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
        final double screenHeight = primaryDisplay.size.height;
        final double targetY = ((screenHeight - windowHeight) / 2).clamp(20.0, screenHeight - windowHeight);
        await windowManager.setPosition(Offset(leftEdgeOffset, targetY));
      } catch (_) {
        await windowManager.setPosition(Offset(leftEdgeOffset, 80));
      }

      await windowManager.setSize(const Size(windowWidth, windowHeight));
      await windowManager.setMinimumSize(const Size(320.0, windowHeight));
      await windowManager.setMaximumSize(const Size(1200.0, windowHeight));
      await windowManager.setMovable(false);
      await windowManager.setResizable(false);
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true); // Don't show in taskbar
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ClipDockApp());
}

class ClipDockApp extends StatefulWidget {
  const ClipDockApp({super.key});

  @override
  State<ClipDockApp> createState() => _ClipDockAppState();
}

class _ClipDockAppState extends State<ClipDockApp> with TrayListener, WindowListener {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isWindowVisible = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      _initSystemTray();
    }
  }

  Future<void> _loadTheme() async {
    final settings = await DatabaseService.loadSettings();
    if (mounted) {
      setState(() {
        _themeMode = settings.isDark ? ThemeMode.dark : ThemeMode.light;
      });
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _initSystemTray() async {
    try {
      String iconPath = 'assets/app_icon.ico';
      if (Platform.isWindows) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final candidates = [
          '$exeDir\\app_icon.ico',
          '$exeDir\\data\\flutter_assets\\assets\\app_icon.ico',
          '$exeDir\\assets\\app_icon.ico',
          '$exeDir\\app_icon.png',
          r'c:\Users\mahta\Desktop\antigravity\Cnote\assets\app_icon.ico',
          r'c:\Users\mahta\Desktop\antigravity\Cnote\windows\runner\resources\app_icon.ico',
        ];
        for (final candidate in candidates) {
          if (File(candidate).existsSync()) {
            iconPath = candidate;
            break;
          }
        }
      }

      await trayManager.setIcon(iconPath);
      await _updateTrayMenu();
      await trayManager.setToolTip('Clip Dock');
    } catch (_) {}
  }

  Future<void> _updateTrayMenu() async {
    try {
      final isPinned = dockKey.currentState?.isPinned ?? false;
      final Menu menu = Menu(
        items: [
          if (_isWindowVisible)
            MenuItem(
              key: 'hide_dock',
              label: 'Hide / Minimize Clip Dock',
            )
          else
            MenuItem(
              key: 'show_dock',
              label: 'Show / Open Clip Dock',
            ),
          MenuItem(
            key: 'quick_add',
            label: 'Quick Add Clip (+)',
          ),
          MenuItem(
            key: 'toggle_pin',
            label: isPinned ? 'Unpin Dock (Auto-Hide)' : 'Pin Dock (Keep Open)',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'settings',
            label: 'Settings',
          ),
          MenuItem(
            key: 'about',
            label: 'About Clip Dock',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Quit Clip Dock',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (_) {}
  }

  Future<void> _minimizeWindow() async {
    setState(() {
      _isWindowVisible = false;
    });
    try {
      await windowManager.hide();
      await _updateTrayMenu();
    } catch (_) {}
  }

  Future<void> _showWindow() async {
    setState(() {
      _isWindowVisible = true;
    });
    try {
      await windowManager.show();
      await windowManager.focus();
      await _updateTrayMenu();
      dockKey.currentState?.expandDockFromTray();
    } catch (_) {}
  }

  @override
  void onWindowMinimize() {
    _minimizeWindow();
  }

  @override
  void onWindowRestore() {
    setState(() {
      _isWindowVisible = true;
    });
    _updateTrayMenu();
  }

  @override
  void onTrayIconMouseDown() async {
    if (!_isWindowVisible) {
      await _showWindow();
    } else {
      dockKey.currentState?.toggleDock();
    }
  }

  @override
  void onTrayIconRightMouseDown() async {
    await _updateTrayMenu();
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_dock':
        await _showWindow();
        break;
      case 'hide_dock':
        await _minimizeWindow();
        break;
      case 'quick_add':
        _isWindowVisible = true;
        await windowManager.show();
        await windowManager.focus();
        await _updateTrayMenu();
        dockKey.currentState?.expandDockAndAddClip();
        break;
      case 'toggle_pin':
        _isWindowVisible = true;
        await windowManager.show();
        await windowManager.focus();
        dockKey.currentState?.togglePinFromTray();
        await _updateTrayMenu();
        break;
      case 'settings':
        _isWindowVisible = true;
        await windowManager.show();
        await windowManager.focus();
        await _updateTrayMenu();
        dockKey.currentState?.openSettingsFromTray();
        break;
      case 'about':
        _isWindowVisible = true;
        await windowManager.show();
        await windowManager.focus();
        await _updateTrayMenu();
        dockKey.currentState?.openAboutFromTray();
        break;
      case 'exit_app':
        await windowManager.close();
        break;
    }
  }

  void _toggleTheme() async {
    final newMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() {
      _themeMode = newMode;
    });
    final isDark = newMode == ThemeMode.dark;
    final settings = await DatabaseService.loadSettings();
    settings.isDark = isDark;
    if (settings.autoRibbonColor) {
      settings.ribbonColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    }
    await DatabaseService.saveSettings(settings);
    dockKey.currentState?.updateSettingsFromExternal(settings);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeMode == ThemeMode.dark;

    return MaterialApp(
      title: 'Clip Dock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: EdgeDockWidget(
          key: dockKey,
          isDark: isDark,
          onToggleTheme: _toggleTheme,
          onMinimize: _minimizeWindow,
        ),
      ),
    );
  }
}
