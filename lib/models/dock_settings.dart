import 'package:flutter/material.dart';

class DockSettings {
  double opacity; // 0.20 to 1.0 (default 1.0: 100% opacity)
  double transparency; // 0.0 to 1.0 (default 0.30: 30% background transparency)
  double blur; // 0.0 to 30.0 (default 30.0: 30px max blur)
  bool showRibbonWhenCollapsed; // default: true
  bool showRibbonWhenExpanded; // default: true
  double ribbonWidth; // 0.0 to 24.0
  double ribbonHeightPercent; // 0.2 to 1.0 (20% to 100% of height)
  double ribbonOpacity; // 0.0 to 1.0 (0% to 100% opacity)
  Color ribbonColor;
  double edgeOffsetVisible; // -100.0 to +100.0 (default 0.0: open position)
  double edgeOffsetHidden; // -100.0 to +100.0 (default 0.0: closed position)
  double panelWidth; // 320.0 to 600.0 (default 400.0)
  bool isPinned;
  bool isDark;
  bool clickRowToCopy; // default: false
  bool clickRowToFill; // default: true (click clip row to paste/fill directly into active window)
  bool showCopyButton; // default: true
  bool autoCapture; // default: true (auto-save clipboard to Auto tab)
  bool rightClickToPaste; // default: true (right-click panel to paste from clipboard)
  bool dragToPaste; // default: true (drag clip to paste into apps)
  bool autoBackup; // default: true (auto-save backup to Documents on every change)
  bool hasCompletedInitialSetup; // default: false (first-launch onboarding flag)
  bool autoRibbonColor; // default: true (dynamically adjust ribbon color to match active theme)

  DockSettings({
    this.opacity = 1.0,
    this.transparency = 0.30,
    this.blur = 30.0,
    this.showRibbonWhenCollapsed = true,
    this.showRibbonWhenExpanded = true,
    this.ribbonWidth = 24.0,
    this.ribbonHeightPercent = 1.0,
    this.ribbonOpacity = 0.90,
    this.ribbonColor = const Color(0xFF000000),
    this.edgeOffsetVisible = 0.0,
    this.edgeOffsetHidden = 0.0,
    this.panelWidth = 400.0,
    this.isPinned = false,
    this.isDark = true,
    this.clickRowToCopy = false,
    this.clickRowToFill = true,
    this.showCopyButton = true,
    this.autoCapture = true,
    this.rightClickToPaste = true,
    this.dragToPaste = true,
    this.autoBackup = true,
    this.hasCompletedInitialSetup = false,
    this.autoRibbonColor = true,
  });

