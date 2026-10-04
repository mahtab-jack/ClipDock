import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/clip_item.dart';
import '../models/dock_settings.dart';
import '../services/database_service.dart';
import '../services/startup_service.dart';
import '../services/telegram_service.dart';
import '../theme/app_theme.dart';
import 'telegram_icon.dart';

class SettingsDialog extends StatefulWidget {
  final bool isDark;
  final List<ClipItem> clips;
  final DockSettings settings;
  final Function(DockSettings updatedSettings) onSettingsChanged;
  final Function(DockSettings? restoredSettings, List<ClipItem> restoredClips) onRestoreBackup;
  final VoidCallback onClearAll;

  const SettingsDialog({
    super.key,
    required this.isDark,
    required this.clips,
    required this.settings,
    required this.onSettingsChanged,
    required this.onRestoreBackup,
    required this.onClearAll,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final TextEditingController _importController = TextEditingController();
  final TextEditingController _hexController = TextEditingController();
  late final TextEditingController _maxCharsController;
  late final TextEditingController _telegramTokenController;
  late final TextEditingController _telegramChannelController;
  bool _isImporting = false;
  bool _launchOnStartup = false;
  bool _isLoadingStartup = true;
  String? _statusMessage;
  bool _isTestingTelegram = false;
  String? _telegramTestResult;
  bool _telegramTestSuccess = false;
  bool _obscureTelegramToken = true;

  late DockSettings _currentSettings;

  static const List<_ColorOption> _themePresetColors = [
    _ColorOption(Color(0xFFCBD5E1), 'Auto (Theme Default)', isAuto: true),
    _ColorOption(Color(0xFFFFFFFF), 'Light Mode (White)', isLight: true),
    _ColorOption(Color(0xFF000000), 'AMOLED Pitch Black'),
  ];

  static const List<_ColorOption> _solidColors = [
    _ColorOption(Color(0xFF38BDF8), 'Cyan Blue'),
    _ColorOption(Color(0xFF10B981), 'Emerald Green'),
    _ColorOption(Color(0xFFF43F5E), 'Rose Crimson'),
    _ColorOption(Color(0xFFF59E0B), 'Amber Gold'),
    _ColorOption(Color(0xFFA855F7), 'Vivid Purple'),
    _ColorOption(Color(0xFF2563EB), 'Royal Blue'),
    _ColorOption(Color(0xFFEF4444), 'Ruby Red'),
    _ColorOption(Color(0xFFF97316), 'Tangerine Orange'),
    _ColorOption(Color(0xFF14B8A6), 'Teal Ocean'),
    _ColorOption(Color(0xFF84CC16), 'Lime Accent'),
    _ColorOption(Color(0xFF6366F1), 'Indigo Neon'),
    _ColorOption(Color(0xFFD946EF), 'Fuchsia Glow'),
  ];

  static const List<_ColorOption> _softPastelColors = [
    _ColorOption(Color(0xFFDDD6FE), 'Soft Lavender'),
    _ColorOption(Color(0xFFBAE6FD), 'Soft Ice Blue'),
    _ColorOption(Color(0xFFA7F3D0), 'Soft Mint'),
    _ColorOption(Color(0xFFFECDD3), 'Soft Blush'),
    _ColorOption(Color(0xFFFED7AA), 'Soft Peach'),
    _ColorOption(Color(0xFFFEF08A), 'Soft Sand'),
    _ColorOption(Color(0xFFCBD5E1), 'Soft Slate Silver'),
    _ColorOption(Color(0xFFE9D5FF), 'Pale Mauve'),
    _ColorOption(Color(0xFF99F6E4), 'Soft Aqua'),
    _ColorOption(Color(0xFFFBCFE8), 'Muted Pink'),
    _ColorOption(Color(0xFFE2E8F0), 'Cool Gray'),
    _ColorOption(Color(0xFFE7E5E4), 'Warm Stone'),
  ];

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.settings.copyWith();
    _hexController.text = _colorToHex(_currentSettings.ribbonColor);
    _maxCharsController = TextEditingController(text: _currentSettings.maxAutoChars.toString());
    _telegramTokenController = TextEditingController(text: _currentSettings.telegramBotToken);
    _telegramChannelController = TextEditingController(text: _currentSettings.telegramChannelId);
    _loadStartupState();
  }

  String _colorToHex(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  }

  Color? _hexToColor(String hex) {
    String cleanHex = hex.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      final intVal = int.tryParse('FF$cleanHex', radix: 16);
      if (intVal != null) {
        return Color(intVal);
      }
    }
    return null;
  }

