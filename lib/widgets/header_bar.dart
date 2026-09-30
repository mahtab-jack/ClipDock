import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';

class HeaderBar extends StatelessWidget {
  final bool isDark;
  final bool isPinned;
  final int totalClips;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleTheme;
  final VoidCallback onCollapse;
  final VoidCallback onAdd;
  final VoidCallback? onPaste;
  final VoidCallback? onMinimize;

  const HeaderBar({
    super.key,
    required this.isDark,
    required this.isPinned,
    required this.totalClips,
    required this.onTogglePin,
    required this.onToggleTheme,
    required this.onCollapse,
    required this.onAdd,
    this.onPaste,
    this.onMinimize,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Title with Total Count
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Clip Dock ($totalClips)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          // Paste Button on Top Bar before Add button
          if (onPaste != null) ...[
            Tooltip(
              message: 'Paste from Windows Clipboard',
              child: InkWell(
                onTap: onPaste,
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.accentSilver.withAlpha(35)
                        : AppColors.lightHandle.withAlpha(25),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isDark ? AppColors.accentSilver.withAlpha(120) : AppColors.lightHandle.withAlpha(120),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.paste_rounded,
                        size: 11,
                        color: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Paste',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.accentSilver : AppColors.lightHandle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],

          // + Add Button on Top Header
          Tooltip(
            message: 'Add New Clip',
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.accentCyan.withAlpha(35)
                      : AppColors.lightHandle.withAlpha(25),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isDark ? AppColors.accentCyan.withAlpha(140) : AppColors.lightHandle.withAlpha(140),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '+',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        color: isDark ? AppColors.accentCyan : AppColors.lightHandle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.accentCyan : AppColors.lightHandle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Pin Toggle Button
          Tooltip(
            message: isPinned ? 'Unpin (Auto-hide on mouse exit)' : 'Pin Open (Keep visible)',
            child: SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                onPressed: onTogglePin,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(24, 24),
                  fixedSize: const Size(24, 24),
                ),
                icon: Icon(
                  isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  size: 14,
                  color: isPinned
                      ? (isDark ? AppColors.accentCyan : AppColors.accentBlue)
                      : subtextColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),

          // Theme Toggle Button
          Tooltip(
            message: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
            child: SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                onPressed: onToggleTheme,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(24, 24),
                  fixedSize: const Size(24, 24),
                ),
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 14,
                  color: subtextColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),

          // Collapse Button (Hide dock)
          Tooltip(
            message: 'Collapse Dock',
            child: SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                onPressed: onCollapse,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(24, 24),
                  fixedSize: const Size(24, 24),
                ),
                icon: CollapseChevronIcon(
                  color: isDark ? AppColors.accentSilver : AppColors.lightTextPrimary,
                  size: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),

          // Minimize Button
          Tooltip(
            message: 'Minimize to Tray',
            child: SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                onPressed: onMinimize ?? () => windowManager.hide(),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(24, 24),
                  fixedSize: const Size(24, 24),
                ),
                icon: Center(
                  child: Container(
                    width: 12,
                    height: 2.4,
                    decoration: BoxDecoration(
                      color: subtextColor,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CollapseChevronIcon extends StatelessWidget {
  final Color color;
  final double size;

  const CollapseChevronIcon({
    super.key,
    required this.color,
    this.size = 13,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CollapseChevronPainter(color: color),
      ),
    );
  }
}

class _CollapseChevronPainter extends CustomPainter {
  final Color color;

  _CollapseChevronPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Single chevron <
    path.moveTo(w * 0.65, h * 0.18);
    path.lineTo(w * 0.30, h * 0.50);
    path.lineTo(w * 0.65, h * 0.82);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CollapseChevronPainter oldDelegate) =>
      oldDelegate.color != color;
}
