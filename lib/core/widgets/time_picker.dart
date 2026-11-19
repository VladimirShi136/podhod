import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Выбор времени суток в стиле тетради. Возвращает минуты от полуночи
/// или null, если окно закрыли.
Future<int?> pickTimeOfDay(BuildContext context, {required int initial}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _TimeDialog(initial: initial),
  );
}

class _TimeDialog extends StatefulWidget {
  const _TimeDialog({required this.initial});

  final int initial;

  @override
  State<_TimeDialog> createState() => _TimeDialogState();
}

class _TimeDialogState extends State<_TimeDialog> {
  late int _hour = widget.initial ~/ 60;
  late int _minute = (widget.initial % 60 ~/ 5) * 5;

  Widget _column(
    String label,
    int value,
    VoidCallback onUp,
    VoidCallback onDown,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '$label: больше',
          onPressed: onUp,
          icon: const Icon(Icons.keyboard_arrow_up, size: 36),
          color: AppColors.ink,
        ),
        Text(value.toString().padLeft(2, '0'), style: AppText.hand(56)),
        IconButton(
          tooltip: '$label: меньше',
          onPressed: onDown,
          icon: const Icon(Icons.keyboard_arrow_down, size: 36),
          color: AppColors.ink,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.paper,
      title: Text('Время напоминания', style: AppText.hand(28)),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _column(
            'Часы',
            _hour,
            () => setState(() => _hour = (_hour + 1) % 24),
            () => setState(() => _hour = (_hour + 23) % 24),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(':', style: AppText.hand(56)),
          ),
          _column(
            'Минуты',
            _minute,
            () => setState(() => _minute = (_minute + 5) % 60),
            () => setState(() => _minute = (_minute + 55) % 60),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Отмена', style: AppText.body(18)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_hour * 60 + _minute),
          child: Text('Готово', style: AppText.body(18)),
        ),
      ],
    );
  }
}
