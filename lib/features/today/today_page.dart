import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/day_key.dart';
import '../../core/utils/plural.dart';
import '../../core/widgets/input_dialogs.dart';
import '../../core/widgets/notebook_widgets.dart';
import '../../core/widgets/paper_lines.dart';
import '../../data/providers.dart';
import '../../data/repositories/models.dart';
import '../../notebook/page_header.dart';
import 'exercise_picker_sheet.dart';
import 'exercise_row.dart';
import 'exercise_sheet.dart';
import 'rest_timer.dart';
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
  bool _exercisePickerOpen = false;
  Set<int> _exerciseIdsWhenPickerOpened = {};

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
    final todayKey = dayKey(DateTime.now());
    final isToday = day == todayKey;
    final isFuture = day.compareTo(todayKey) > 0;
    final date = parseDayKey(day);

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: kLine)),
        SliverToBoxAdapter(
          child: PageHeader(title: formatDayTitle(date), wrapTitle: true),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: kLine,
            child: Row(
              children: [
                Expanded(
                  child: LineText(
                    'Тренировка №$number',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(15),
                  ),
                ),
                if (isToday && streak > 0) ...[
                  const SizedBox(width: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Sticker(
                          '🔥 серия: $streak '
                          '${plural(streak, 'день', 'дня', 'дней')}',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: isToday
              ? LineText('Сегодня', style: AppText.hand(24))
              : const SizedBox(height: kLine),
        ),
        if (isToday) const SliverToBoxAdapter(child: SizedBox(height: kLine)),
        if (details != null)
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = details.exercises[index];
              final shouldAnimate =
                  !_exercisePickerOpen ||
                  _exerciseIdsWhenPickerOpened.contains(item.entry.id);
              return TweenAnimationBuilder<double>(
                key: ValueKey('${item.entry.id}-$shouldAnimate'),
                tween: Tween(begin: shouldAnimate ? 0.0 : 1.0, end: 1.0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (context, progress, child) => ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: progress,
                    child: Opacity(opacity: progress, child: child),
                  ),
                ),
                child: ExerciseRow(
                  details: item,
                  day: day,
                  onOpen: () => showExerciseSheet(
                    context,
                    entryId: item.entry.id,
                    day: day,
                  ),
                ),
              );
            }, childCount: details.exercises.length),
          ),
        if (details?.exercises.isNotEmpty == true)
          const SliverToBoxAdapter(child: SizedBox(height: kLine)),
        SliverToBoxAdapter(
          child: SizedBox(
            height: kLine,
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _pickExercises(day),
                child: LineText(
                  '+ добавить упражнение',
                  style: AppText.body(
                    19,
                    color: AppColors.ink.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: kLine)),
        if (workout != null && !isFuture)
          SliverToBoxAdapter(
            child: Column(
              children: [
                _MoodRow(
                  mood: workout.mood,
                  onChanged: (m) => repo.setMood(workout.id, m),
                ),
                const SizedBox(height: kLine),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    final text = await askText(
                      context,
                      title: 'Заметка',
                      initial: workout.note,
                      hint: 'Как прошла тренировка?',
                    );
                    if (text != null) {
                      await repo.setNote(workout.id, text.trim());
                    }
                  },
                  child: SizedBox(
                    height: kLine,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: LineText(
                        workout.note.isEmpty
                            ? '✎ заметка…'
                            : '✎ ${workout.note}',
                        maxLines: 1,
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
                const SizedBox(height: kLine),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: _fadeSizeTransition,
                  child: isToday && workout.startedAt != null
                      ? LineText(
                          _timeInfo(workout),
                          key: ValueKey(
                            workout.finishedAt == null ? 'started' : 'finished',
                          ),
                          style: AppText.body(14),
                        )
                      : const SizedBox.shrink(key: ValueKey('not-started')),
                ),
              ],
            ),
          ),
        if (isToday)
          const SliverToBoxAdapter(child: RestTimerBar(snapToLines: true)),
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: _fadeSizeTransition,
            child:
                _mainButton(day, details, isToday, isFuture) ??
                const SizedBox.shrink(key: ValueKey('no-main-button')),
          ),
        ),
        if (!isToday)
          SliverToBoxAdapter(
            child: NotebookButton(
              label: 'Вернуться к сегодняшнему дню',
              filled: details != null && !details.isEmpty,
              onPressed: () =>
                  ref.read(selectedDayProvider.notifier).select(todayKey),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: kLine)),
      ],
    );
  }

  Future<void> _pickExercises(String day) async {
    _exerciseIdsWhenPickerOpened =
        ref
            .read(workoutDayProvider)
            .value
            ?.exercises
            .map((exercise) => exercise.entry.id)
            .toSet() ??
        {};
    setState(() => _exercisePickerOpen = true);
    try {
      await showExercisePicker(context, day: day);
    } finally {
      if (mounted) setState(() => _exercisePickerOpen = false);
    }
  }

  String _timeInfo(dynamic workout) {
    final start = workout.startedAt as DateTime;
    final end = workout.finishedAt as DateTime?;
    if (end == null) return 'Начало: ${formatTime(start)}';
    final minutes = end.difference(start).inMinutes;
    return 'Длительность: $minutes мин (${formatTime(start)}–${formatTime(end)})';
  }

  /// Главная кнопка внизу страницы. Для прошлых и будущих дней таймера
  /// «начать/завершить» нет: там можно только записать или спланировать
  /// упражнения, поэтому при уже внесённых упражнениях кнопки нет (null).
  Widget? _mainButton(
    String day,
    WorkoutDetails? details,
    bool isToday,
    bool isFuture,
  ) {
    final repo = ref.read(workoutRepositoryProvider);
    final workout = details?.workout;

    if (!isToday) {
      if (workout != null && !details!.isEmpty) return null;
      return NotebookButton(
        label: isFuture ? 'Запланировать тренировку' : 'Записать тренировку',
        filled: true,
        onPressed: () => _pickExercises(day),
      );
    }

    if (workout == null || details!.isEmpty) {
      return NotebookButton(
        key: const ValueKey('pick-exercises'),
        label: 'Начать тренировку',
        filled: true,
        onPressed: () => _pickExercises(day),
      );
    }
    if (workout.finishedAt != null) {
      // Кнопки нет: если дописать упражнение или подход, тренировка
      // сама станет снова «идущей».
      return SizedBox(
        key: const ValueKey('workout-finished'),
        height: 2 * kLine,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Тренировка завершена',
                    style: AppText.hand(30, color: AppColors.red),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.check_rounded,
                    color: AppColors.red,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (workout.startedAt == null) {
      return NotebookButton(
        key: const ValueKey('workout-not-started'),
        label: 'Начать тренировку',
        filled: true,
        onPressed: () => repo.startWorkout(workout.id),
      );
    }
    return Column(
      key: const ValueKey('workout-started'),
      mainAxisSize: MainAxisSize.min,
      children: [
        NotebookButton(
          label: 'Завершить тренировку',
          filled: true,
          onPressed: () async {
            final incompleteSets = details.exercises.fold<int>(
              0,
              (count, exercise) =>
                  count + exercise.sets.where((set) => !set.done).length,
            );
            if (incompleteSets > 0) {
              final confirmed = await _confirmFinishIncomplete(
                context,
                incompleteSets,
              );
              if (confirmed != true || !context.mounted) return;
            }
            await repo.finishWorkout(workout.id);
          },
        ),
        SizedBox(
          height: kLine,
          child: TextButton(
            onPressed: () => repo.cancelWorkoutStart(workout.id),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, kLine),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: LineText('Отменить начало', style: AppText.body(16)),
          ),
        ),
      ],
    );
  }

  Future<bool?> _confirmFinishIncomplete(
    BuildContext context,
    int incompleteSets,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('Есть невыполненные подходы', style: AppText.hand(28)),
        content: Text(
          'Осталось $incompleteSets '
          '${plural(incompleteSets, 'подход', 'подхода', 'подходов')}. '
          'Завершить тренировку всё равно?',
          style: AppText.body(17),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Продолжить', style: AppText.body(18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Завершить',
              style: AppText.body(18, color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _fadeSizeTransition(Widget child, Animation<double> animation) {
  return SizeTransition(
    sizeFactor: animation,
    alignment: Alignment.topCenter,
    child: FadeTransition(opacity: animation, child: child),
  );
}

class _MoodRow extends StatelessWidget {
  const _MoodRow({required this.mood, required this.onChanged});

  final int? mood;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kLine,
      child: Row(
        children: [
          LineText('Самочувствие', style: AppText.body(16)),
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
                            style: const TextStyle(fontSize: 22),
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
