import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/features/calendar/calendar_logic.dart';

void main() {
  test('сетка ноября 2026: 1 ноября — воскресенье', () {
    final cells = monthCells(DateTime(2026, 11, 15));
    expect(cells.length % 7, 0);
    expect(cells.take(6).every((c) => c == null), isTrue);
    expect(cells[6], DateTime(2026, 11, 1));
    expect(cells.whereType<DateTime>().length, 30);
  });

  test('февраль 2027 начинается с понедельника и занимает 4 ряда', () {
    final cells = monthCells(DateTime(2027, 2));
    expect(cells.first, DateTime(2027, 2, 1));
    expect(cells.length, 28);
  });

  test('сдвиг месяцев через границу года', () {
    expect(addMonths(DateTime(2026, 12), 1), DateTime(2027, 1));
    expect(addMonths(DateTime(2026, 1), -1), DateTime(2025, 12));
  });

  test('monthRange и activeInMonth', () {
    expect(monthRange(DateTime(2026, 2)), ('2026-02-01', '2026-02-28'));
    expect(
      activeInMonth(['2026-11-30', '2026-11-01', '2026-10-31', '2026-12-01'],
          DateTime(2026, 11)),
      2,
    );
  });
}
