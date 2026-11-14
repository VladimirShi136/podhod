import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'notebook/notebook_screen.dart';

class PodhodApp extends StatelessWidget {
  const PodhodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Подход',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const NotebookScreen(),
    );
  }
}
