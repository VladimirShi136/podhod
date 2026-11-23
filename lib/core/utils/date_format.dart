const _weekdays = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];

const _monthsGenitive = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// «Воскресенье,
/// 15 ноября»
String formatDayTitle(DateTime date) =>
    '${_weekdays[date.weekday - 1]},\n'
    '${date.day} ${_monthsGenitive[date.month - 1]}';

/// «15 ноября»
String formatDayShort(DateTime date) =>
    '${date.day} ${_monthsGenitive[date.month - 1]}';

/// «09:05»
String formatTime(DateTime time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
