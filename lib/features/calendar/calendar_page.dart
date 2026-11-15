import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/day_key.dart';
import '../../core/utils/plural.dart';
import '../../notebook/notebook_scope.dart';
import '../../notebook/page_header.dart';
import '../today/today_providers.dart';
import 'calendar_logic.dart';
import 'calendar_providers.dart';

const _weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Календарь — «оглавление тетради»: дни с тренировками отмечены,
/// нажатие на день открывает его на странице «Сегодня».
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(calendarMonthProvider);
    final workoutDays =
        ref.watch(monthWorkoutDaysProvider(month)).value ?? const <String>{};
    final activeDays = ref.watch(activeDaysProvider).value ?? const <String>[];
    final done = activeDays.toSet();
    final selected = ref.watch(selectedDayProvider);
    final todayKey = dayKey(DateTime.now());
    final cells = monthCells(month);
    final count = activeInMonth(activeDays, month);
    final streak = ref.watch(streakProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'Календарь', subtitle: 'Оглавление тетради'),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                _NavButton(
                  icon: Icons.chevron_left,
                  tooltip: 'Предыдущий месяц',
                  onTap: () => ref.read(calendarMonthProvider.notifier).shift(-1),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ref.read(calendarMonthProvider.notifier).reset(),
                    child: Text(
                      '${monthNames[month.month - 1]} ${month.year}',
                      textAlign: TextAlign.center,
                      style: AppText.hand(32),
                    ),
                  ),
                ),
                _NavButton(
                  icon: Icons.chevron_right,
                  tooltip: 'Следующий месяц',
                  onTap: () => ref.read(calendarMonthProvider.notifier).shift(1),
                ),
              ],
            ),
          ),
          Row(
            children: [
              for (final w in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: AppText.body(14,
                          color: AppColors.ink.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
            ],
          ),
          for (var row = 0; row < cells.length ~/ 7; row++)
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: _DayCell(
                        date: cells[row * 7 + col],
                        hasWorkout: cells[row * 7 + col] != null &&
                            workoutDays
                                .contains(dayKey(cells[row * 7 + col]!)),
                        isDone: cells[row * 7 + col] != null &&
                            done.contains(dayKey(cells[row * 7 + col]!)),
                        isToday: cells[row * 7 + col] != null &&
                            dayKey(cells[row * 7 + col]!) == todayKey,
                        isSelected: cells[row * 7 + col] != null &&
                            dayKey(cells[row * 7 + col]!) == selected,
                        onTap: (d) {
                          ref
                              .read(selectedDayProvider.notifier)
                              .select(dayKey(d));
                          NotebookScope.of(context).goTo(0);
                        },
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            count == 0
                ? 'В этом месяце тренировок пока нет'
                : 'В месяце: $count ${plural(count, 'тренировка', 'тренировки', 'тренировок')}',
            style: AppText.body(18),
          ),
          if (streak > 0)
            Text(
              'Серия: $streak ${plural(streak, 'день', 'дня', 'дней')} подряд',
              style: AppText.body(16),
            ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _Legend(color: AppColors.accent, text: 'выполнено'),
              _Legend(color: null, text: 'запланировано'),
              _Legend(color: AppColors.red, text: 'сегодня', ring: true),
              _Legend(color: AppColors.red, text: 'открыт на «Сегодня»', underline: true),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 30),
      color: AppColors.ink,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.hasWorkout,
    required this.isDone,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime? date;
  final bool hasWorkout;
  final bool isDone;
  final bool isToday;
  final bool isSelected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final d = date;
    if (d == null) return const SizedBox.shrink();

    final Color? fill = isDone ? AppColors.accent : null;
    final Color borderColor = isToday
        ? AppColors.red
        : hasWorkout
            ? AppColors.ink
            : Colors.transparent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(d),
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(
              color: borderColor,
              width: isToday ? 2.5 : 1.6,
            ),
          ),
          child: Text(
            '${d.day}',
            style: AppText.hand(
              isSelected ? 28 : 24,
            ).copyWith(
              decoration: isSelected ? TextDecoration.underline : null,
              decorationColor: AppColors.red,
              decorationThickness: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.text,
    this.ring = false,
    this.underline = false,
  });

  final Color? color;
  final String text;
  final bool ring;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (underline)
          Text(
            '12',
            style: AppText.hand(18).copyWith(
              decoration: TextDecoration.underline,
              decorationColor: AppColors.red,
              decorationThickness: 2,
            ),
          )
        else
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ring ? null : color,
            border: Border.all(
              color: ring ? color! : AppColors.ink,
              width: ring ? 2.5 : 1.4,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: AppText.body(14)),
      ],
    );
  }
}
