import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/clip_item.dart';
import '../theme/app_theme.dart';
import 'edge_dock_widget.dart' show ToastType;
import 'telegram_icon.dart';

class ClipCard extends StatefulWidget {
  final int serialNo;
  final ClipItem item;
  final bool isDark;
  final bool isTrash;
  final bool isAuto;
  final int displayLines;
  final bool clickRowToCopy;
  final bool clickRowToFill;
  final bool showCopyButton;
  final bool dragToPaste;
  final Function(String message, [ToastType type])? onNotify;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleStar;
  final VoidCallback? onMoveToAll;
  final VoidCallback? onRestore;
  final VoidCallback? onDeleteForever;
  final VoidCallback? onSendTelegram;
  final bool isSendingTelegram;
  final Function(String? colorHex)? onColorChanged;
  final ValueChanged<bool>? onDialogOpen;

  const ClipCard({
    super.key,
    required this.serialNo,
    required this.item,
    required this.isDark,
    this.isTrash = false,
    this.isAuto = false,
    this.displayLines = 2,
    this.clickRowToCopy = false,
    this.clickRowToFill = true,
    this.showCopyButton = true,
    this.dragToPaste = true,
    this.onNotify,
    this.onCopy,
    this.onEdit,
    this.onDelete,
    this.onToggleStar,
    this.onMoveToAll,
    this.onRestore,
    this.onDeleteForever,
    this.onSendTelegram,
    this.isSendingTelegram = false,
    this.onColorChanged,
    this.onDialogOpen,
  });

  @override
  State<ClipCard> createState() => _ClipCardState();
}

class _ClipCardState extends State<ClipCard> {
  static const MethodChannel _dragDropChannel = MethodChannel('cnote/drag_drop');
  bool _isCopied = false;
  bool _isHovered = false;
  Timer? _copiedResetTimer;

