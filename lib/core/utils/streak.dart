import 'day_key.dart';

/// Серия дней подряд с выполненными подходами.
///
/// [activeDays] — дни («ГГГГ-ММ-ДД»), в которые выполнен хотя бы один подход.
/// Если сегодня тренировки ещё не было, серия не обрывается: считаем от вчера.
int currentStreak(Iterable<String> activeDays, DateTime today) {
  final days = activeDays.toSet();
  var cursor = DateTime(today.year, today.month, today.day);
  if (!days.contains(dayKey(cursor))) cursor = _previousDay(cursor);

  var count = 0;
  while (days.contains(dayKey(cursor))) {
    count++;
    cursor = _previousDay(cursor);
  }
  return count;
}

/// Номер тренировки: сколько дней с выполненными подходами было ДО [day], плюс один.
int workoutNumber(Iterable<String> activeDays, String day) {
  return activeDays.where((d) => d.compareTo(day) < 0).length + 1;
}

DateTime _previousDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);
