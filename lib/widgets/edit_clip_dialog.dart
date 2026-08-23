import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/clip_item.dart';
import '../models/dock_settings.dart';
import '../theme/app_theme.dart';

class EditClipDialog extends StatefulWidget {
  final bool isDark;
  final ClipItem item;
  final int serialNo;
  final DockSettings settings;
  final Function(String newTitle, String newContent) onSave;

  const EditClipDialog({
    super.key,
    required this.isDark,
    required this.item,
    required this.serialNo,
    required this.settings,
    required this.onSave,
  });

  @override
  State<EditClipDialog> createState() => _EditClipDialogState();
}

class _EditClipDialogState extends State<EditClipDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _contentController = TextEditingController(text: widget.item.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      setState(() {
        _errorText = 'Clip content cannot be empty';
      });
      return;
    }

    final finalTitle = title.isEmpty
        ? (content.length > 35 ? '${content.substring(0, 35)}...' : content)
        : title;

    widget.onSave(finalTitle, content);
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.accentSilver.withAlpha(40) : AppColors.lightHandle.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark ? AppColors.accentSilver.withAlpha(100) : AppColors.lightHandle.withAlpha(100),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '#${widget.serialNo}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Edit Clip',
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

                // Title Input
                Text(
                  'Title / Label',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: subtextColor,
                  ),
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
                    style: TextStyle(fontSize: 12, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Clip title / summary...',
                      hintStyle: TextStyle(fontSize: 11, color: subtextColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Content Input
                Text(
                  'Clip Content (Text to copy)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                  ),
                  child: TextField(
                    controller: _contentController,
                    maxLines: 4,
                    style: TextStyle(fontSize: 12, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Edit clip text...',
                      hintStyle: TextStyle(fontSize: 11, color: subtextColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ),

                if (_errorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _errorText!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.accentRose,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontSize: 12, color: subtextColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.accentSilver : AppColors.lightTextPrimary,
                        foregroundColor: isDark ? const Color(0xFF000000) : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
