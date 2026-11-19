/// Одно запланированное напоминание.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
}

const _bodies = [
  'Пора размяться: сегодня по плану тренировка.',
  'Тетрадь ждёт. Один подход уже лучше, чем ни одного.',
  'Время тренировки. Запишем новый результат?',
  'Сделайте сегодняшний подход, и серия продолжится.',
];

/// Расписание напоминаний на ближайшие [horizonDays] дней.
///
/// Напоминания ставятся заранее по одному (а не «каждую неделю»), поэтому
/// корректно переживают смену часового пояса и перевод часов. Расписание
/// обновляется при каждом запуске приложения и при смене настроек.
/// Если сегодня уже есть выполненные подходы ([trainedToday]),
/// сегодняшнее напоминание пропускается.
List<PlannedReminder> planReminders({
  required DateTime now,
  required int minutes,
  required Set<int> weekdays,
  required bool trainedToday,
  int horizonDays = 14,
}) {
  final result = <PlannedReminder>[];
  for (var i = 0; i < horizonDays; i++) {
    final date = DateTime(now.year, now.month, now.day + i);
    if (!weekdays.contains(date.weekday)) continue;
    final at = DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);
    if (!at.isAfter(now)) continue;
    if (i == 0 && trainedToday) continue;
    result.add(
      PlannedReminder(
        id: i,
        at: at,
        title: 'Подход',
        body: _bodies[i % _bodies.length],
      ),
    );
  }
  return result;
}
