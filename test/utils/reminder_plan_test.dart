import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/features/settings/reminder_plan.dart';

void main() {
  // 2026-11-15 — воскресенье
  final sunday = DateTime(2026, 11, 15, 10, 0);

  test('только выбранные дни недели, на горизонте 14 дней', () {
    final plan = planReminders(
      now: sunday,
      minutes: 18 * 60 + 30,
      weekdays: {1, 3, 5}, // пн, ср, пт
      trainedToday: false,
    );
    expect(plan.map((r) => r.at.weekday).toSet(), {1, 3, 5});
    expect(plan.first.at, DateTime(2026, 11, 16, 18, 30));
    expect(plan.length, 6); // две недели: 3 + 3
    expect(plan.every((r) => r.at.isAfter(sunday)), isTrue);
    expect(plan.map((r) => r.id).toSet().length, plan.length); // id уникальны
  });

  test('сегодня: уже прошло время или уже тренировались — пропускаем', () {
    final late = DateTime(2026, 11, 15, 19, 0);
    final passed = planReminders(
      now: late,
      minutes: 18 * 60,
      weekdays: {7},
      trainedToday: false,
    );
    expect(passed.first.at, DateTime(2026, 11, 22, 18, 0));

    final trained = planReminders(
      now: sunday,
      minutes: 18 * 60,
      weekdays: {7},
      trainedToday: true,
    );
    expect(trained.first.at, DateTime(2026, 11, 22, 18, 0));

    final notTrained = planReminders(
      now: sunday,
      minutes: 18 * 60,
      weekdays: {7},
      trainedToday: false,
    );
    expect(notTrained.first.at, DateTime(2026, 11, 15, 18, 0));
  });

  test('нет дней — нет напоминаний', () {
    expect(
      planReminders(now: sunday, minutes: 600, weekdays: {}, trainedToday: false),
      isEmpty,
    );
  });
}
