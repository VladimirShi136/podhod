import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class BookmarkTab {
  const BookmarkTab({
    required this.label,
    required this.icon,
    required this.pageIndex,
    required this.color,
  });

  final String label;
  final IconData icon;
  final int pageIndex;
  final Color color;
}

/// Закладки, которые выглядывают из-под нижнего края тетради.
///
/// Виджет нужно рисовать ПОД тетрадью (раньше неё в Stack): верхняя часть
/// каждой закладки уходит вверх за границы виджета и прячется под страницами.
/// Видно только то, что торчит ниже края тетради. Активная закладка торчит
/// сильнее остальных.
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

  /// Сколько торчит активная / неактивная закладка.
  static const double peekActive = 54;
  static const double peekInactive = 42;

  /// Зазор между самой длинной закладкой и нижним краем экрана.
  static const double bottomGap = 6;

  /// Часть закладки, спрятанная под тетрадью.
  static const double hiddenPart = 24;

  /// Высота, которую виджет занимает на экране.
  static const double height = peekActive + bottomGap;

  static const double _sidePadding = 14;
  static const double _tabGap = 3;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth =
              (constraints.maxWidth - _sidePadding * 2) / tabs.length;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _positionedTab(i, tabWidth),
            ],
          );
        },
      ),
    );
  }

  Widget _positionedTab(int i, double tabWidth) {
    final tab = tabs[i];
    final active = tab.pageIndex == activeIndex;
    final peek = active ? peekActive : peekInactive;

    return AnimatedPositioned(
      key: ValueKey(tab.pageIndex),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: _sidePadding + i * tabWidth + _tabGap,
      width: tabWidth - _tabGap * 2,
      // Неактивные закладки приподняты, активная опущена до нижнего зазора.
      bottom: bottomGap + (peekActive - peek),
      height: peek + hiddenPart,
      child: _TabButton(
        tab: tab,
        active: active,
        onTap: () => onTap(tab.pageIndex),
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
    final base = active ? tab.color : Color.lerp(tab.color, Colors.black, 0.22)!;
    final fg = base.computeLuminance() > 0.45
        ? const Color(0xFF3B2A14)
        : const Color(0xFFF8EFDD);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(base, Colors.black, 0.18)!, base],
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(4),
            bottom: Radius.circular(12),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              offset: Offset(0, 2),
              blurRadius: 3,
            ),
          ],
        ),
        // Верхние hiddenPart пикселей спрятаны под тетрадью, поэтому
        // содержимое выравниваем по видимой нижней части.
        padding: const EdgeInsets.only(top: BookmarkBar.hiddenPart),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: active ? 22 : 18, color: fg),
            const SizedBox(height: 1),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: AppText.body(active ? 13 : 12, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