  DockSettings copyWith({
    double? opacity,
    double? transparency,
    double? blur,
    bool? showRibbonWhenCollapsed,
    bool? showRibbonWhenExpanded,
    double? ribbonWidth,
    double? ribbonHeightPercent,
    double? ribbonOpacity,
    Color? ribbonColor,
    double? edgeOffsetVisible,
    double? edgeOffsetHidden,
    double? panelWidth,
    bool? isPinned,
    bool? isDark,
    bool? clickRowToCopy,
    bool? clickRowToFill,
    bool? showCopyButton,
    bool? autoCapture,
    bool? rightClickToPaste,
    bool? dragToPaste,
    bool? autoBackup,
    bool? hasCompletedInitialSetup,
    bool? autoRibbonColor,
  }) {
    return DockSettings(
      opacity: opacity ?? this.opacity,
      transparency: transparency ?? this.transparency,
      blur: blur ?? this.blur,
      showRibbonWhenCollapsed: showRibbonWhenCollapsed ?? this.showRibbonWhenCollapsed,
      showRibbonWhenExpanded: showRibbonWhenExpanded ?? this.showRibbonWhenExpanded,
      ribbonWidth: ribbonWidth ?? this.ribbonWidth,
      ribbonHeightPercent: ribbonHeightPercent ?? this.ribbonHeightPercent,
      ribbonOpacity: ribbonOpacity ?? this.ribbonOpacity,
      ribbonColor: ribbonColor ?? this.ribbonColor,
      edgeOffsetVisible: edgeOffsetVisible ?? this.edgeOffsetVisible,
      edgeOffsetHidden: edgeOffsetHidden ?? this.edgeOffsetHidden,
      panelWidth: panelWidth ?? this.panelWidth,
      isPinned: isPinned ?? this.isPinned,
      isDark: isDark ?? this.isDark,
      clickRowToCopy: clickRowToCopy ?? this.clickRowToCopy,
      clickRowToFill: clickRowToFill ?? this.clickRowToFill,
      showCopyButton: showCopyButton ?? this.showCopyButton,
      autoCapture: autoCapture ?? this.autoCapture,
      rightClickToPaste: rightClickToPaste ?? this.rightClickToPaste,
      dragToPaste: dragToPaste ?? this.dragToPaste,
      autoBackup: autoBackup ?? this.autoBackup,
      hasCompletedInitialSetup: hasCompletedInitialSetup ?? this.hasCompletedInitialSetup,
      autoRibbonColor: autoRibbonColor ?? this.autoRibbonColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'opacity': opacity,
      'transparency': transparency,
      'blur': blur,
      'showRibbonWhenCollapsed': showRibbonWhenCollapsed,
      'showRibbonWhenExpanded': showRibbonWhenExpanded,
      'ribbonWidth': ribbonWidth,
      'ribbonHeightPercent': ribbonHeightPercent,
      'ribbonOpacity': ribbonOpacity,
      'ribbonColor': ribbonColor.toARGB32(),
      'edgeOffsetVisible': edgeOffsetVisible,
      'edgeOffsetHidden': edgeOffsetHidden,
      'panelWidth': panelWidth,
      'isPinned': isPinned,
      'isDark': isDark,
      'clickRowToCopy': clickRowToCopy,
      'clickRowToFill': clickRowToFill,
      'showCopyButton': showCopyButton,
      'autoCapture': autoCapture,
      'rightClickToPaste': rightClickToPaste,
      'dragToPaste': dragToPaste,
      'autoBackup': autoBackup,
      'hasCompletedInitialSetup': hasCompletedInitialSetup,
      'autoRibbonColor': autoRibbonColor,
    };
  }

  factory DockSettings.fromJson(Map<String, dynamic> json) {
    final legacyOffset = (json['edgeOffset'] as num?)?.toDouble() ?? 0.0;
    final isDark = json['isDark'] as bool? ?? true;
    final autoRibbon = json['autoRibbonColor'] as bool? ?? false;
    final defaultColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return DockSettings(
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      transparency: (json['transparency'] as num?)?.toDouble() ?? 0.30,
      blur: (json['blur'] as num?)?.toDouble() ?? 30.0,
      showRibbonWhenCollapsed: json['showRibbonWhenCollapsed'] as bool? ?? true,
      showRibbonWhenExpanded: json['showRibbonWhenExpanded'] as bool? ?? true,
      ribbonWidth: (json['ribbonWidth'] as num?)?.toDouble() ?? 24.0,
      ribbonHeightPercent: (json['ribbonHeightPercent'] as num?)?.toDouble() ?? 1.0,
      ribbonOpacity: (json['ribbonOpacity'] as num?)?.toDouble() ?? 0.90,
      ribbonColor: autoRibbon
          ? defaultColor
          : (json['ribbonColor'] != null ? Color(json['ribbonColor'] as int) : defaultColor),
      edgeOffsetVisible: (json['edgeOffsetVisible'] as num?)?.toDouble() ?? legacyOffset,
      edgeOffsetHidden: (json['edgeOffsetHidden'] as num?)?.toDouble() ?? legacyOffset,
      panelWidth: (json['panelWidth'] as num?)?.toDouble() ?? 400.0,
      isPinned: json['isPinned'] as bool? ?? false,
      isDark: isDark,
      clickRowToCopy: json['clickRowToCopy'] as bool? ?? false,
      clickRowToFill: json['clickRowToFill'] as bool? ?? true,
      showCopyButton: json['showCopyButton'] as bool? ?? true,
      autoCapture: json['autoCapture'] as bool? ?? true,
      rightClickToPaste: json['rightClickToPaste'] as bool? ?? true,
      dragToPaste: json['dragToPaste'] as bool? ?? true,
      autoBackup: json['autoBackup'] as bool? ?? true,
      hasCompletedInitialSetup: json['hasCompletedInitialSetup'] as bool? ?? true,
      autoRibbonColor: autoRibbon,
    );
  }
}