  Future<void> _loadStartupState() async {
    final enabled = await StartupService.isLaunchOnStartupEnabled();
    if (mounted) {
      setState(() {
        _launchOnStartup = enabled;
        _isLoadingStartup = false;
      });
    }
  }

  Future<void> _toggleStartup(bool value) async {
    setState(() {
      _isLoadingStartup = true;
    });
    final success = await StartupService.setLaunchOnStartup(value);
    if (mounted) {
      setState(() {
        _isLoadingStartup = false;
        if (success) {
          _launchOnStartup = value;
          _statusMessage = value
              ? 'Added to Windows startup'
              : 'Removed from Windows startup';
        } else {
          _statusMessage = 'Could not update startup setting';
        }
      });
    }
  }

  void _updateSettings(DockSettings updated) {
    setState(() {
      _currentSettings = updated;
    });
    widget.onSettingsChanged(updated);
  }

  Future<void> _testTelegramConnection() async {
    final token = _telegramTokenController.text.trim();
    final channelId = _telegramChannelController.text.trim();

    if (token.isEmpty) {
      setState(() {
        _telegramTestSuccess = false;
        _telegramTestResult = 'Please enter a Telegram Bot Token first';
      });
      return;
    }

    setState(() {
      _isTestingTelegram = true;
      _telegramTestResult = null;
    });

    final res = await TelegramService.testConnection(
      botToken: token,
      chatId: channelId,
    );

    if (mounted) {
      setState(() {
        _isTestingTelegram = false;
        _telegramTestSuccess = res.success;
        if (res.success) {
          _telegramTestResult = channelId.isNotEmpty
              ? 'Verified @${res.botName ?? "bot"} and delivered test message to channel.'
              : 'Bot token verified (@${res.botName ?? "bot"}). Channel ID was not set.';
        } else {
          _telegramTestResult = res.error ?? 'Connection test failed';
        }
      });
    }
  }

  @override
  void dispose() {
    _importController.dispose();
    _hexController.dispose();
    _maxCharsController.dispose();
    _telegramTokenController.dispose();
    _telegramChannelController.dispose();
    super.dispose();
  }

