import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/input_dialogs.dart';
import 'programs_providers.dart';

/// Спрашивает, в какую программу добавить упражнения (или создаёт новую),
/// и добавляет их. Возвращает название программы или null, если отменили.
Future<String?> addToProgramFlow(
  BuildContext context,
  WidgetRef ref,
  List<int> exerciseIds,
) async {
  final repo = ref.read(programRepositoryProvider);
  final programs = await repo.watchAll().first;
  if (!context.mounted) return null;

  // id существующей программы, -1 — создать новую, null — отмена
  final choice = await showDialog<int>(
    context: context,
    builder: (ctx) => SimpleDialog(
      backgroundColor: AppColors.paper,
      title: Text('В какую программу?', style: AppText.hand(28)),
      children: [
        for (final p in programs)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(p.program.id),
            child: Text(p.program.name, style: AppText.body(19)),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(ctx).pop(-1),
          child: Text('+ Новая программа…',
              style: AppText.body(19, color: AppColors.red)),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return null;

  int programId;
  String name;
  if (choice == -1) {
    final typed = await askText(
      context,
      title: 'Название программы',
      hint: 'Например, «Ноги»',
    );
    if (typed == null || typed.trim().isEmpty) return null;
    name = typed.trim();
    programId = await repo.create(name);
  } else {
    programId = choice;
    name = programs.firstWhere((p) => p.program.id == choice).program.name;
  }

  for (final id in exerciseIds) {
    await repo.addExercise(programId, id);
  }
  return name;
}
