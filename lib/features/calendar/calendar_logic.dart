import '../../core/utils/day_key.dart';

const monthNames = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

/// Первое число месяца, в котором лежит [d].
DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month);

/// Сдвиг месяца на [delta] (первое число).
DateTime addMonths(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);

/// Ячейки сетки месяца с понедельника: null — пустая клетка до/после месяца.
/// Длина всегда кратна 7.
List<DateTime?> monthCells(DateTime month) {
  final first = firstOfMonth(month);
  final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
  final lead = first.weekday - 1; // понедельник = 0
  final cells = <DateTime?>[
    for (var i = 0; i < lead; i++) null,
    for (var d = 1; d <= daysInMonth; d++) DateTime(first.year, first.month, d),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}

/// Ключи первого и последнего дня месяца.
(String, String) monthRange(DateTime month) {
  final first = firstOfMonth(month);
  final last = DateTime(first.year, first.month + 1, 0);
  return (dayKey(first), dayKey(last));
}

/// Сколько дней с выполненными подходами в месяце.
int activeInMonth(Iterable<String> activeDays, DateTime month) {
  final (from, to) = monthRange(month);
  return activeDays.where((d) => d.compareTo(from) >= 0 && d.compareTo(to) <= 0).length;
}
