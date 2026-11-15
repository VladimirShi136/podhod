import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/core/utils/date_format.dart';
import 'package:podhod/core/utils/plural.dart';
import 'package:podhod/core/utils/streak.dart';

void main() {
  test('plural', () {
    expect(plural(1, 'день', 'дня', 'дней'), 'день');
    expect(plural(2, 'день', 'дня', 'дней'), 'дня');
    expect(plural(5, 'день', 'дня', 'дней'), 'дней');
    expect(plural(11, 'день', 'дня', 'дней'), 'дней');
    expect(plural(21, 'день', 'дня', 'дней'), 'день');
    expect(plural(112, 'день', 'дня', 'дней'), 'дней');
  });

  test('streak', () {
    final today = DateTime(2026, 11, 15);
    expect(currentStreak([], today), 0);
    expect(currentStreak(['2026-11-15', '2026-11-14', '2026-11-13'], today), 3);
    // сегодня ещё не занимались, серия идёт от вчера
    expect(currentStreak(['2026-11-14', '2026-11-13'], today), 2);
    expect(currentStreak(['2026-11-13'], today), 0);
    // граница месяца
    expect(currentStreak(['2026-11-01', '2026-10-31'], DateTime(2026, 11, 1)), 2);
  });

  test('workoutNumber', () {
    expect(workoutNumber([], '2026-11-15'), 1);
    expect(workoutNumber(['2026-11-14', '2026-11-10'], '2026-11-15'), 3);
    expect(workoutNumber(['2026-11-15', '2026-11-14'], '2026-11-15'), 2);
  });

  test('formatDayTitle', () {
    expect(formatDayTitle(DateTime(2026, 11, 15)), 'Воскресенье, 15 ноября');
    expect(formatTime(DateTime(2026, 1, 1, 9, 5)), '09:05');
  });
}
