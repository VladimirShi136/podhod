import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/day_key.dart';
import '../../core/utils/plural.dart';
import '../../core/widgets/input_dialogs.dart';
import '../../core/widgets/notebook_widgets.dart';
import '../../data/providers.dart';
import '../../data/repositories/models.dart';
import '../../notebook/page_header.dart';
import 'exercise_picker_sheet.dart';
import 'exercise_row.dart';
import 'exercise_sheet.dart';
import 'today_providers.dart';

const _moods = ['😫', '😕', '😐', '🙂', '💪'];

/// Страница «Сегодня»: тренировка выбранного дня из базы данных.
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(selectedDayProvider.notifier).refreshToday();
      ref.invalidate(streakProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(selectedDayProvider);
    final details = ref.watch(workoutDayProvider).value;
    final streak = ref.watch(streakProvider);
    final number = ref.watch(workoutNumberProvider);
    final repo = ref.read(workoutRepositoryProvider);
    final workout = details?.workout;
    final isToday = day == dayKey(DateTime.now());
    final date = parseDayKey(day);

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(title: formatDayTitle(date), wrapTitle: true),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text('Тренировка №$number', style: AppText.body(15)),
                  if (streak > 0)
                    Sticker(
                      '🔥 серия: $streak '
                      '${plural(streak, 'день', 'дня', 'дней')}',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isToday ? 'Сегодня' : formatDayShort(date),
                style: AppText.hand(24),
              ),
              if (details != null)
                for (final item in details.exercises)
                  ExerciseRow(
                    key: ValueKey(item.entry.id),
                    details: item,
                    day: day,
                    onOpen: () => showExerciseSheet(
                      context,
                      entryId: item.entry.id,
                      day: day,
                    ),
                  ),
              SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showExercisePicker(context, day: day),
                    child: Text(
                      '+ добавить упражнение',
                      style: AppText.body(
                        19,
                        color: AppColors.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
              if (workout != null) ...[
                _MoodRow(
                  mood: workout.mood,
                  onChanged: (m) => repo.setMood(workout.id, m),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    final text = await askText(
                      context,
                      title: 'Заметка',
                      initial: workout.note,
                      hint: 'Как прошла тренировка?',
                    );
                    if (text != null)
                      await repo.setNote(workout.id, text.trim());
                  },
                  child: SizedBox(
                    height: 56,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        workout.note.isEmpty
                            ? '✎ заметка…'
                            : '✎ ${workout.note}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(
                          17,
                          color: AppColors.ink.withValues(
                            alpha: workout.note.isEmpty ? 0.5 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (workout.startedAt != null)
                  Text(_timeInfo(workout), style: AppText.body(14)),
              ],
              const Spacer(),
              const SizedBox(height: 8),
              _mainButton(day, details),
            ],
          ),
        ),
      ],
    );
  }

  String _timeInfo(dynamic workout) {
    final start = workout.startedAt as DateTime;
    final end = workout.finishedAt as DateTime?;
    if (end == null) return 'Начало: ${formatTime(start)}';
    final minutes = end.difference(start).inMinutes;
    return 'Длительность: $minutes мин (${formatTime(start)}–${formatTime(end)})';
  }

  Widget _mainButton(String day, WorkoutDetails? details) {
    final repo = ref.read(workoutRepositoryProvider);
    final workout = details?.workout;

    if (workout == null || details!.isEmpty) {
      return NotebookButton(
        label: 'Начать тренировку',
        filled: true,
        onPressed: () => showExercisePicker(context, day: day),
      );
    }
    if (workout.finishedAt != null) {
      return NotebookButton(
        label: 'Тренировка завершена ✓ · продолжить',
        onPressed: () => repo.reopenWorkout(workout.id),
      );
    }
    if (workout.startedAt == null) {
      return NotebookButton(
        label: 'Начать тренировку',
        filled: true,
        onPressed: () => repo.startWorkout(workout.id),
      );
    }
    return NotebookButton(
      label: 'Завершить тренировку',
      filled: true,
      onPressed: () => repo.finishWorkout(workout.id),
    );
  }
}

class _MoodRow extends StatelessWidget {
  const _MoodRow({required this.mood, required this.onChanged});

  final int? mood;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Text('Самочувствие', style: AppText.body(16)),
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _moods.length; i++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(mood == i + 1 ? null : i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Opacity(
                          opacity: mood == null || mood == i + 1 ? 1 : 0.3,
                          child: Text(
                            _moods[i],
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
