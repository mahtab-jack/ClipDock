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
      minimumSize: Size(400.0, windowHeight),
      maximumSize: Size(450.0, windowHeight),
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
      await windowManager.setMinimumSize(const Size(400.0, windowHeight));
      await windowManager.setMaximumSize(const Size(450.0, windowHeight));
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

class _ClipDockAppState extends State<ClipDockApp> with TrayListener {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
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
      final Menu menu = Menu(
        items: [
          MenuItem(
            key: 'maximize_minimize',
            label: 'Maximize/Minimize',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Exit',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
      await trayManager.setToolTip('Clip Dock');
    } catch (_) {}
  }

  @override
  void onTrayIconMouseDown() {
    dockKey.currentState?.toggleDock();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'maximize_minimize') {
      try {
        final isMinimized = await windowManager.isMinimized();
        if (isMinimized) {
          await windowManager.restore();
          await windowManager.show();
          await windowManager.focus();
        } else {
          await windowManager.minimize();
        }
      } catch (_) {}
    } else if (menuItem.key == 'exit_app') {
      windowManager.close();
    }
  }

  void _toggleTheme() async {
    final newMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() {
      _themeMode = newMode;
    });
    final settings = await DatabaseService.loadSettings();
    settings.isDark = newMode == ThemeMode.dark;
    await DatabaseService.saveSettings(settings);
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
        ),
      ),
    );
  }
}
