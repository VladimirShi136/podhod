import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/settings/reminder_sync.dart';
import 'notebook/notebook_screen.dart';

class PodhodApp extends ConsumerWidget {
  const PodhodApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Держит расписание напоминаний в актуальном состоянии.
    ref.watch(reminderSyncProvider);

    return MaterialApp(
      title: 'Подход',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Системный масштаб шрифта ограничен, иначе тетрадная сетка «поплывёт».
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.15,
        child: child!,
      ),
      home: const NotebookScreen(),
    );
  }
}