  void _showColorPickerPopup(BuildContext context) {
    widget.onDialogOpen?.call(true);
    final isDark = widget.isDark;
    const List<String> solidColors = [
      '#EF4444', // Red
      '#F97316', // Orange
      '#F59E0B', // Amber
      '#10B981', // Emerald
      '#06B6D4', // Cyan
      '#3B82F6', // Blue
      '#8B5CF6', // Purple
      '#EC4899', // Pink
      '#64748B', // Slate
    ];

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          alignment: Alignment.center,
          child: Container(
            width: 210,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 100 : 35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Label Color',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (widget.item.labelColor != null)
                      InkWell(
                        onTap: () {
                          widget.onColorChanged?.call(null);
                          Navigator.of(ctx).pop();
                        },
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: solidColors.map((hex) {
                    final color = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                    final isSelected = widget.item.labelColor?.toUpperCase() == hex.toUpperCase();
                    return InkWell(
                      onTap: () {
                        widget.onColorChanged?.call(hex);
                        Navigator.of(ctx).pop();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : Border.all(color: Colors.black12, width: 1),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 13, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      widget.onDialogOpen?.call(false);
    });
  }

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  void _copyToClipboard() {
    if (widget.item.isImage && widget.item.imagePath != null) {
      try {
        _dragDropChannel.invokeMethod('copyImageToClipboard', {
          'filePath': widget.item.imagePath,
        });
      } catch (_) {}
    } else {
      Clipboard.setData(ClipboardData(text: widget.item.content));
    }

    _copiedResetTimer?.cancel();
    setState(() {
      _isCopied = true;
    });

    if (widget.onCopy != null) {
      widget.onCopy!();
    } else {
      widget.onNotify?.call(widget.item.isImage ? 'Copied image #${widget.serialNo}' : 'Copied clip #${widget.serialNo}');
    }

    _copiedResetTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  Future<void> _fillIntoActiveWindow() async {
    final shouldAlsoCopy = widget.clickRowToCopy;
    String? targetApp;
    if (widget.item.isImage && widget.item.imagePath != null) {
      try {
        targetApp = await _dragDropChannel.invokeMethod<String>('fillImageIntoActiveWindow', {
          'filePath': widget.item.imagePath,
        });
      } catch (_) {}
      final success = targetApp != null && targetApp.isNotEmpty;
      if (success) {
        final appLabel = targetApp == 'active window' ? 'active window' : targetApp;
        widget.onNotify?.call('Filled image #${widget.serialNo} into $appLabel', ToastType.success);
      } else {
        widget.onNotify?.call('No active input found to fill', ToastType.warning);
      }
    } else {
      if (shouldAlsoCopy) {
        Clipboard.setData(ClipboardData(text: widget.item.content));
      }
      try {
        targetApp = await _dragDropChannel.invokeMethod<String>('fillTextIntoActiveWindow', {
          'text': widget.item.content,
          'restoreClipboard': !shouldAlsoCopy,
        });
      } catch (_) {}
      final success = targetApp != null && targetApp.isNotEmpty;
      if (success) {
        final appLabel = targetApp == 'active window' ? 'active window' : targetApp;
        widget.onNotify?.call('Filled clip #${widget.serialNo} into $appLabel', ToastType.success);
      } else {
        widget.onNotify?.call('No active input found to fill', ToastType.warning);
      }
    }

    if (shouldAlsoCopy && (targetApp != null && targetApp.isNotEmpty)) {
      _copiedResetTimer?.cancel();
      setState(() {
        _isCopied = true;
      });

      _copiedResetTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() {
            _isCopied = false;
          });
        }
      });
    }
  }

  void _handleRowTap() {
    if (widget.isTrash) return;
    if (widget.clickRowToFill) {
      _fillIntoActiveWindow();
    } else if (widget.clickRowToCopy) {
      _copyToClipboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark
        ? (_isHovered ? AppColors.darkGlassCardHover : AppColors.darkGlassCard)
        : (_isHovered ? AppColors.lightGlassCardHover : AppColors.lightGlassCard);

    final borderColor = _isHovered
        ? (isDark ? AppColors.silverGlow : AppColors.lightBorder)
        : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle);

    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    Color? customLabelColor;
    if (widget.item.labelColor != null && widget.item.labelColor!.isNotEmpty) {
      try {
        final hex = widget.item.labelColor!.replaceAll('#', '');
        customLabelColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    final cardContent = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTap: widget.isTrash ? null : widget.onEdit,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
        },
        onExit: (_) {
          setState(() => _isHovered = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _isCopied ? AppColors.accentEmerald : borderColor,
              width: _isCopied || _isHovered ? 1.3 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withAlpha(50)
                          : Colors.black.withAlpha(15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Serial Number / Custom Color Label Pill
              Container(
                constraints: const BoxConstraints(minWidth: 26),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: customLabelColor != null
                      ? customLabelColor.withAlpha(isDark ? 45 : 30)
                      : (isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: customLabelColor ?? (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                    width: customLabelColor != null ? 1.2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${widget.serialNo}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: customLabelColor ?? (isDark ? AppColors.accentSilver : AppColors.lightTextSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Content & Time + Character Count (Clickable to Fill/Copy if enabled)
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: (widget.clickRowToFill || widget.clickRowToCopy) ? _handleRowTap : null,
                      onSecondaryTap: widget.isTrash ? null : widget.onEdit,
                      child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: widget.item.isImage
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.item.customTitle != null && widget.item.customTitle!.trim().isNotEmpty) ...[
                                  Text(
                                    widget.item.customTitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                ],
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final maxImgWidth = constraints.maxWidth * 0.70;
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth: maxImgWidth,
                                            maxHeight: 180,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                                              width: 1,
                                            ),
                                          ),
                                          child: widget.item.imagePath != null && File(widget.item.imagePath!).existsSync()
                                              ? Image.file(
                                                  File(widget.item.imagePath!),
                                                  fit: BoxFit.contain, // Fit, NOT cover!
                                                  errorBuilder: (context, error, stackTrace) => Padding(
                                                    padding: const EdgeInsets.all(12),
                                                    child: Icon(
                                                      Icons.image_not_supported_rounded,
                                                      size: 24,
                                                      color: subtextColor,
                                                    ),
                                                  ),
                                                )
                                              : Padding(
                                                  padding: const EdgeInsets.all(12),
                                                  child: Icon(
                                                    Icons.image_rounded,
                                                    size: 24,
                                                    color: subtextColor,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.item.timeAgo} • Image',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: subtextColor,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  (widget.item.customTitle != null && widget.item.customTitle!.trim().isNotEmpty)
                                      ? widget.item.customTitle!
                                      : (widget.item.content.isNotEmpty ? widget.item.content : widget.item.title),
                                  maxLines: widget.displayLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${widget.item.timeAgo} • ${widget.item.content.length} chars',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: subtextColor,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Action buttons overlay: shown when mouse enters this specific clip row
                  if (_isHovered)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A).withAlpha(240)
                              : const Color(0xFFFFFFFF).withAlpha(245),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 90 : 30),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.isTrash) ...[
                              if (widget.onRestore != null)
                                Tooltip(
                                  message: 'Restore clip',
                                  child: IconButton(
                                    onPressed: widget.onRestore,
                                    iconSize: 15,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                    splashRadius: 11,
                                    icon: const Icon(
                                      Icons.restore_rounded,
                                      color: AppColors.accentEmerald,
                                    ),
                                  ),
                                ),
                              if (widget.onDeleteForever != null)
                                Tooltip(
                                  message: 'Delete permanently',
                                  child: IconButton(
                                    onPressed: widget.onDeleteForever,
                                    iconSize: 15,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                    splashRadius: 11,
                                    icon: const Icon(
                                      Icons.delete_forever_rounded,
                                      color: Color(0xFFFB7185),
                                    ),
                                  ),
                                ),
                            ] else ...[
                              if (widget.isAuto) ...[
                                if (widget.onMoveToAll != null)
                                  Tooltip(
                                    message: 'Move to Clips tab',
                                    child: IconButton(
                                      onPressed: widget.onMoveToAll,
                                      iconSize: 14,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                      splashRadius: 11,
                                      icon: Icon(
                                        Icons.content_cut_rounded,
                                        color: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                                      ),
                                    ),
                                  ),
                              ] else ...[
                                Tooltip(
                                  message: widget.item.isStarred ? 'Unstar clip' : 'Star clip',
                                  child: IconButton(
                                    onPressed: widget.onToggleStar,
                                    iconSize: 15,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                    splashRadius: 11,
                                    icon: Icon(
                                      widget.item.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                                      color: widget.item.isStarred ? AppColors.accentAmber : subtextColor,
                                    ),
                                  ),
                                ),
                              ],
                              // Individual Label Color Picker (Text clips only)
                              if (!widget.item.isImage && widget.onColorChanged != null)
                                Tooltip(
                                  message: customLabelColor != null ? 'Change label color' : 'Set label color',
                                  child: IconButton(
                                    onPressed: () => _showColorPickerPopup(context),
                                    iconSize: 13,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                    splashRadius: 11,
                                    icon: customLabelColor != null
                                        ? Container(
                                            width: 11,
                                            height: 11,
                                            decoration: BoxDecoration(
                                              color: customLabelColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isDark ? Colors.white70 : Colors.black45,
                                                width: 1.2,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.palette_outlined,
                                            size: 13,
                                            color: subtextColor,
                                          ),
                                  ),
                                ),
                              if (widget.onEdit != null)
                                Tooltip(
                                  message: 'Edit clip',
                                  child: IconButton(
                                    onPressed: widget.onEdit,
                                    iconSize: 13,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                    splashRadius: 11,
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: subtextColor,
                                    ),
                                  ),
                                ),
                              if (widget.onSendTelegram != null)
                                Tooltip(
                                  message: widget.isSendingTelegram
                                      ? 'Sending to Telegram...'
                                      : 'Send to Telegram channel',
                                  child: IconButton(
                                    onPressed: widget.isSendingTelegram ? null : widget.onSendTelegram,
                                    iconSize: 13,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                    splashRadius: 11,
                                    icon: widget.isSendingTelegram
                                        ? const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2AABEE)),
                                            ),
                                          )
                                        : const TelegramIcon(
                                            size: 13,
                                            color: Color(0xFF2AABEE),
                                          ),
                                  ),
                                ),
                              if (widget.onDelete != null)
                                Tooltip(
                                  message: 'Move to trash',
                                  child: IconButton(
                                    onPressed: widget.onDelete,
                                    iconSize: 13,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                    splashRadius: 11,
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: subtextColor,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Copy Button with Icon on Top and Label "Copy" Below
            if (widget.showCopyButton || !widget.clickRowToCopy) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: _isCopied ? 'Copied to clipboard' : 'Copy clip content',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _copyToClipboard,
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isCopied
                            ? AppColors.accentEmerald.withAlpha(45)
                            : (_isHovered
                                ? (isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface)
                                : Colors.transparent),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isCopied
                              ? AppColors.accentEmerald
                              : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 13,
                            color: _isCopied
                                ? AppColors.accentEmerald
                                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isCopied ? 'Copied' : 'Copy',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: _isCopied
                                  ? AppColors.accentEmerald
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

    return cardContent;
  }
}
