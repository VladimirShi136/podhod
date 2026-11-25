import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/paper_lines.dart';
import 'notebook_page_def.dart';
import 'notebook_scope.dart';

/// Шапка страницы: рукописный заголовок и шестерёнка настроек справа.
/// На странице настроек вместо шестерёнки показывается кнопка «назад».
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showGear = true,
    this.showBack = false,
    this.wrapTitle = false,
  });

  final String title;
  final String? subtitle;
  final bool showGear;
  final bool showBack;
  final bool wrapTitle;

  @override
  Widget build(BuildContext context) {
    final scope = NotebookScope.of(context);
    final titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          // заголовок стоит на линии, каждая его строка — одна строка тетради
          child: LineText(
            title,
            maxLines: wrapTitle ? null : 1,
            overflow: wrapTitle ? null : TextOverflow.ellipsis,
            style: AppText.hand(30),
          ),
        ),
        // «назад» стоит там же, где на других страницах шестерёнка
        if (showBack)
          Transform.translate(
            offset: const Offset(0, -5),
            child: _CircleButton(
              icon: Icons.arrow_back,
              tooltip: 'Назад',
              onTap: scope.goBack,
            ),
          )
        else if (showGear)
          Transform.translate(
            offset: const Offset(0, -5),
            child: _CircleButton(
              icon: Icons.settings_outlined,
              tooltip: 'Настройки',
              onTap: () => scope.goTo(kSettingsPage),
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Обычные заголовки стоят на второй линейке; переносимый заголовок
        // Today начинает с первой строки даты.
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 2 * kLine),
          child: wrapTitle
              ? titleRow
              : Padding(
                  padding: const EdgeInsets.only(top: kLine / 2),
                  child: titleRow,
                ),
        ),
        if (subtitle != null)
          LineText(
            subtitle!,
            style: AppText.body(
              15,
              color: AppColors.ink.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  static const _shape = CircleBorder(
    side: BorderSide(color: AppColors.ink, width: 2),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: _shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: _shape,
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 22, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}
