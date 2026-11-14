import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
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
  });

  final String title;
  final String? subtitle;
  final bool showGear;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final scope = NotebookScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              if (showBack) ...[
                _CircleButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Назад',
                  onTap: scope.goBack,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.hand(30),
                ),
              ),
              if (showGear)
                _CircleButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Настройки',
                  onTap: () => scope.goTo(kSettingsPage),
                ),
            ],
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: AppText.body(15, color: AppColors.ink.withValues(alpha: 0.7)),
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
