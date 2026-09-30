import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/dock_settings.dart';
import '../theme/app_theme.dart';

class AddClipDialog extends StatefulWidget {
  final bool isDark;
  final DockSettings settings;
  final Function(String title, String content) onAdd;

  const AddClipDialog({
    super.key,
    required this.isDark,
    required this.settings,
    required this.onAdd,
  });

  @override
  State<AddClipDialog> createState() => _AddClipDialogState();
}

class _AddClipDialogState extends State<AddClipDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String? _errorText;

  double? _customContentHeight;
  bool _hasManuallyResized = false;
  static const double _minContentHeight = 85.0;
  static const double _maxContentHeight = 280.0;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  double _getEffectiveContentHeight() {
    if (_hasManuallyResized && _customContentHeight != null) {
      return _customContentHeight!;
    }
    final text = _contentController.text;
    if (text.isEmpty) return _minContentHeight;
    final newlineCount = '\n'.allMatches(text).length + 1;
    final estWrappedLines = (text.length / 36).ceil();
    final lineCount = newlineCount > estWrappedLines ? newlineCount : estWrappedLines;
    if (lineCount <= 3) return _minContentHeight;
    final computed = _minContentHeight + (lineCount - 3) * 20.0;
    return computed.clamp(_minContentHeight, _maxContentHeight);
  }

  void _handleAdd() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      setState(() {
        _errorText = 'Content cannot be empty';
      });
      return;
    }

    final finalTitle = title.isEmpty
        ? (content.length > 35 ? '${content.substring(0, 35)}...' : content)
        : title;

    widget.onAdd(finalTitle, content);
    Navigator.of(context).pop();
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

    final charCount = _contentController.text.length;
    final effectiveHeight = _getEffectiveContentHeight();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.settings.blur,
            sigmaY: widget.settings.blur,
          ),
          child: Container(
            width: 380,
            constraints: const BoxConstraints(maxHeight: 620),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.2),
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
                        Icons.add_circle_outline_rounded,
                        size: 20,
                        color: isDark ? AppColors.accentSilver : AppColors.lightTextPrimary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Add New Clip',
                          style: TextStyle(
                            fontSize: 14,
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
                  const SizedBox(height: 12),

                  // Title Field
                  Text(
                    'Title / Label (Optional)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subtextColor),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                    ),
                    child: TextField(
                      controller: _titleController,
                      autofocus: true,
                      style: TextStyle(fontSize: 12, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'e.g. Work Email, Server IP, Note...',
                        hintStyle: TextStyle(fontSize: 11, color: subtextColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Content Field with Resizer Handle
                  Text(
                    'Clip Content (Text to copy)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subtextColor),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: effectiveHeight,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
                              child: TextField(
                                controller: _contentController,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                style: TextStyle(fontSize: 12, color: textColor),
                                decoration: InputDecoration(
                                  hintText: 'Type or paste the text content here...',
                                  hintStyle: TextStyle(fontSize: 11, color: subtextColor),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Bottom row: Character count on left & Resizer grip on right
                        Positioned(
                          left: 10,
                          right: 3,
                          bottom: 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '$charCount ${charCount == 1 ? 'character' : 'characters'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: subtextColor.withAlpha(160),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanUpdate: (details) {
                                  setState(() {
                                    _hasManuallyResized = true;
                                    final newH = (effectiveHeight + details.delta.dy).clamp(_minContentHeight, _maxContentHeight);
                                    _customContentHeight = newH;
                                  });
                                },
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.resizeDownRight,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    alignment: Alignment.bottomRight,
                                    padding: const EdgeInsets.all(2),
                                    child: CustomPaint(
                                      size: const Size(12, 12),
                                      painter: ResizeGripPainter(
                                        color: subtextColor.withAlpha(isDark ? 190 : 210),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_errorText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _errorText!,
                      style: const TextStyle(fontSize: 11, color: AppColors.accentRose, fontWeight: FontWeight.w500),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel', style: TextStyle(fontSize: 12, color: subtextColor)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _handleAdd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.accentSilver : AppColors.lightTextPrimary,
                          foregroundColor: isDark ? const Color(0xFF000000) : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('+ Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
  }
}

class ResizeGripPainter extends CustomPainter {
  final Color color;
  const ResizeGripPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // 2 diagonal parallel lines matching browser textarea resize grip
    canvas.drawLine(
      Offset(size.width - 2, size.height - 9),
      Offset(size.width - 9, size.height - 2),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 2, size.height - 5),
      Offset(size.width - 5, size.height - 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ResizeGripPainter oldDelegate) => oldDelegate.color != color;
}
