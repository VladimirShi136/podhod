import 'package:flutter/material.dart';

import '../../features/calendar/calendar_logic.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

const _weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Выбор дня в стиле тетради (по-русски, без системного окна Material).
/// Возвращает выбранный день (полночь) или null, если окно закрыли.
Future<DateTime?> pickDay(BuildContext context, {DateTime? initial}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _DayPickerDialog(initial: initial ?? DateTime.now()),
  );
}

class _DayPickerDialog extends StatefulWidget {
  const _DayPickerDialog({required this.initial});

  final DateTime initial;

  @override
  State<_DayPickerDialog> createState() => _DayPickerDialogState();
}

class _DayPickerDialogState extends State<_DayPickerDialog> {
  late DateTime _month = firstOfMonth(widget.initial);

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final cells = monthCells(_month);
    final today = DateTime.now();

    return Dialog(
      backgroundColor: AppColors.paper,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Предыдущий месяц',
                  onPressed: () =>
                      setState(() => _month = addMonths(_month, -1)),
                  icon: const Icon(Icons.chevron_left, size: 30),
                  color: AppColors.ink,
                ),
                Expanded(
                  child: Text(
                    '${monthNames[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: AppText.hand(28),
                  ),
                ),
                IconButton(
                  tooltip: 'Следующий месяц',
                  onPressed: () =>
                      setState(() => _month = addMonths(_month, 1)),
                  icon: const Icon(Icons.chevron_right, size: 30),
                  color: AppColors.ink,
                ),
              ],
            ),
            Row(
              children: [
                for (final w in _weekdayLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: AppText.body(13,
                            color: AppColors.ink.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
              ],
            ),
            for (var row = 0; row < cells.length ~/ 7; row++)
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(child: _cell(cells[row * 7 + col], today)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pop(DateTime(today.year, today.month, today.day)),
                  child: Text('Сегодня', style: AppText.body(17)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Отмена', style: AppText.body(17)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(DateTime? d, DateTime today) {
    if (d == null) return const SizedBox.shrink();
    final isToday = _same(d, today);
    final isInitial = _same(d, widget.initial);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(d),
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isInitial ? AppColors.accent : null,
            border: Border.all(
              color: isToday ? AppColors.red : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: Text('${d.day}', style: AppText.hand(22)),
        ),
      ),
    );
  }
}
