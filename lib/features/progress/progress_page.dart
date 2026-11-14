import 'package:flutter/widgets.dart';

import '../../core/widgets/placeholder_page.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Прогресс',
      subtitle: 'Объём и личные рекорды',
      stage: 8,
    );
  }
}
