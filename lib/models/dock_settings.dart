import 'package:flutter/material.dart';

class DockSettings {
  double opacity; // 0.20 to 1.0 (default 1.0: 100% opacity)
  double blur; // 0.0 to 30.0 (default 30.0: 30px max blur)
  bool showRibbonWhenCollapsed; // default: true
  bool showRibbonWhenExpanded; // default: true
  double ribbonWidth; // 0.0 to 24.0
  double ribbonHeightPercent; // 0.2 to 1.0 (20% to 100% of height)
  double ribbonOpacity; // 0.0 to 1.0 (0% to 100% opacity)
  Color ribbonColor;
  double edgeOffset; // -100.0 to +100.0 (default 0.0)
  bool isPinned;
  bool isDark;
  bool clickRowToCopy; // default: false
  bool showCopyButton; // default: true
  bool autoCapture; // default: true (auto-save clipboard to Auto tab)
  bool rightClickToPaste; // default: true (right-click panel to paste from clipboard)
  bool dragToPaste; // default: true (drag clip to paste into apps)

  DockSettings({
    this.opacity = 1.0,
    this.blur = 30.0,
    this.showRibbonWhenCollapsed = true,
    this.showRibbonWhenExpanded = true,
    this.ribbonWidth = 24.0,
    this.ribbonHeightPercent = 1.0,
    this.ribbonOpacity = 0.90,
    this.ribbonColor = const Color(0xFFCBD5E1),
    this.edgeOffset = 0.0,
    this.isPinned = false,
    this.isDark = true,
    this.clickRowToCopy = false,
    this.showCopyButton = true,
    this.autoCapture = true,
    this.rightClickToPaste = true,
    this.dragToPaste = true,
  });

  DockSettings copyWith({
    double? opacity,
    double? blur,
    bool? showRibbonWhenCollapsed,
    bool? showRibbonWhenExpanded,
    double? ribbonWidth,
    double? ribbonHeightPercent,
    double? ribbonOpacity,
    Color? ribbonColor,
    double? edgeOffset,
    bool? isPinned,
    bool? isDark,
    bool? clickRowToCopy,
    bool? showCopyButton,
    bool? autoCapture,
    bool? rightClickToPaste,
    bool? dragToPaste,
  }) {
    return DockSettings(
      opacity: opacity ?? this.opacity,
      blur: blur ?? this.blur,
      showRibbonWhenCollapsed: showRibbonWhenCollapsed ?? this.showRibbonWhenCollapsed,
      showRibbonWhenExpanded: showRibbonWhenExpanded ?? this.showRibbonWhenExpanded,
      ribbonWidth: ribbonWidth ?? this.ribbonWidth,
      ribbonHeightPercent: ribbonHeightPercent ?? this.ribbonHeightPercent,
      ribbonOpacity: ribbonOpacity ?? this.ribbonOpacity,
      ribbonColor: ribbonColor ?? this.ribbonColor,
      edgeOffset: edgeOffset ?? this.edgeOffset,
      isPinned: isPinned ?? this.isPinned,
      isDark: isDark ?? this.isDark,
      clickRowToCopy: clickRowToCopy ?? this.clickRowToCopy,
      showCopyButton: showCopyButton ?? this.showCopyButton,
      autoCapture: autoCapture ?? this.autoCapture,
      rightClickToPaste: rightClickToPaste ?? this.rightClickToPaste,
      dragToPaste: dragToPaste ?? this.dragToPaste,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'opacity': opacity,
      'blur': blur,
      'showRibbonWhenCollapsed': showRibbonWhenCollapsed,
      'showRibbonWhenExpanded': showRibbonWhenExpanded,
      'ribbonWidth': ribbonWidth,
      'ribbonHeightPercent': ribbonHeightPercent,
      'ribbonOpacity': ribbonOpacity,
      'ribbonColor': ribbonColor.toARGB32(),
      'edgeOffset': edgeOffset,
      'isPinned': isPinned,
      'isDark': isDark,
      'clickRowToCopy': clickRowToCopy,
      'showCopyButton': showCopyButton,
      'autoCapture': autoCapture,
      'rightClickToPaste': rightClickToPaste,
      'dragToPaste': dragToPaste,
    };
  }

  factory DockSettings.fromJson(Map<String, dynamic> json) {
    return DockSettings(
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      blur: (json['blur'] as num?)?.toDouble() ?? 30.0,
      showRibbonWhenCollapsed: json['showRibbonWhenCollapsed'] as bool? ?? true,
      showRibbonWhenExpanded: json['showRibbonWhenExpanded'] as bool? ?? true,
      ribbonWidth: (json['ribbonWidth'] as num?)?.toDouble() ?? 24.0,
      ribbonHeightPercent: (json['ribbonHeightPercent'] as num?)?.toDouble() ?? 1.0,
      ribbonOpacity: (json['ribbonOpacity'] as num?)?.toDouble() ?? 0.90,
      ribbonColor: json['ribbonColor'] != null ? Color(json['ribbonColor'] as int) : const Color(0xFFCBD5E1),
      edgeOffset: (json['edgeOffset'] as num?)?.toDouble() ?? 0.0,
      isPinned: json['isPinned'] as bool? ?? false,
      isDark: json['isDark'] as bool? ?? true,
      clickRowToCopy: json['clickRowToCopy'] as bool? ?? false,
      showCopyButton: json['showCopyButton'] as bool? ?? true,
      autoCapture: json['autoCapture'] as bool? ?? true,
      rightClickToPaste: json['rightClickToPaste'] as bool? ?? true,
      dragToPaste: json['dragToPaste'] as bool? ?? true,
    );
  }
}
