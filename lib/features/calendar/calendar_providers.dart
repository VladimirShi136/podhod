import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'calendar_logic.dart';

/// Какой месяц открыт в календаре (первое число).
class CalendarMonth extends Notifier<DateTime> {
  @override
  DateTime build() => firstOfMonth(DateTime.now());

  void shift(int delta) => state = addMonths(state, delta);

  void reset() => state = firstOfMonth(DateTime.now());
}

final calendarMonthProvider =
    NotifierProvider<CalendarMonth, DateTime>(CalendarMonth.new);

/// Дни месяца, в которых есть хотя бы одно упражнение.
final monthWorkoutDaysProvider = StreamProvider.autoDispose
    .family<Set<String>, DateTime>((ref, month) {
  final (from, to) = monthRange(month);
  return ref.watch(workoutRepositoryProvider).watchWorkoutDays(from, to);
});
