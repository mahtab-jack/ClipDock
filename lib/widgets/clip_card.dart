import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/clip_item.dart';
import '../theme/app_theme.dart';
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
  final Function(String message)? onNotify;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleStar;
  final VoidCallback? onMoveToAll;
  final VoidCallback? onRestore;
  final VoidCallback? onDeleteForever;
  final VoidCallback? onSendTelegram;
  final bool isSendingTelegram;

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
  });

  @override
  State<ClipCard> createState() => _ClipCardState();
}

class _ClipCardState extends State<ClipCard> {
  static const MethodChannel _dragDropChannel = MethodChannel('cnote/drag_drop');
  bool _isCopied = false;
  bool _isHovered = false;
  Timer? _copiedResetTimer;

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

  void _fillIntoActiveWindow() {
    if (widget.item.isImage && widget.item.imagePath != null) {
      try {
        _dragDropChannel.invokeMethod('fillImageIntoActiveWindow', {
          'filePath': widget.item.imagePath,
        });
      } catch (_) {}
      widget.onNotify?.call('Filled image #${widget.serialNo} into active window');
    } else {
      Clipboard.setData(ClipboardData(text: widget.item.content));
      try {
        _dragDropChannel.invokeMethod('fillTextIntoActiveWindow', {
          'text': widget.item.content,
        });
      } catch (_) {}
      widget.onNotify?.call('Filled clip #${widget.serialNo} into active window');
    }

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

  void _handleRowTap() {
    if (widget.isTrash) return;
    if (widget.clickRowToFill) {
      _fillIntoActiveWindow();
    } else if (widget.clickRowToCopy) {
      _copyToClipboard();
    }
  }

  void _startNativeDrag() {
    if (!widget.dragToPaste || widget.isTrash) return;
    try {
      Clipboard.setData(ClipboardData(text: widget.item.content));
      _dragDropChannel.invokeMethod('startDragText', {
        'text': widget.item.content,
      });
    } catch (_) {}
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
            children: [
              // Serial Number (Clean Silvery Pill)
              Container(
                constraints: const BoxConstraints(minWidth: 26),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkGlassSurface
                      : AppColors.lightGlassSurface,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${widget.serialNo}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: isDark ? AppColors.accentSilver : AppColors.lightTextSecondary,
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
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Image Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.black26 : Colors.black12,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                                        width: 1,
                                      ),
                                    ),
                                    child: widget.item.imagePath != null && File(widget.item.imagePath!).existsSync()
                                        ? Image.file(
                                            File(widget.item.imagePath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Icon(
                                              Icons.image_not_supported_rounded,
                                              size: 20,
                                              color: subtextColor,
                                            ),
                                          )
                                        : Icon(
                                            Icons.image_rounded,
                                            size: 20,
                                            color: subtextColor,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Title and Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        (widget.item.customTitle != null && widget.item.customTitle!.trim().isNotEmpty)
                                            ? widget.item.customTitle!
                                            : (widget.item.title.isNotEmpty ? widget.item.title : 'Captured Image'),
                                        maxLines: 1,
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
                                        '${widget.item.timeAgo} • Image',
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

    if (!widget.dragToPaste || widget.isTrash) {
      return cardContent;
    }

    return Draggable<ClipItem>(
      data: widget.item,
      onDragStarted: _startNativeDrag,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withAlpha(240) : Colors.white.withAlpha(240),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(90),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.drag_indicator_rounded,
                size: 15,
                color: isDark ? AppColors.accentCyan : const Color(0xFF0284C7),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  widget.item.title.isNotEmpty ? widget.item.title : widget.item.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.item.content.length} chars',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.accentSilver : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: cardContent,
      ),
      child: cardContent,
    );
  }
}
