import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/clip_item.dart';
import '../theme/app_theme.dart';

class ClipCard extends StatefulWidget {
  final int serialNo;
  final ClipItem item;
  final bool isDark;
  final bool isTrash;
  final bool isAuto;
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

  const ClipCard({
    super.key,
    required this.serialNo,
    required this.item,
    required this.isDark,
    this.isTrash = false,
    this.isAuto = false,
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
    Clipboard.setData(ClipboardData(text: widget.item.content));
    _copiedResetTimer?.cancel();
    setState(() {
      _isCopied = true;
    });

    if (widget.onCopy != null) {
      widget.onCopy!();
    } else {
      widget.onNotify?.call('Copied clip #${widget.serialNo}');
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
    Clipboard.setData(ClipboardData(text: widget.item.content));
    _copiedResetTimer?.cancel();
    setState(() {
      _isCopied = true;
    });

    try {
      _dragDropChannel.invokeMethod('fillTextIntoActiveWindow', {
        'text': widget.item.content,
      });
    } catch (_) {}

    widget.onNotify?.call('Filled clip #${widget.serialNo} into active window');

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

    final cardContent = MouseRegion(
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
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: (widget.clickRowToFill || widget.clickRowToCopy) ? _handleRowTap : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.item.title.isNotEmpty ? widget.item.title : widget.item.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
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

            const SizedBox(width: 4),

            if (widget.isTrash) ...[
              // Trash Mode: Restore Button
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

              // Trash Mode: Delete Permanently Button
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
              // Auto Mode: Scissor Icon to Move to All tab
              if (widget.isAuto) ...[
                if (widget.onMoveToAll != null)
                  Tooltip(
                    message: 'Move to All tab',
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
                // Normal Active Mode: Star / Favorite Button
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

              // Active Mode: Edit Button
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

              // Active Mode: Delete (Move to Trash) Button
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

            // Copy Button with Label (shown if showCopyButton is true OR if clickRowToCopy is false)
            if (widget.showCopyButton || !widget.clickRowToCopy) ...[
              const SizedBox(width: 3),
              Tooltip(
                message: _isCopied ? 'Copied to clipboard' : 'Copy clip content',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _copyToClipboard,
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 12,
                            color: _isCopied
                                ? AppColors.accentEmerald
                                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isCopied ? 'Copied' : 'Copy',
                            style: TextStyle(
                              fontSize: 11,
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
