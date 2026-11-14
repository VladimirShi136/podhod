import 'package:flutter/material.dart';

import '../../notebook/page_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Временное содержимое страницы, пока её экран не сделан.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stage,
    this.isSettings = false,
  });

  final String title;
  final String subtitle;

  /// Номер этапа из ROADMAP.md, на котором страница будет сделана.
  final int stage;

  /// На странице настроек вместо шестерёнки показывается кнопка «назад».
  final bool isSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: title,
          subtitle: subtitle,
          showGear: !isSettings,
          showBack: isSettings,
        ),
        const SizedBox(height: 28),
        Text(
          'Страница-заглушка.\nСделаем на этапе $stage.',
          style: AppText.body(20, color: AppColors.ink.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}
