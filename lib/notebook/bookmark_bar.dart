import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class BookmarkTab {
  const BookmarkTab({
    required this.label,
    required this.icon,
    required this.pageIndex,
  });

  final String label;
  final IconData icon;
  final int pageIndex;
}

/// Нижняя панель навигации в виде закладок. Активная закладка выдвинута.
class BookmarkBar extends StatelessWidget {
  const BookmarkBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onTap,
  });

  final List<BookmarkTab> tabs;

  /// Индекс страницы, которая сейчас открыта (у настроек закладки нет).
  final int activeIndex;
  final ValueChanged<int> onTap;

  static const double height = 68;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final tab in tabs)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _TabButton(
                    tab: tab,
                    active: tab.pageIndex == activeIndex,
                    onTap: () => onTap(tab.pageIndex),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final BookmarkTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? const Color(0xFF3B2A14) : const Color(0xFFF5EAD4);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: active ? 66 : 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: active
                ? const [Color(0xFFF3D27A), Color(0xFFE8B84A)]
                : const [Color(0xFF8A5F3A), Color(0xFF6A4527)],
          ),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(active ? 12 : 0),
            bottom: const Radius.circular(12),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: 22, color: fg),
            const SizedBox(height: 2),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: AppText.body(13, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