  Future<void> _exportBackup() async {
    final fileName = 'ClipDock-Backup-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}.json';
    final jsonStr = DatabaseService.createBackupJsonString(_currentSettings, widget.clips);

    String? savePath;
    if (!kIsWeb && Platform.isWindows) {
      try {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          '''
Add-Type -AssemblyName System.Windows.Forms
\$sfd = New-Object System.Windows.Forms.SaveFileDialog
\$sfd.Filter = "JSON Backup (*.json)|*.json|All files (*.*)|*.*"
\$sfd.FileName = "$fileName"
\$sfd.Title = "Export Clip Dock Backup"
if (\$sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  Write-Output \$sfd.FileName
}
''',
        ]);
        if (result.exitCode == 0) {
          final out = (result.stdout as String).trim();
          if (out.isNotEmpty && !out.contains('Error')) {
            savePath = out;
          }
        }
      } catch (_) {}
    }

    if (savePath == null || savePath.isEmpty) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      final downloadsDir = Directory('$userProfile\\Downloads');
      if (downloadsDir.existsSync()) {
        savePath = '$userProfile\\Downloads\\$fileName';
      } else {
        savePath = fileName;
      }
    }

    try {
      final file = File(savePath);
      await file.writeAsString(jsonStr);
      Clipboard.setData(ClipboardData(text: jsonStr));
      final shortName = savePath.split('\\').last;
      if (mounted) {
        setState(() {
          _statusMessage = 'Backup saved to $shortName';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to write backup file';
        });
      }
    }
  }

  Future<void> _importBackupFromFile() async {
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
\$ofd.Filter = "JSON Backup (*.json)|*.json|Text files (*.txt)|*.txt|All files (*.*)|*.*"
\$ofd.Title = "Import Clip Dock Backup"
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
          _processImportContent(content);
          return;
        }
      } catch (_) {}
    }

    setState(() {
      _isImporting = !_isImporting;
      _statusMessage = _isImporting ? 'Paste backup JSON string below' : null;
    });
  }

  void _processImportContent(String raw) {
    final restored = DatabaseService.parseBackupJson(raw);
    if (restored != null && (restored.clips.isNotEmpty || restored.settings != null)) {
      if (restored.settings != null) {
        setState(() {
          _currentSettings = restored.settings!;
          _hexController.text = _colorToHex(_currentSettings.ribbonColor);
        });
      }
      widget.onRestoreBackup(restored.settings, restored.clips);
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _statusMessage = 'Could not parse backup data';
    });
  }

  void _handleManualImport() {
    final raw = _importController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _statusMessage = 'Paste backup JSON string into the box';
      });
      return;
    }
    _processImportContent(raw);
  }

  void _openBackupFolder() {
    DatabaseService.openBackupFolder();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgSurface = isDark
        ? const Color(0xF5141414)
        : const Color(0xF5F8FAFC);
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFFFFFFF);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(16),
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
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: isDark ? AppColors.accentSilver : AppColors.lightTextPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Settings & Customization',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
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
                const SizedBox(height: 10),

                // Scrollable Settings Sections (Scrollbar hidden, scrolling functional)
                Flexible(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Section 1: Glass & Appearance
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Glass & Appearance',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                              ),
                              const SizedBox(height: 8),

                              // Panel Material Style Dropdown
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Panel Material Style', style: TextStyle(fontSize: 10.5, color: subtextColor)),
                                  Text(
                                    _currentSettings.materialStyle == 'acrylic' ? 'Acrylic' : 'Default',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: _currentSettings.materialStyle == 'acrylic'
                                          ? (isDark ? AppColors.accentCyan : const Color(0xFF0284C7))
                                          : textColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _currentSettings.materialStyle,
                                    isExpanded: true,
                                    dropdownColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: subtextColor),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'default',
                                        child: Text(
                                          'Default (Solid Matte - All Windows)',
                                          style: TextStyle(fontSize: 11, color: textColor),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'acrylic',
                                        child: Text(
                                          'Acrylic (Native Desktop Blur - Win 11)',
                                          style: TextStyle(fontSize: 11, color: textColor),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        _updateSettings(_currentSettings.copyWith(materialStyle: val));
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Panel Width Slider
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Panel Width', style: TextStyle(fontSize: 10.5, color: subtextColor)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                    ),
                                    child: Text(
                                      '${_currentSettings.panelWidth.round()} px',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _currentSettings.panelWidth == 400.0
                                            ? subtextColor
                                            : (isDark ? AppColors.accentCyan : const Color(0xFF0284C7)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  // [-] Step Button (-10px, long press -25px)
                                  Tooltip(
                                    message: 'Decrease 10px (Long press 25px)',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          final newVal = (_currentSettings.panelWidth - 10.0).clamp(320.0, 600.0);
                                          _updateSettings(_currentSettings.copyWith(panelWidth: newVal));
                                        },
                                        onLongPress: () {
                                          final newVal = (_currentSettings.panelWidth - 25.0).clamp(320.0, 600.0);
                                          _updateSettings(_currentSettings.copyWith(panelWidth: newVal));
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                          ),
                                          child: Text(
                                            '-',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Slider (320 to 600 px)
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      ),
                                      child: Slider(
                                        value: _currentSettings.panelWidth,
                                        min: 320.0,
                                        max: 600.0,
                                        divisions: 28,
                                        activeColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                        onChanged: (val) {
                                          _updateSettings(_currentSettings.copyWith(panelWidth: val.roundToDouble()));
                                        },
                                      ),
                                    ),
                                  ),

                                  // [+] Step Button (+10px, long press +25px)
                                  Tooltip(
                                    message: 'Increase 10px (Long press 25px)',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          final newVal = (_currentSettings.panelWidth + 10.0).clamp(320.0, 600.0);
                                          _updateSettings(_currentSettings.copyWith(panelWidth: newVal));
                                        },
                                        onLongPress: () {
                                          final newVal = (_currentSettings.panelWidth + 25.0).clamp(320.0, 600.0);
                                          _updateSettings(_currentSettings.copyWith(panelWidth: newVal));
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                          ),
                                          child: Text(
                                            '+',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Reset Button if non-default
                                  if (_currentSettings.panelWidth != 400.0) ...[
                                    const SizedBox(width: 6),
                                    Tooltip(
                                      message: 'Reset to 400 px',
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            _updateSettings(_currentSettings.copyWith(panelWidth: 400.0));
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                            ),
                                            child: Text(
                                              'Reset',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: subtextColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Section 2: Clipboard & Interaction Behavior
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Clipboard & Interaction Behavior',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                              ),
                              const SizedBox(height: 8),

                              // Auto-capture toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Auto-capture clipboard',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                                    ),
                                  ),
                                  Switch(
                                    value: _currentSettings.autoCapture,
                                    activeThumbColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                    onChanged: (val) {
                                      _updateSettings(_currentSettings.copyWith(autoCapture: val));
                                    },
                                  ),
                                ],
                              ),

                              // Max chars setting (for auto clips only)
                              if (_currentSettings.autoCapture) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.black.withAlpha(50) : Colors.black.withAlpha(10),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Max chars (Auto-capture)',
                                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 76,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(
                                                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: TextField(
                                              controller: _maxCharsController,
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                              ),
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              onChanged: (val) {
                                                final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                                                if (parsed != null && parsed > 0) {
                                                  _updateSettings(_currentSettings.copyWith(maxAutoChars: parsed));
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        children: [5000, 15000, 50000, 100000].map((count) {
                                          final isSelected = _currentSettings.maxAutoChars == count;
                                          return InkWell(
                                            onTap: () {
                                              _maxCharsController.text = count.toString();
                                              _updateSettings(_currentSettings.copyWith(maxAutoChars: count));
                                            },
                                            borderRadius: BorderRadius.circular(4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? (isDark ? AppColors.accentCyan.withAlpha(45) : const Color(0xFF0284C7).withAlpha(35))
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? (isDark ? AppColors.accentCyan : const Color(0xFF0284C7))
                                                      : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                count == 15000 ? '15k (Default)' : 'k',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                  color: isSelected
                                                      ? (isDark ? AppColors.accentCyan : const Color(0xFF0284C7))
                                                      : subtextColor,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),

                              // Auto clips retention
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Auto clips retention',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      {'label': '1d', 'days': 1},
                                      {'label': '3d', 'days': 3},
                                      {'label': '7d', 'days': 7},
                                      {'label': '14d', 'days': 14},
                                      {'label': '30d', 'days': 30},
                                      {'label': 'Never', 'days': 0},
                                    ].map((opt) {
                                      final isSelected = _currentSettings.autoClipsRetentionDays == opt['days'];
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 3),
                                        child: InkWell(
                                          onTap: () {
                                            _updateSettings(_currentSettings.copyWith(autoClipsRetentionDays: opt['days'] as int));
                                          },
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? (isDark ? AppColors.accentCyan.withAlpha(45) : const Color(0xFF0284C7).withAlpha(35))
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isSelected
                                                    ? (isDark ? AppColors.accentCyan : const Color(0xFF0284C7))
                                                    : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              opt['label'] as String,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                color: isSelected
                                                    ? (isDark ? AppColors.accentCyan : const Color(0xFF0284C7))
                                                    : textColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Trash retention
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Trash retention',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      {'label': '1d', 'days': 1},
                                      {'label': '3d', 'days': 3},
                                      {'label': '7d', 'days': 7},
                                      {'label': '14d', 'days': 14},
                                      {'label': '30d', 'days': 30},
                                      {'label': 'Never', 'days': 0},
                                    ].map((opt) {
                                      final isSelected = _currentSettings.trashRetentionDays == opt['days'];
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 3),
                                        child: InkWell(
                                          onTap: () {
                                            _updateSettings(_currentSettings.copyWith(trashRetentionDays: opt['days'] as int));
                                          },
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? (isDark ? AppColors.accentCyan.withAlpha(45) : const Color(0xFF0284C7).withAlpha(35))
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isSelected
                                                    ? (isDark ? AppColors.accentCyan : const Color(0xFF0284C7))
                                                    : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              opt['label'] as String,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                color: isSelected
                                                    ? (isDark ? AppColors.accentCyan : const Color(0xFF0284C7))
                                                    : textColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Clip row lines option (1 to 6)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Clip row lines',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [1, 2, 3, 4, 5, 6].map((lines) {
                                      final isSelected = _currentSettings.displayLines == lines;
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: InkWell(
                                          onTap: () {
                                            _updateSettings(_currentSettings.copyWith(displayLines: lines));
                                          },
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            width: 24,
                                            height: 22,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? (isDark ? AppColors.accentCyan.withAlpha(45) : const Color(0xFF0284C7).withAlpha(35))
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isSelected
                                                    ? (isDark ? AppColors.accentCyan : const Color(0xFF0284C7))
                                                    : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              '$lines',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                color: isSelected
                                                    ? (isDark ? AppColors.accentCyan : const Color(0xFF0284C7))
                                                    : textColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Click row to fill toggle (mutually exclusive with Click row to copy)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Click row to fill',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                                    ),
                                  ),
                                  Switch(
                                    value: _currentSettings.clickRowToFill,
                                    activeThumbColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                    onChanged: (val) {
                                      _updateSettings(_currentSettings.copyWith(
                                        clickRowToFill: val,
                                        clickRowToCopy: val ? false : _currentSettings.clickRowToCopy,
                                      ));
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Click row to copy toggle (mutually exclusive with Click row to fill)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Click row to copy',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                                    ),
                                  ),
                                  Switch(
                                    value: _currentSettings.clickRowToCopy,
                                    activeThumbColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                    onChanged: (val) {
                                      _updateSettings(_currentSettings.copyWith(
                                        clickRowToCopy: val,
                                        clickRowToFill: val ? false : _currentSettings.clickRowToFill,
                                      ));
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Show copy button toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Show copy button',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: _currentSettings.clickRowToCopy ? textColor : subtextColor,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: !_currentSettings.clickRowToCopy || _currentSettings.showCopyButton,
                                    activeThumbColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                    onChanged: _currentSettings.clickRowToCopy
                                        ? (val) {
                                            _updateSettings(_currentSettings.copyWith(showCopyButton: val));
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Section 3: Dock Position & Screen Edge Alignment (Separate Sliders for Visible and Hidden States)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Position & Edge Alignment',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                              ),
                              const SizedBox(height: 8),

                              // Slider 1: Visible Position (When Opened)
                              _buildOffsetSliderSection(
                                context: context,
                                isDark: isDark,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                title: 'Visible Position (Open)',
                                subtitle: '',
                                value: _currentSettings.edgeOffsetVisible,
                                onChanged: (val) {
                                  _updateSettings(_currentSettings.copyWith(edgeOffsetVisible: val));
                                },
                                onReset: () {
                                  _updateSettings(_currentSettings.copyWith(edgeOffsetVisible: 0.0));
                                },
                              ),

                              const SizedBox(height: 10),
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                              ),
                              const SizedBox(height: 10),

                              // Slider 2: Hidden Position (When Closed)
                              _buildOffsetSliderSection(
                                context: context,
                                isDark: isDark,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                title: 'Hidden Position (Closed)',
                                subtitle: '',
                                value: _currentSettings.edgeOffsetHidden,
                                onChanged: (val) {
                                  _updateSettings(_currentSettings.copyWith(edgeOffsetHidden: val));
                                },
                                onReset: () {
                                  _updateSettings(_currentSettings.copyWith(edgeOffsetHidden: 0.0));
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Section 3: Edge Ribbon / Handle Customization
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edge Ribbon Customization',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                              ),
                              const SizedBox(height: 8),

                              // Show Ribbon When Collapsed
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Show ribbon when hidden', style: TextStyle(fontSize: 10.5, color: subtextColor)),
                                  Switch(
                                    value: _currentSettings.showRibbonWhenCollapsed,
                                    activeThumbColor: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                                    onChanged: (val) {
                                      _updateSettings(_currentSettings.copyWith(showRibbonWhenCollapsed: val));
                                    },
                                  ),
                                ],
                              ),

                              // Show Ribbon When Expanded
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Show ribbon when open', style: TextStyle(fontSize: 10.5, color: subtextColor)),
                                  Switch(
                                    value: _currentSettings.showRibbonWhenExpanded,
                                    activeThumbColor: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                                    onChanged: (val) {
                                      _updateSettings(_currentSettings.copyWith(showRibbonWhenExpanded: val));
                                    },
                                  ),
                                ],
                              ),

                              // Ribbon Opacity / Transparency Slider
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Ribbon Opacity', style: TextStyle(fontSize: 10.5, color: subtextColor)),
                                  Text('${(_currentSettings.ribbonOpacity * 100).round()}%',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: textColor)),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: _currentSettings.ribbonOpacity,
                                  min: 0.0,
                                  max: 1.0,
                                  divisions: 20,
                                  activeColor: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                                  onChanged: (val) {
                                    _updateSettings(_currentSettings.copyWith(ribbonOpacity: val));
                                  },
                                ),
                              ),

                              // Ribbon Height Slider
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Ribbon Height', style: TextStyle(fontSize: 10.5, color: subtextColor)),
                                  Text('${(_currentSettings.ribbonHeightPercent * 100).round()}%',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: textColor)),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: _currentSettings.ribbonHeightPercent,
                                  min: 0.20,
                                  max: 1.0,
                                  divisions: 16,
                                  activeColor: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                                  onChanged: (val) {
                                    _updateSettings(_currentSettings.copyWith(ribbonHeightPercent: val));
                                  },
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Ribbon Color: Clickable Selected Color Dot + HEX Input in One Line
                              Text('Ribbon Color', style: TextStyle(fontSize: 10.5, color: subtextColor)),
                              const SizedBox(height: 6),
                              Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                ),
                                child: Row(
                                  children: [
                                    // Clickable Selected Color Circle (Opens Modal)
                                    Tooltip(
                                      message: 'Click to choose color from palette',
                                      child: InkWell(
                                        onTap: _openColorPaletteModal,
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: _currentSettings.ribbonColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isDark ? Colors.white70 : Colors.black45,
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _currentSettings.ribbonColor.withAlpha(120),
                                                  blurRadius: 6,
                                                  spreadRadius: 0.5,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.palette_outlined,
                                              size: 12,
                                              color: _currentSettings.ribbonColor.computeLuminance() > 0.5
                                                  ? Colors.black87
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('#', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: subtextColor)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: TextField(
                                        controller: _hexController,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.6,
                                          color: textColor,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'HEX code (e.g. 38BDF8)',
                                          hintStyle: TextStyle(fontSize: 11, color: subtextColor),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (text) {
                                          final parsed = _hexToColor(text);
                                          if (parsed != null) {
                                            _updateSettings(_currentSettings.copyWith(ribbonColor: parsed, autoRibbonColor: false));
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Section 3: Launch on Windows Startup
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.power_settings_new_rounded,
                                size: 16,
                                color: isDark ? AppColors.accentSilver : AppColors.lightTextPrimary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Launch on Windows Startup',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                                ),
                              ),
                              if (_isLoadingStartup)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                Switch(
                                  value: _launchOnStartup,
                                  onChanged: _toggleStartup,
                                  activeThumbColor: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Section 4: Backup & Restore
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Backup & Restore',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                                  ),
                                  Text(
                                    '${widget.clips.length} stored clips',
                                    style: TextStyle(fontSize: 10, color: subtextColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // 1. Auto Backup Toggle
                              Row(
                                children: [
                                  Icon(
                                    Icons.cloud_sync_outlined,
                                    size: 16,
                                    color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Automatic Backup',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                                        ),
                                        Text(
                                          'Auto-saves snapshot to Documents on change',
                                          style: TextStyle(fontSize: 9.5, color: subtextColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _currentSettings.autoBackup,
                                    activeThumbColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                    onChanged: (val) {
                                      _updateSettings(_currentSettings.copyWith(autoBackup: val));
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // 2. Backup Folder Row
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.folder_open_rounded,
                                      size: 14,
                                      color: subtextColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        r'Documents\ClipDock\Backups',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'Consolas',
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _openBackupFolder,
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Open Folder',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Icon(
                                              Icons.launch_rounded,
                                              size: 11,
                                              color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // 3. Export Backup & Import Backup Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _exportBackup,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        side: BorderSide(color: borderColor),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                        foregroundColor: textColor,
                                      ),
                                      icon: const Icon(Icons.upload_file_rounded, size: 14),
                                      label: const Text('Export Backup', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _importBackupFromFile,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        side: BorderSide(color: _isImporting ? AppColors.accentCyan : borderColor),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                        foregroundColor: textColor,
                                      ),
                                      icon: const Icon(Icons.download_rounded, size: 14),
                                      label: const Text('Import Backup', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],
                              ),

                              if (_isImporting) ...[
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                  ),
                                  child: TextField(
                                    controller: _importController,
                                    maxLines: 3,
                                    style: TextStyle(fontSize: 11, color: textColor),
                                    decoration: InputDecoration(
                                      hintText: 'Paste backup JSON string here...',
                                      hintStyle: TextStyle(fontSize: 10.5, color: subtextColor),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ElevatedButton.icon(
                                  onPressed: _handleManualImport,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                  ),
                                  icon: const Icon(Icons.check_rounded, size: 13),
                                  label: const Text('Confirm Restore', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                                ),
                              ],

                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    widget.onClearAll();
                                    Navigator.of(context).pop();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.accentRose,
                                    side: BorderSide(color: AppColors.accentRose.withAlpha(90)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                  ),
                                  icon: const Icon(Icons.delete_sweep_outlined, size: 14),
                                  label: const Text(
                                    'Clear All Stored Clips',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Section 5: Telegram Channel Integration
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const TelegramIcon(size: 16, color: Color(0xFF2AABEE)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Telegram Channel Integration',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                                        ),
                                        Text(
                                          'Forward clips directly to a Telegram channel via a bot',
                                          style: TextStyle(fontSize: 9.5, color: subtextColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Bot Token Field
                              Text(
                                'Bot Token',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _telegramTokenController,
                                        obscureText: _obscureTelegramToken,
                                        style: TextStyle(fontSize: 10.5, color: textColor),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. 7123456789:AAHk...',
                                          hintStyle: TextStyle(fontSize: 10, color: subtextColor.withAlpha(140)),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (val) {
                                          _updateSettings(_currentSettings.copyWith(telegramBotToken: val.trim()));
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscureTelegramToken = !_obscureTelegramToken;
                                        });
                                      },
                                      iconSize: 14,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                      icon: Icon(
                                        _obscureTelegramToken ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: subtextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Create a bot via @BotFather on Telegram to obtain a Bot Token',
                                style: TextStyle(fontSize: 8.5, color: subtextColor.withAlpha(180)),
                              ),
                              const SizedBox(height: 8),

                              // Channel ID Field
                              Text(
                                'Channel ID / Username',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                alignment: Alignment.centerLeft,
                                child: TextField(
                                  controller: _telegramChannelController,
                                  style: TextStyle(fontSize: 10.5, color: textColor),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. @your_channel or -1001234567890',
                                    hintStyle: TextStyle(fontSize: 10, color: subtextColor.withAlpha(140)),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) {
                                    _updateSettings(_currentSettings.copyWith(telegramChannelId: val.trim()));
                                  },
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Add your bot as an Administrator in your channel with Post Messages permission',
                                style: TextStyle(fontSize: 8.5, color: subtextColor.withAlpha(180)),
                              ),
                              const SizedBox(height: 10),

                              // Test Connection Button & Result
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _isTestingTelegram ? null : _testTelegramConnection,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF2AABEE).withAlpha(40)
                                            : const Color(0xFF2AABEE).withAlpha(30),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF2AABEE).withAlpha(120),
                                          width: 0.9,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_isTestingTelegram) ...[
                                            const SizedBox(
                                              width: 11,
                                              height: 11,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2AABEE)),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ] else ...[
                                            const Icon(Icons.send_rounded, size: 12, color: Color(0xFF2AABEE)),
                                            const SizedBox(width: 5),
                                          ],
                                          Text(
                                            _isTestingTelegram ? 'Testing...' : 'Test Connection',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2AABEE),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (_telegramTokenController.text.isNotEmpty || _telegramChannelController.text.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        _telegramTokenController.clear();
                                        _telegramChannelController.clear();
                                        setState(() {
                                          _telegramTestResult = null;
                                        });
                                        _updateSettings(_currentSettings.copyWith(
                                          telegramBotToken: '',
                                          telegramChannelId: '',
                                        ));
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          'Clear',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: subtextColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (_telegramTestResult != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _telegramTestSuccess
                                        ? AppColors.accentEmerald.withAlpha(25)
                                        : AppColors.accentRose.withAlpha(25),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: _telegramTestSuccess
                                          ? AppColors.accentEmerald.withAlpha(120)
                                          : AppColors.accentRose.withAlpha(120),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _telegramTestSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                        size: 13,
                                        color: _telegramTestSuccess ? AppColors.accentEmerald : AppColors.accentRose,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _telegramTestResult!,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w500,
                                            color: _telegramTestSuccess ? AppColors.accentEmerald : AppColors.accentRose,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

                // Status notification message
                if (_statusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.accentEmerald,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildOffsetSliderSection({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required String title,
    required String subtitle,
    required double value,
    required ValueChanged<double> onChanged,
    required VoidCallback onReset,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
              ),
              child: Text(
                value == 0.0
                    ? '0 px (Default)'
                    : (value > 0
                        ? '+${value.round()} px (Right)'
                        : '${value.round()} px (Left)'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: value == 0.0
                      ? subtextColor
                      : (isDark ? AppColors.accentCyan : const Color(0xFF0284C7)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 9, color: subtextColor),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // [-] Step Button
            Tooltip(
              message: 'Shift Left 1px (Long press 5px)',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged((value - 1.0).clamp(-100.0, 100.0)),
                  onLongPress: () => onChanged((value - 5.0).clamp(-100.0, 100.0)),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                    ),
                    child: Text(
                      '-',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
                    ),
                  ),
                ),
              ),
            ),
            // Slider (-100 to +100 px, step 1px)
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: value,
                  min: -100.0,
                  max: 100.0,
                  divisions: 200,
                  activeColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                  onChanged: (val) => onChanged(val.roundToDouble()),
                ),
              ),
            ),
            // [+] Step Button
            Tooltip(
              message: 'Shift Right 1px (Long press 5px)',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged((value + 1.0).clamp(-100.0, 100.0)),
                  onLongPress: () => onChanged((value + 5.0).clamp(-100.0, 100.0)),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                    ),
                    child: Text(
                      '+',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                    ),
                  ),
                ),
              ),
            ),
            if (value != 0.0) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Reset to 0 px',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onReset,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                      ),
                      child: Text(
                        'Reset',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subtextColor),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(covariant SettingsDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDark != oldWidget.isDark) {
      if (_currentSettings.autoRibbonColor) {
        final newColor = widget.isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
        setState(() {
          _currentSettings.ribbonColor = newColor;
          _hexController.text = _colorToHex(newColor);
        });
      }
    }
  }

  void _selectColor(Color color, {bool isAuto = false}) {
    _hexController.text = _colorToHex(color);
    _updateSettings(_currentSettings.copyWith(ribbonColor: color, autoRibbonColor: isAuto));
  }

  void _openColorPaletteModal() {
    final isDark = widget.isDark;
    final bgAlpha = (widget.settings.opacity * 255).round().clamp(0, 255);
    final bgSurface = isDark
        ? Color.fromARGB(bgAlpha, 14, 14, 14)
        : Color.fromARGB(bgAlpha, 248, 250, 252);
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Color Palette',
      barrierColor: Colors.black.withAlpha(180),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final currentColor = _currentSettings.ribbonColor;
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.settings.blur,
                    sigmaY: widget.settings.blur,
                  ),
                  child: Container(
                    width: 370,
                    constraints: const BoxConstraints(maxHeight: 560),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(90),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Row(
                            children: [
                              Icon(
                                Icons.palette_outlined,
                                size: 18,
                                color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Choose Ribbon Color',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(),
                                iconSize: 16,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                icon: Icon(Icons.close_rounded, color: subtextColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Section 1: Theme Presets (Light & AMOLED)
                          Text(
                            'Theme Presets (Light & AMOLED)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: subtextColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildColorGrid(_themePresetColors, currentColor, (color, isAuto) {
                            _selectColor(color, isAuto: isAuto);
                            setModalState(() {});
                          }, isDark),

                          const SizedBox(height: 12),

                          // Section 2: Solid Colors
                          Text(
                            'Solid & Vibrant Colors',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: subtextColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildColorGrid(_solidColors, currentColor, (color, isAuto) {
                            _selectColor(color, isAuto: false);
                            setModalState(() {});
                          }, isDark),

                          const SizedBox(height: 12),

                          // Section 3: Low / Thin Colors (Soft Pastels)
                          Text(
                            'Low & Thin Pastel Colors',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: subtextColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildColorGrid(_softPastelColors, currentColor, (color, isAuto) {
                            _selectColor(color, isAuto: false);
                            setModalState(() {});
                          }, isDark),

                          const SizedBox(height: 14),

                          // Bottom Row: Current Selected Preview and Done button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: currentColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? Colors.white54 : Colors.black26,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '#${_colorToHex(currentColor)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () => Navigator.of(dialogCtx).pop(),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.accentCyan.withAlpha(40)
                                        : const Color(0xFF0284C7).withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.accentCyan.withAlpha(120)
                                          : const Color(0xFF0284C7).withAlpha(120),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Done',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                    ),
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
            );
          },
        );
      },
    );
  }

  Widget _buildColorGrid(
    List<_ColorOption> options,
    Color currentColor,
    void Function(Color color, bool isAuto) onSelected,
    bool isDark,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final effectiveColor = option.isAuto
            ? (isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF))
            : option.color;
        final isSelected = option.isAuto
            ? _currentSettings.autoRibbonColor
            : (!_currentSettings.autoRibbonColor && currentColor.toARGB32() == effectiveColor.toARGB32());
        final isWhite = effectiveColor.toARGB32() == const Color(0xFFFFFFFF).toARGB32();
        final isBlack = effectiveColor.toARGB32() == const Color(0xFF000000).toARGB32();
        final isBright = effectiveColor.computeLuminance() > 0.6;

        return Tooltip(
          message: option.isAuto
              ? 'Auto (${isDark ? 'AMOLED Black #000000' : 'Light White #FFFFFF'})'
              : '${option.name} (#${_colorToHex(option.color)})',
          child: GestureDetector(
            onTap: () => onSelected(effectiveColor, option.isAuto),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: effectiveColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? (isBright ? Colors.black : Colors.white)
                      : (isDark
                          ? (isWhite || isBlack ? Colors.white54 : Colors.white24)
                          : (isWhite || isBlack ? Colors.black54 : Colors.black12)),
                  width: isSelected ? 2.5 : (isWhite || isBlack ? 1.4 : 1),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: effectiveColor.withAlpha(180),
                          blurRadius: 7,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: isBright ? Colors.black : Colors.white,
                    )
                  : (option.isAuto
                      ? Center(
                          child: Icon(
                            Icons.brightness_auto_rounded,
                            size: 13,
                            color: isBright ? Colors.black87 : Colors.white70,
                          ),
                        )
                      : null),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ColorOption {
  final Color color;
  final String name;
  final bool isLight;
  final bool isAuto;

  const _ColorOption(
    this.color,
    this.name, {
    this.isLight = false,
    this.isAuto = false,
  });
}
