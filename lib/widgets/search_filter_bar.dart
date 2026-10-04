import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ClipTab {
  all,
  auto,
  starred,
  trash,
}

enum MediaFilter {
  all,
  text,
  image,
}

class SearchFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isDark;
  final int allCount;
  final int autoCount;
  final int starredCount;
  final int trashCount;
  final ClipTab activeTab;
  final MediaFilter activeMediaFilter;
  final int textCount;
  final int imageCount;
  final ValueChanged<ClipTab> onTabChanged;
  final ValueChanged<MediaFilter> onMediaFilterChanged;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onPaste;
  final VoidCallback? onEmptyTrash;
  final VoidCallback? onClearAuto;

  const SearchFilterBar({
    super.key,
    required this.controller,
    this.focusNode,
    required this.isDark,
    required this.allCount,
    required this.autoCount,
    required this.starredCount,
    required this.trashCount,
    required this.activeTab,
    this.activeMediaFilter = MediaFilter.all,
    this.textCount = 0,
    this.imageCount = 0,
    required this.onTabChanged,
    required this.onMediaFilterChanged,
    required this.onChanged,
    required this.onClear,
    this.onPaste,
    this.onEmptyTrash,
    this.onClearAuto,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final inputBg = isDark ? AppColors.darkGlassSurface : AppColors.lightGlassSurface;
    final borderColor = isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search Box with Vertically Centered Icon and Placeholder
          Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Prefix Search Icon
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 6),
                  child: Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: subtextColor,
                  ),
                ),

                // Search TextField (Vertically Centered)
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: activeTab == ClipTab.trash
                          ? 'Search trash clips...'
                          : (activeTab == ClipTab.auto
                              ? 'Search auto clips...'
                              : 'Search stored clips...'),
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: subtextColor,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),

                // Clear Button if text present
                if (controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 14),
                    onPressed: onClear,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    splashRadius: 12,
                    color: subtextColor,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tabs [All, Auto, Starred, Trash] on Left, [Paste / Empty Trash] on Right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Filter Tabs (All, Auto, Starred, Trash)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tab 1: Clips
                      InkWell(
                        onTap: () => onTabChanged(ClipTab.all),
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: activeTab == ClipTab.all
                                    ? (isDark ? AppColors.accentSilver : AppColors.lightHandle)
                                    : Colors.transparent,
                                width: 2.0,
                              ),
                            ),
                          ),
                          child: Text(
                            'Clips ($allCount)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: activeTab == ClipTab.all ? FontWeight.w700 : FontWeight.w500,
                              color: activeTab == ClipTab.all ? textColor : subtextColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),

                      // Tab 2: Starred clips
                      InkWell(
                        onTap: () => onTabChanged(ClipTab.starred),
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: activeTab == ClipTab.starred
                                    ? AppColors.accentAmber
                                    : Colors.transparent,
                                width: 2.0,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                activeTab == ClipTab.starred ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 12,
                                color: activeTab == ClipTab.starred ? AppColors.accentAmber : subtextColor,
                              ),
                              const SizedBox(width: 2.5),
                              Text(
                                'Starred ($starredCount)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: activeTab == ClipTab.starred ? FontWeight.w700 : FontWeight.w500,
                                  color: activeTab == ClipTab.starred
                                      ? (isDark ? Colors.amber[200] : Colors.amber[800])
                                      : subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),

                      // Tab 3: Auto-captured clips
                      InkWell(
                        onTap: () => onTabChanged(ClipTab.auto),
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: activeTab == ClipTab.auto
                                    ? AppColors.accentCyan
                                    : Colors.transparent,
                                width: 2.0,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LightningBoltIcon(
                                size: 11.5,
                                color: activeTab == ClipTab.auto ? AppColors.accentCyan : subtextColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Auto ($autoCount)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: activeTab == ClipTab.auto ? FontWeight.w700 : FontWeight.w500,
                                  color: activeTab == ClipTab.auto
                                      ? (isDark ? AppColors.accentCyan : const Color(0xFF0284C7))
                                      : subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),

                      // Tab 4: Trash
                      InkWell(
                        onTap: () => onTabChanged(ClipTab.trash),
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: activeTab == ClipTab.trash
                                    ? const Color(0xFFFB7185)
                                    : Colors.transparent,
                                width: 2.0,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 12,
                                color: activeTab == ClipTab.trash
                                    ? const Color(0xFFFB7185)
                                    : subtextColor,
                              ),
                              const SizedBox(width: 2.5),
                              Text(
                                'Trash ($trashCount)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: activeTab == ClipTab.trash ? FontWeight.w700 : FontWeight.w500,
                                  color: activeTab == ClipTab.trash
                                      ? (isDark ? const Color(0xFFFDA4AF) : const Color(0xFFE11D48))
                                      : subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Action Button on Right (Clear All in Auto tab, Empty Trash in Trash tab)
              if (activeTab == ClipTab.trash)
                if (trashCount > 0 && onEmptyTrash != null)
                  InkWell(
                    onTap: onEmptyTrash,
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFFF43F5E).withAlpha(30) : const Color(0xFFF43F5E).withAlpha(20),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: const Color(0xFFF43F5E).withAlpha(120),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_sweep_outlined,
                            size: 12,
                            color: Color(0xFFFB7185),
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Empty',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFB7185),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink()
              else if (activeTab == ClipTab.auto)
                if (autoCount > 0 && onClearAuto != null)
                  Tooltip(
                    message: 'Clear all auto-captured clips',
                    child: InkWell(
                      onTap: onClearAuto,
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFFF43F5E).withAlpha(30) : const Color(0xFFF43F5E).withAlpha(20),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color(0xFFF43F5E).withAlpha(120),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_sweep_outlined,
                              size: 12,
                              color: Color(0xFFFB7185),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Clear All',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFB7185),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink()
              else
                const SizedBox.shrink(),
            ],
          ),

          // Sub-tabs [Text, Image] when multiple media types exist, or when any filter is active
          if ((textCount > 0 && imageCount > 0) || activeMediaFilter != MediaFilter.all) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                InkWell(
                  onTap: () => onMediaFilterChanged(MediaFilter.all),
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: activeMediaFilter == MediaFilter.all
                              ? (isDark ? AppColors.accentSilver : AppColors.lightHandle)
                              : Colors.transparent,
                          width: 2.0,
                        ),
                      ),
                    ),
                    child: Text(
                      'All',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: activeMediaFilter == MediaFilter.all ? FontWeight.w700 : FontWeight.w500,
                        color: activeMediaFilter == MediaFilter.all ? textColor : subtextColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => onMediaFilterChanged(MediaFilter.text),
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: activeMediaFilter == MediaFilter.text
                              ? (isDark ? AppColors.accentCyan : const Color(0xFF0284C7))
                              : Colors.transparent,
                          width: 2.0,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.text_fields_rounded,
                          size: 11,
                          color: activeMediaFilter == MediaFilter.text ? (isDark ? AppColors.accentCyan : const Color(0xFF0284C7)) : subtextColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Text ($textCount)',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: activeMediaFilter == MediaFilter.text ? FontWeight.w700 : FontWeight.w500,
                            color: activeMediaFilter == MediaFilter.text ? (isDark ? AppColors.accentCyan : const Color(0xFF0284C7)) : subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => onMediaFilterChanged(MediaFilter.image),
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: activeMediaFilter == MediaFilter.image
                              ? AppColors.accentEmerald
                              : Colors.transparent,
                          width: 2.0,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 11,
                          color: activeMediaFilter == MediaFilter.image ? AppColors.accentEmerald : subtextColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Image ($imageCount)',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: activeMediaFilter == MediaFilter.image ? FontWeight.w700 : FontWeight.w500,
                            color: activeMediaFilter == MediaFilter.image ? AppColors.accentEmerald : subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class LightningBoltIcon extends StatelessWidget {
  final double size;
  final Color color;

  const LightningBoltIcon({
    super.key,
    this.size = 11.5,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.72, size),
      painter: _LightningBoltPainter(color),
    );
  }
}

class _LightningBoltPainter extends CustomPainter {
  final Color color;

  _LightningBoltPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.62, 0);
    path.lineTo(size.width * 0.05, size.height * 0.54);
    path.lineTo(size.width * 0.48, size.height * 0.54);
    path.lineTo(size.width * 0.38, size.height);
    path.lineTo(size.width * 0.95, size.height * 0.42);
    path.lineTo(size.width * 0.52, size.height * 0.42);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LightningBoltPainter oldDelegate) => oldDelegate.color != color;
}
