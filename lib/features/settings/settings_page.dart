import 'package:flutter/widgets.dart';

import '../../core/widgets/placeholder_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Настройки',
      subtitle: 'Напоминания, экспорт, тема',
      stage: 10,
      isSettings: true,
    );
  }
}
