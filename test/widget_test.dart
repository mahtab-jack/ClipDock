import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cnote/main.dart';
import 'package:cnote/models/clip_item.dart';
import 'package:cnote/models/dock_settings.dart';
import 'package:cnote/widgets/clip_card.dart';

void main() {
  testWidgets('ClipDockApp renders header, paste button, Add button, tabs (All, Auto, Starred, Trash), and settings', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ClipDockApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Pin dock so it does not auto-collapse during tests
    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);

    // Verify header and title with count
    expect(find.textContaining('Clip Dock'), findsOneWidget);

    // Verify Paste and Add buttons are present
    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    // Verify Clips / Auto / Starred / Trash tabs
    expect(find.textContaining('Clips'), findsOneWidget);
    expect(find.textContaining('Auto'), findsOneWidget);
    expect(find.textContaining('Starred'), findsOneWidget);
    expect(find.textContaining('Trash'), findsOneWidget);

    // Verify Settings button is present
    expect(find.text('Settings'), findsOneWidget);

    // Mock empty clipboard
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': ''};
        }
        return null;
      },
    );

    // Test clicking Paste with empty clipboard -> triggers warning toast with warning icon
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Clipboard is empty'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    // Test clicking Auto tab
    await tester.ensureVisible(find.textContaining('Auto'));
    await tester.tap(find.textContaining('Auto'));
    await tester.pump(const Duration(milliseconds: 200));

    // Test clicking Trash tab
    await tester.ensureVisible(find.textContaining('Trash'));
    await tester.tap(find.textContaining('Trash'));
    await tester.pump(const Duration(milliseconds: 200));

    // In Trash tab when empty, check empty state
    expect(find.textContaining('Trash is empty'), findsOneWidget);

    // Click back to Clips tab
    await tester.ensureVisible(find.textContaining('Clips'));
    await tester.tap(find.textContaining('Clips'));
    await tester.pump(const Duration(milliseconds: 200));

    // Test opening Add dialog
    await tester.tap(find.text('Add'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Add New Clip'), findsOneWidget);
    expect(find.textContaining('0 characters'), findsOneWidget);

    // Close Add dialog
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pump(const Duration(milliseconds: 300));

    // Test opening Settings dialog
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Settings & Customization'), findsOneWidget);
    expect(find.text('Auto-capture clipboard'), findsOneWidget);
    expect(find.text('Right-click panel to paste'), findsOneWidget);
    expect(find.text('Drag clip to paste into apps'), findsOneWidget);

    // Close Settings dialog
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pump(const Duration(milliseconds: 300));

    // Test opening About dialog
    expect(find.text('About'), findsOneWidget);
    await tester.tap(find.text('About'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('About Clip Dock'), findsOneWidget);
    expect(find.text('Mahtab Jack'), findsOneWidget);
    expect(find.text('v1.2.0'), findsWidgets);
    expect(find.text('Visit Profile'), findsOneWidget);

    // Close About dialog via top close button
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pump(const Duration(milliseconds: 300));

    // Let any pending timers elapse
    await tester.pump(const Duration(seconds: 4));
  });

  test('DockSettings serialization and deserialization preserves all values', () {
    final settings = DockSettings(
      opacity: 0.85,
      transparency: 0.45,
      blur: 15.0,
      ribbonWidth: 20.0,
      ribbonHeightPercent: 0.5,
      ribbonOpacity: 0.9,
      ribbonColor: const Color(0xFF00FF00),
      showRibbonWhenExpanded: false,
      showRibbonWhenCollapsed: true,
      edgeOffsetVisible: -12.0,
      edgeOffsetHidden: 5.0,
      panelWidth: 460.0,
      isPinned: true,
      isDark: false,
      clickRowToCopy: true,
      clickRowToFill: true,
      showCopyButton: false,
      autoCapture: false,
      rightClickToPaste: true,
      dragToPaste: true,
      autoBackup: true,
      hasCompletedInitialSetup: true,
      autoRibbonColor: true,
    );

    final json = settings.toJson();
    final restored = DockSettings.fromJson(json);

    expect(restored.opacity, 0.85);
    expect(restored.transparency, 0.45);
    expect(restored.blur, 15.0);
    expect(restored.ribbonWidth, 20.0);
    expect(restored.ribbonHeightPercent, 0.5);
    expect(restored.ribbonOpacity, 0.9);
    expect(restored.ribbonColor, const Color(0xFFFFFFFF));
    expect(restored.showRibbonWhenExpanded, false);
    expect(restored.showRibbonWhenCollapsed, true);
    expect(restored.edgeOffsetVisible, -12.0);
    expect(restored.edgeOffsetHidden, 5.0);
    expect(restored.panelWidth, 460.0);
    expect(restored.isPinned, true);
    expect(restored.isDark, false);
    expect(restored.clickRowToCopy, true);
    expect(restored.clickRowToFill, true);
    expect(restored.showCopyButton, false);
    expect(restored.autoCapture, false);
    expect(restored.rightClickToPaste, true);
    expect(restored.dragToPaste, true);
    expect(restored.autoBackup, true);
    expect(restored.hasCompletedInitialSetup, true);
    expect(restored.autoRibbonColor, true);
  });

  test('ClipItem isAuto serialization and deserialization', () {
    final clip = ClipItem(
      id: 'test_auto_1',
      title: 'Auto Clip',
      content: 'Auto Copied Content',
      createdAt: DateTime.now(),
      isAuto: true,
    );

    final json = clip.toJson();
    expect(json['isAuto'], true);

    final restored = ClipItem.fromJson(json);
    expect(restored.isAuto, true);
    expect(restored.title, 'Auto Clip');
    expect(restored.content, 'Auto Copied Content');
  });

  testWidgets('Auto clipboard capture saves to Auto tab; stays in Auto tab on copy; scissor button moves to All tab', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String simulatedClipboard = 'initial text';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': simulatedClipboard};
        }
        return null;
      },
    );

    await tester.pumpWidget(const ClipDockApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Simulate external copy event
    simulatedClipboard = 'https://flutter.dev/gems';
    // Advance time by 700ms to trigger periodic clipboard timer and pump animations
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // In All tab, auto-captured clip should NOT be visible
    expect(find.text('https://flutter.dev/gems'), findsNothing);

    // Switch to Auto tab
    await tester.ensureVisible(find.textContaining('Auto (1)'));
    await tester.tap(find.textContaining('Auto (1)'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // In Auto tab, auto-captured clip IS visible
    expect(find.textContaining('https://flutter.dev/gems'), findsOneWidget);

    // Hover mouse over clip card to reveal overlay action buttons
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.byType(ClipCard).first));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Verify Scissor icon is present in Auto tab overlay
    expect(find.byIcon(Icons.content_cut_rounded), findsOneWidget);

    // Copy the clip in Auto tab -> clip stays in Auto tab and copies only
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(find.textContaining('Copied clip #'), findsOneWidget);

    // Still in Auto tab and still 1 item in Auto tab
    expect(find.textContaining('Auto (1)'), findsOneWidget);

    // Move mouse back over card to ensure overlay is active and tap Scissor icon
    await gesture.moveTo(tester.getCenter(find.byType(ClipCard).first));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.content_cut_rounded));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(find.text('Moved clip to Clips tab'), findsOneWidget);

    // Switch back to Clips tab
    await tester.ensureVisible(find.textContaining('Clips ('));
    await tester.tap(find.textContaining('Clips ('));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // Now it IS visible in Clips tab
    expect(find.textContaining('https://flutter.dev/gems'), findsOneWidget);

    // Let pending timers finish
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Explicit paste button sends clip to Clips tab and repeated paste brings old item to top', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String simulatedClipboard = 'initial item 1';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': simulatedClipboard};
        }
        return null;
      },
    );

    await tester.pumpWidget(const ClipDockApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Paste item 1 via Paste button
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // Ensure item 1 is in Clips tab
    expect(find.textContaining('initial item 1'), findsOneWidget);
    expect(find.textContaining('Clips (1)'), findsOneWidget);

    // Now paste item 2
    simulatedClipboard = 'second item 2';
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(find.textContaining('second item 2'), findsOneWidget);
    expect(find.textContaining('Clips (2)'), findsOneWidget);

    // Now paste repeated item 1 again: old item 1 should come to top
    simulatedClipboard = 'initial item 1';
    await tester.tap(find.text('Paste'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Clip moved to top'), findsOneWidget);
    expect(find.textContaining('Clips (2)'), findsOneWidget);

    final firstClipCard = tester.widget<ClipCard>(find.byType(ClipCard).first);
    expect(firstClipCard.item.content, 'initial item 1');

    // Let pending timers finish
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('In Auto tab repeated detected item moves to top and Clear All empties auto clips', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String simulatedClipboard = 'initial auto';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': simulatedClipboard};
        }
        return null;
      },
    );

    await tester.pumpWidget(const ClipDockApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Capture first auto item
    simulatedClipboard = 'first auto item';
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Capture second auto item
    simulatedClipboard = 'second auto item';
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Switch to Auto tab
    await tester.ensureVisible(find.textContaining('Auto (2)'));
    await tester.tap(find.textContaining('Auto (2)'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // Top item should be 'second auto item'
    var firstCard = tester.widget<ClipCard>(find.byType(ClipCard).first);
    expect(firstCard.item.content, 'second auto item');

    // Now copy 'first auto item' again externally: it should automatically move to the top
    simulatedClipboard = 'first auto item';
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Top item should now be 'first auto item'
    firstCard = tester.widget<ClipCard>(find.byType(ClipCard).first);
    expect(firstCard.item.content, 'first auto item');

    // In Auto tab, Clear All button should be visible
    expect(find.text('Clear All'), findsOneWidget);

    // Tap Clear All
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // Auto tab should now be empty (0 items)
    expect(find.textContaining('Auto (0)'), findsOneWidget);
    expect(find.textContaining('Trash (2)'), findsOneWidget);

    // Let pending timers finish
    await tester.pump(const Duration(seconds: 4));
  });
}
