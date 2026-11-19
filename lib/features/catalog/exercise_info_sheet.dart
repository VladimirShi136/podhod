import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/day_key.dart';
import '../../core/widgets/notebook_widgets.dart';
import '../../data/db/database.dart';
import '../../data/db/enums.dart';
import '../../data/providers.dart';
import '../../data/repositories/catalog_repository.dart';
import '../programs/program_picker.dart';
import '../progress/progress_logic.dart';
import '../progress/progress_providers.dart';
import 'catalog_logic.dart';
import 'catalog_providers.dart';
import 'custom_exercise_dialog.dart';

/// Карточка упражнения. Возвращает true, если упражнение добавили в сегодняшнюю
/// тренировку (вызывающий тогда может перейти на страницу «Сегодня»).
Future<bool?> showExerciseInfo(BuildContext context, int exerciseId) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.88,
      child: ExerciseInfoSheet(exerciseId: exerciseId),
    ),
  );
}

class ExerciseInfoSheet extends ConsumerWidget {
  const ExerciseInfoSheet({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(exerciseInfoProvider(exerciseId)).value;
    if (info == null) return const SizedBox(height: 120);

    final ex = info.exercise;
    final progress = _progressOf(ref, ex.id);
    final ready = readyForHarder(progress) && info.harder.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Text(ex.name, style: AppText.hand(32)),
                  Text(
                    '${ex.muscleGroup.label} · ${ex.kind.label}'
                    '${ex.isCustom ? ' · своё' : ''}',
                    style: AppText.body(15,
                        color: AppColors.ink.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 8),
                  Text(_statsText(progress), style: AppText.body(17)),
                  if (ready) ...[
                    const SizedBox(height: 8),
                    Sticker(
                      '🚀 можно пробовать: '
                      '${info.harder.map((e) => e.name).join(', ')}',
                      fontSize: 14,
                    ),
                  ],
                  if (info.easier.isNotEmpty || info.harder.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('Путь прогрессии', style: AppText.hand(26)),
                    for (final e in info.easier)
                      _ChainRow(
                        exercise: e,
                        caption: 'легче',
                        onTap: () => _open(context, e.id),
                      ),
                    _ChainRow(exercise: ex, caption: 'вы здесь', current: true),
                    for (final e in info.harder)
                      _ChainRow(
                        exercise: e,
                        caption: 'сложнее',
                        onTap: () => _open(context, e.id),
                      ),
                  ],
                  if (ex.isCustom)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _edit(context, ref, ex),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text('Изменить',
                                style: AppText.body(16)),
                          ),
                          TextButton.icon(
                            onPressed: () => _delete(context, ref, ex),
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.red),
                            label: Text('Удалить',
                                style: AppText.body(16, color: AppColors.red)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: NotebookButton(
                    label: 'В программу',
                    onPressed: () async {
                      final name = await addToProgramFlow(context, ref, [ex.id]);
                      if (name != null && context.mounted) {
                        await _info(context, 'Добавлено',
                            'Упражнение добавлено в программу «$name».');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NotebookButton(
                    label: 'В сегодня',
                    filled: true,
                    onPressed: () async {
                      final workouts = ref.read(workoutRepositoryProvider);
                      final id = await workouts.ensureWorkout(
                        dayKey(DateTime.now()),
                      );
                      await workouts.addExercise(
                        workoutId: id,
                        exerciseId: ex.id,
                      );
                      if (context.mounted) Navigator.of(context).pop(true);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ExerciseProgress? _progressOf(WidgetRef ref, int id) {
    final data = ref.watch(progressProvider).value;
    if (data == null) return null;
    for (final e in data.exercises) {
      if (e.exerciseId == id) return e;
    }
    return null;
  }

  String _statsText(ExerciseProgress? p) {
    if (p == null) return 'Вы пока не выполняли это упражнение.';
    return 'Рекорд: ${p.format(p.bestValue)} · '
        '${formatDayShort(parseDayKey(p.bestDay))} · '
        'тренировок: ${p.sessions}';
  }

  Future<void> _open(BuildContext context, int id) async {
    final added = await showExerciseInfo(context, id);
    if (added == true && context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Exercise ex) async {
    final data = await showCustomExerciseDialog(context, edit: ex);
    if (data == null) return;
    final ok = await ref
        .read(catalogRepositoryProvider)
        .updateCustom(ex.id, name: data.name, group: data.group);
    if (!ok && context.mounted) {
      await _info(context, 'Название занято',
          'Упражнение с таким названием уже есть.');
    }
    ref.invalidate(exerciseInfoProvider(ex.id));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Exercise ex) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('Удалить упражнение?', style: AppText.hand(28)),
        content: Text('«${ex.name}» исчезнет из каталога.',
            style: AppText.body(17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена', style: AppText.body(18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                Text('Удалить', style: AppText.body(18, color: AppColors.red)),
          ),
        ],
      ),
    );
    if (sure != true) return;
    final result = await ref.read(catalogRepositoryProvider).deleteCustom(ex.id);
    if (!context.mounted) return;
    if (result == DeleteResult.inUse) {
      await _info(
        context,
        'Нельзя удалить',
        'Упражнение есть в тренировках или программах. Сначала уберите его '
            'оттуда.',
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _info(BuildContext context, String title, String text) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text(title, style: AppText.hand(28)),
        content: Text(text, style: AppText.body(17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Понятно', style: AppText.body(18)),
          ),
        ],
      ),
    );
  }
}

class _ChainRow extends StatelessWidget {
  const _ChainRow({
    required this.exercise,
    required this.caption,
    this.current = false,
    this.onTap,
  });

  final Exercise exercise;
  final String caption;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(caption,
                  style: AppText.body(13,
                      color: current
                          ? AppColors.red
                          : AppColors.ink.withValues(alpha: 0.6))),
            ),
            Expanded(
              child: Text(
                exercise.name,
                style: AppText.body(19).copyWith(
                  fontWeight: current ? FontWeight.bold : null,
                ),
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}
