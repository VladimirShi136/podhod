import 'package:flutter/widgets.dart';

import '../../core/widgets/placeholder_page.dart';

class ProgramsPage extends StatelessWidget {
  const ProgramsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Программы',
      subtitle: 'Сохранённые комплексы',
      stage: 9,
    );
  }
}
