import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/day_key.dart';
import '../../data/db/enums.dart';
import 'progress_chart.dart';
import 'progress_logic.dart';
import 'progress_providers.dart';

Future<void> showExerciseProgress(BuildContext context, int exerciseId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: ExerciseProgressSheet(exerciseId: exerciseId),
    ),
  );
}

class ExerciseProgressSheet extends ConsumerStatefulWidget {
  const ExerciseProgressSheet({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  ConsumerState<ExerciseProgressSheet> createState() =>
      _ExerciseProgressSheetState();
}

class _ExerciseProgressSheetState extends ConsumerState<ExerciseProgressSheet> {
  bool _showTotal = false;

  static const _maxPoints = 30;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(progressProvider).value;
    ExerciseProgress? ex;
    if (data != null) {
      for (final e in data.exercises) {
        if (e.exerciseId == widget.exerciseId) ex = e;
      }
    }
    if (ex == null) return const SizedBox(height: 120);

    final isTime = ex.kind == ExerciseKind.time;
    final all = ex.points;
    final shown =
        all.length > _maxPoints ? all.sublist(all.length - _maxPoints) : all;
    final chartPoints = [
      for (final p in shown)
        ChartPoint(shortDate(p.day), _showTotal ? p.total : p.best),
    ];
    final recent = all.reversed.take(5).toList();
    final unit = isTime ? ' с' : '';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ex.name, style: AppText.hand(32)),
            Text(
              'Рекорд: ${ex.format(ex.bestValue)} · '
              '${formatDayShort(parseDayKey(ex.bestDay))}',
              style: AppText.body(17),
            ),
            Text('Тренировок с упражнением: ${ex.sessions}',
                style: AppText.body(15,
                    color: AppColors.ink.withValues(alpha: 0.7))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Лучший подход', style: AppText.body(15)),
                  selected: !_showTotal,
                  selectedColor: AppColors.accent,
                  onSelected: (_) => setState(() => _showTotal = false),
                ),
                ChoiceChip(
                  label: Text('Всего за день', style: AppText.body(15)),
                  selected: _showTotal,
                  selectedColor: AppColors.accent,
                  onSelected: (_) => setState(() => _showTotal = true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ProgressChart(points: chartPoints),
            if (all.length == 1)
              Text('Пока одна тренировка — график появится после второй.',
                  style: AppText.body(14,
                      color: AppColors.ink.withValues(alpha: 0.7))),
            const SizedBox(height: 12),
            Text('Последние тренировки', style: AppText.hand(26)),
            for (final p in recent)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(formatDayShort(parseDayKey(p.day)),
                          style: AppText.body(17)),
                    ),
                    Text(
                      'лучший ${p.best}$unit · всего ${p.total}$unit · '
                      '${p.sets} подх.',
                      style: AppText.body(15),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
