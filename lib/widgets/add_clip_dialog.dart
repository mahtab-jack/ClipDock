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

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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

                // Content Field
                Text(
                  'Clip Content (Text to copy)',
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
                    controller: _contentController,
                    maxLines: 4,
                    style: TextStyle(fontSize: 12, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Type or paste the text content here...',
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
    );
  }
}
