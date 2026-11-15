import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/input_dialogs.dart';
import '../../core/widgets/notebook_widgets.dart';
import '../../data/db/database.dart';
import '../../data/db/enums.dart';
import '../../data/providers.dart';
import '../../data/repositories/models.dart';
import 'set_bubble.dart';
import 'sets_format.dart';
import 'today_providers.dart';

/// Открывает редактор подходов упражнения.
Future<void> showExerciseSheet(
  BuildContext context, {
  required int entryId,
  required String day,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (_) => ExerciseSheet(entryId: entryId, day: day),
  );
}

class ExerciseSheet extends ConsumerWidget {
  const ExerciseSheet({super.key, required this.entryId, required this.day});

  final int entryId;
  final String day;

  WorkoutExerciseDetails? _find(WorkoutDetails? w) {
    if (w == null) return null;
    for (final e in w.exercises) {
      if (e.entry.id == entryId) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = _find(ref.watch(workoutDayProvider).value);
    if (details == null) {
      // упражнение удалено: закрываем лист
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox(height: 80);
    }

    final repo = ref.read(workoutRepositoryProvider);
    final kind = details.exercise.kind;
    final isTime = kind == ExerciseKind.time;
    final last = ref
            .watch(lastSetsProvider((details.exercise.id, day)))
            .value ??
        const <WorkoutSet>[];
    final best = ref.watch(bestBeforeProvider((details.exercise.id, day))).value;
    final bestStr = bestText(best, kind);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(details.exercise.name, style: AppText.hand(32)),
              Text(
                '${details.exercise.muscleGroup.label} · ${kind.label}',
                style: AppText.body(15,
                    color: AppColors.ink.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 6),
              if (last.isNotEmpty)
                Text('Прошлый раз: ${setsSummary(last, kind)}',
                    style: AppText.body(16)),
              if (bestStr != null)
                Text('Рекорд: $bestStr', style: AppText.body(16)),
              const SizedBox(height: 10),
              for (var i = 0; i < details.sets.length; i++)
                _SetEditor(
                  index: i,
                  set: details.sets[i],
                  isTime: isTime,
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: NotebookButton(
                      label: '+ подход',
                      onPressed: () {
                        final lastSet =
                            details.sets.isEmpty ? null : details.sets.last;
                        repo.addSet(
                          details.entry.id,
                          reps: isTime ? null : (lastSet?.reps ?? 10),
                          seconds: isTime ? (lastSet?.seconds ?? 30) : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () async {
                  final ok = await _confirmRemove(context);
                  if (ok == true) await repo.removeExercise(details.entry.id);
                },
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                label: Text('Убрать из тренировки',
                    style: AppText.body(16, color: AppColors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmRemove(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('Убрать упражнение?', style: AppText.hand(28)),
        content: Text('Все подходы будут удалены.', style: AppText.body(17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена', style: AppText.body(18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Убрать', style: AppText.body(18, color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

class _SetEditor extends ConsumerWidget {
  const _SetEditor({
    required this.index,
    required this.set,
    required this.isTime,
  });

  final int index;
  final WorkoutSet set;
  final bool isTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(workoutRepositoryProvider);
    final value = (isTime ? set.seconds : set.reps) ?? (isTime ? 30 : 10);
    final step = isTime ? 5 : 1;

    Future<void> save(int v) {
      final clamped = v < 1 ? 1 : v;
      return isTime
          ? repo.updateSet(set.id, seconds: clamped)
          : repo.updateSet(set.id, reps: clamped);
    }

    return SizedBox(
      height: 52,
      child: Row(
        children: [
          SetBubble(
            number: index + 1,
            done: set.done,
            size: 28,
            onTap: () => repo.toggleSet(set.id),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Меньше',
            onPressed: () => save(value - step),
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.ink,
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final v = await askNumber(
                context,
                title: isTime ? 'Секунды' : 'Повторения',
                initial: value,
                suffix: isTime ? 'с' : null,
              );
              if (v != null) await save(v);
            },
            child: SizedBox(
              width: 80,
              child: Text(
                isTime ? '$value с' : '$value',
                textAlign: TextAlign.center,
                style: AppText.hand(32),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Больше',
            onPressed: () => save(value + step),
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.ink,
          ),
          IconButton(
            tooltip: 'Удалить подход',
            onPressed: () => repo.removeSet(set.id),
            icon: const Icon(Icons.close),
            color: AppColors.red,
          ),
        ],
      ),
    );
  }
}
