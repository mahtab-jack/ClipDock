import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/clip_item.dart';
import '../models/dock_settings.dart';
import '../services/startup_service.dart';
import '../theme/app_theme.dart';

class SettingsDialog extends StatefulWidget {
  final bool isDark;
  final List<ClipItem> clips;
  final DockSettings settings;
  final Function(DockSettings updatedSettings) onSettingsChanged;
  final Function(List<ClipItem> importedClips) onImportClips;
  final VoidCallback onClearAll;

  const SettingsDialog({
    super.key,
    required this.isDark,
    required this.clips,
    required this.settings,
    required this.onSettingsChanged,
    required this.onImportClips,
    required this.onClearAll,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final TextEditingController _importController = TextEditingController();
  final TextEditingController _hexController = TextEditingController();
  bool _isImporting = false;
  bool _launchOnStartup = false;
  bool _isLoadingStartup = true;
  String? _statusMessage;

  late DockSettings _currentSettings;

  static const List<Color> _presetColors = [
    Color(0xFFCBD5E1), // Silver
    Color(0xFF38BDF8), // Cyan
    Color(0xFF10B981), // Emerald
    Color(0xFFF43F5E), // Rose
    Color(0xFFF59E0B), // Amber
    Color(0xFFA855F7), // Purple
    Color(0xFFFFFFFF), // Pure White
  ];

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.settings.copyWith();
    _hexController.text = _colorToHex(_currentSettings.ribbonColor);
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

  String _getExportFileName() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'cNote-$y-$m-$d.json';
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

  @override
  void dispose() {
    _importController.dispose();
    _hexController.dispose();
    super.dispose();
  }

  Future<void> _exportToFile() async {
    if (widget.clips.isEmpty) {
      setState(() {
        _statusMessage = 'No clips to export';
      });
      return;
    }

    final fileName = _getExportFileName();
    final jsonList = widget.clips.map((c) => c.toJson()).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonList);

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
\$sfd.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
\$sfd.FileName = "$fileName"
\$sfd.Title = "Export cNote Clips"
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

    // Default fallback to Downloads if dialog was cancelled or unavailable
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
          _statusMessage = 'Exported ${widget.clips.length} clips to $shortName';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to write export file';
        });
      }
    }
  }

  Future<void> _importFromFile() async {
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
\$ofd.Filter = "JSON files (*.json)|*.json|Text files (*.txt)|*.txt|All files (*.*)|*.*"
\$ofd.Title = "Import cNote Clips"
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

    // Toggle manual import text field fallback
    setState(() {
      _isImporting = !_isImporting;
      _statusMessage = _isImporting ? 'Select a file or paste JSON/text below' : null;
    });
  }

  void _processImportContent(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final List<ClipItem> newClips = [];
        for (var entry in decoded) {
          if (entry is Map<String, dynamic>) {
            newClips.add(ClipItem.fromJson(entry));
          } else if (entry is String && entry.trim().isNotEmpty) {
            newClips.add(ClipItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: entry.length > 35 ? '${entry.substring(0, 35)}...' : entry,
              content: entry,
              createdAt: DateTime.now(),
            ));
          }
        }
        widget.onImportClips(newClips);
        Navigator.of(context).pop();
        return;
      }
    } catch (_) {}

    // Plain text line-by-line fallback
    final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isNotEmpty) {
      final List<ClipItem> newClips = lines.map((line) {
        final trimmed = line.trim();
        return ClipItem(
          id: (DateTime.now().millisecondsSinceEpoch + lines.indexOf(line)).toString(),
          title: trimmed.length > 35 ? '${trimmed.substring(0, 35)}...' : trimmed,
          content: trimmed,
          createdAt: DateTime.now(),
        );
      }).toList();
      widget.onImportClips(newClips);
      Navigator.of(context).pop();
    } else {
      setState(() {
        _statusMessage = 'Could not parse import data';
      });
    }
  }

  void _handleManualImport() {
    final raw = _importController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _statusMessage = 'Paste JSON or text clips into the box';
      });
      return;
    }
    _processImportContent(raw);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgAlpha = (_currentSettings.opacity * 255).round().clamp(0, 255);
    final bgSurface = isDark
        ? Color.fromARGB(bgAlpha, 0, 0, 0)
        : Color.fromARGB(bgAlpha, 241, 245, 249);
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg = isDark
        ? Color.fromARGB((_currentSettings.opacity * 220).round().clamp(0, 255), 14, 14, 14)
        : Color.fromARGB((_currentSettings.opacity * 200).round().clamp(0, 255), 255, 255, 255);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _currentSettings.blur,
            sigmaY: _currentSettings.blur,
          ),
          child: Container(
            width: 395,
            constraints: const BoxConstraints(maxHeight: 620),
            padding: const EdgeInsets.all(16),
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
                        // Section 1: Glass & Blur Appearance
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

                              // Opacity / Transparency Slider
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Panel Opacity', style: TextStyle(fontSize: 10.5, color: subtextColor)),
                                  Text('${(_currentSettings.opacity * 100).round()}%',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: textColor)),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: _currentSettings.opacity,
                                  min: 0.20,
                                  max: 1.0,
                                  divisions: 16,
                                  activeColor: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                                  onChanged: (val) {
                                    _updateSettings(_currentSettings.copyWith(opacity: val));
                                  },
                                ),
                              ),

                              // Blur Slider
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Background Blur', style: TextStyle(fontSize: 10.5, color: subtextColor)),
                                  Text('${_currentSettings.blur.round()} px',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: textColor)),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: _currentSettings.blur,
                                  min: 0.0,
                                  max: 30.0,
                                  divisions: 30,
                                  activeColor: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                                  onChanged: (val) {
                                    _updateSettings(_currentSettings.copyWith(blur: val));
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Section 2: Clipboard & Clip Behavior
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Auto-capture clipboard',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                                        ),
                                        Text(
                                          'Automatically save copied text to the Auto tab',
                                          style: TextStyle(fontSize: 9.5, color: subtextColor),
                                        ),
                                      ],
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
                              const SizedBox(height: 6),

                              // Right click panel to paste toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Right-click panel to paste',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                                        ),
                                        Text(
                                          'Right-clicking anywhere on the panel pastes from clipboard',
                                          style: TextStyle(fontSize: 9.5, color: subtextColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _currentSettings.rightClickToPaste,
                                    activeThumbColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                    onChanged: (val) {
                                      _updateSettings(_currentSettings.copyWith(rightClickToPaste: val));
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Drag to paste toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Drag clip to paste into apps',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                                        ),
                                        Text(
                                          'Press & drag any clip onto external windows or inputs',
                                          style: TextStyle(fontSize: 9.5, color: subtextColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _currentSettings.dragToPaste,
                                    activeThumbColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                    onChanged: (val) {
                                      _updateSettings(_currentSettings.copyWith(dragToPaste: val));
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Click row to copy toggle (default: OFF)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Click row to copy',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor),
                                        ),
                                        Text(
                                          'Clicking anywhere on a clip card copies it',
                                          style: TextStyle(fontSize: 9.5, color: subtextColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _currentSettings.clickRowToCopy,
                                    activeThumbColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                    onChanged: (val) {
                                      _updateSettings(_currentSettings.copyWith(clickRowToCopy: val));
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Show copy button toggle (Only hidable if clickRowToCopy is enabled)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Show copy button',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: _currentSettings.clickRowToCopy ? textColor : subtextColor,
                                          ),
                                        ),
                                        Text(
                                          _currentSettings.clickRowToCopy
                                              ? 'Show or hide the Copy button on each clip card'
                                              : 'Always enabled when "Click row to copy" is off',
                                          style: TextStyle(fontSize: 9.5, color: subtextColor),
                                        ),
                                      ],
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

                        // Section 3: Dock Position & Screen Edge Alignment (Horizontal Shift Slider with - and + buttons)
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
                                    'Position & Edge Alignment',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                    ),
                                    child: Text(
                                      _currentSettings.edgeOffset == 0.0
                                          ? '0 px (Default)'
                                          : (_currentSettings.edgeOffset > 0
                                              ? '+${_currentSettings.edgeOffset.round()} px (Right)'
                                              : '${_currentSettings.edgeOffset.round()} px (Left)'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _currentSettings.edgeOffset == 0.0
                                            ? subtextColor
                                            : (isDark ? AppColors.accentCyan : const Color(0xFF0284C7)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Slide panel and ribbon left or right (visible and hidden states)',
                                style: TextStyle(fontSize: 9.5, color: subtextColor),
                              ),
                              const SizedBox(height: 8),

                              // Stepper with [-] and [+] on both sides and Slider in middle
                              Row(
                                children: [
                                  // [-] Step Button (tap: -1px, long press: -5px)
                                  Tooltip(
                                    message: 'Shift Left 1px (Long press 5px)',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          final newVal = (_currentSettings.edgeOffset - 1.0).clamp(-100.0, 100.0);
                                          _updateSettings(_currentSettings.copyWith(edgeOffset: newVal));
                                        },
                                        onLongPress: () {
                                          final newVal = (_currentSettings.edgeOffset - 5.0).clamp(-100.0, 100.0);
                                          _updateSettings(_currentSettings.copyWith(edgeOffset: newVal));
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

                                  // Slider (-100 to +100 px, step 1px)
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      ),
                                      child: Slider(
                                        value: _currentSettings.edgeOffset,
                                        min: -100.0,
                                        max: 100.0,
                                        divisions: 200,
                                        activeColor: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
                                        onChanged: (val) {
                                          _updateSettings(_currentSettings.copyWith(edgeOffset: val.roundToDouble()));
                                        },
                                      ),
                                    ),
                                  ),

                                  // [+] Step Button (tap: +1px, long press: +5px)
                                  Tooltip(
                                    message: 'Shift Right 1px (Long press 5px)',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          final newVal = (_currentSettings.edgeOffset + 1.0).clamp(-100.0, 100.0);
                                          _updateSettings(_currentSettings.copyWith(edgeOffset: newVal));
                                        },
                                        onLongPress: () {
                                          final newVal = (_currentSettings.edgeOffset + 5.0).clamp(-100.0, 100.0);
                                          _updateSettings(_currentSettings.copyWith(edgeOffset: newVal));
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

                                  // Reset Button if non-zero
                                  if (_currentSettings.edgeOffset != 0.0) ...[
                                    const SizedBox(width: 6),
                                    Tooltip(
                                      message: 'Reset to 0 px',
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            _updateSettings(_currentSettings.copyWith(edgeOffset: 0.0));
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

                              // Ribbon Preset Color Palette
                              Text('Ribbon Color (Presets & Custom)', style: TextStyle(fontSize: 10.5, color: subtextColor)),
                              const SizedBox(height: 8),
                              Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: _presetColors.map((color) {
                                    final isSelected = _currentSettings.ribbonColor.toARGB32() == color.toARGB32();
                                    return GestureDetector(
                                      onTap: () {
                                        _hexController.text = _colorToHex(color);
                                        _updateSettings(_currentSettings.copyWith(ribbonColor: color));
                                      },
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? (isDark ? Colors.white : Colors.black)
                                                : (isDark ? Colors.white24 : Colors.black12),
                                            width: isSelected ? 2.2 : 1,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: color.withAlpha(160),
                                                    blurRadius: 7,
                                                    spreadRadius: 1,
                                                  )
                                                ]
                                              : null,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Custom Editable HEX Color Input
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                ),
                                child: Row(
                                  children: [
                                    // Live Color Preview Dot
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: _currentSettings.ribbonColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: isDark ? Colors.white54 : Colors.black26),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subtextColor)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: TextField(
                                        controller: _hexController,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                                        decoration: InputDecoration(
                                          hintText: 'Custom HEX (e.g. FFA500)',
                                          hintStyle: TextStyle(fontSize: 10, color: subtextColor),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (text) {
                                          final parsed = _hexToColor(text);
                                          if (parsed != null) {
                                            _updateSettings(_currentSettings.copyWith(ribbonColor: parsed));
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Launch on Windows Startup',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                                    ),
                                    Text(
                                      'Start in system tray on boot',
                                      style: TextStyle(fontSize: 9.5, color: subtextColor),
                                    ),
                                  ],
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

                        // Section 4: Data Management (Export File / Import File / Clear)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Stored Clips', style: TextStyle(fontSize: 11, color: subtextColor)),
                                  Text('${widget.clips.length} items',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _exportToFile,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        side: BorderSide(color: borderColor),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                        foregroundColor: textColor,
                                      ),
                                      icon: const Icon(Icons.file_upload_outlined, size: 13),
                                      label: const Text('Export JSON', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _importFromFile,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        side: BorderSide(color: _isImporting ? AppColors.accentSilver : borderColor),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                        foregroundColor: textColor,
                                      ),
                                      icon: const Icon(Icons.file_download_outlined, size: 13),
                                      label: const Text('Import JSON', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
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
                                      hintText: 'Paste JSON array or text clips here...',
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
                                    backgroundColor: isDark ? AppColors.accentSilver : AppColors.lightTextPrimary,
                                    foregroundColor: isDark ? const Color(0xFF000000) : Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                  ),
                                  icon: const Icon(Icons.check_rounded, size: 13),
                                  label: const Text('Confirm Import', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
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
      ),
    );
  }
}
