import 'package:flutter/widgets.dart';

import '../../core/widgets/placeholder_page.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Календарь',
      subtitle: 'Оглавление тетради',
      stage: 6,
    );
  }
}
