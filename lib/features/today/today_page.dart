import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/notebook_widgets.dart';
import '../../notebook/page_header.dart';

/// Страница «Сегодня». Пока демо-данные: настоящие подключим на этапе 4.
class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _Item {
  _Item(this.name, this.reps, {this.done = false, this.record = false});

  final String name;
  final String reps;
  bool done;
  final bool record;
}

class _TodayPageState extends State<TodayPage> {
  final _items = <_Item>[
    _Item('Отжимания', '4×15', done: true),
    _Item('Приседания', '4×20'),
    _Item('Подтягивания', '3×8', record: true),
    _Item('Планка', '3×60с'),
  ];

  @override
  Widget build(BuildContext context) {
    // Если контента больше, чем места, страница прокручивается;
    // если места хватает, кнопка «прижимается» к низу.
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(title: 'Суббота, 14 ноября'),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text('Тренировка №1', style: AppText.body(15)),
                  const Sticker('🔥 серия: 1 день'),
                ],
              ),
              const SizedBox(height: 8),
              Text('Сегодня', style: AppText.hand(24)),
              for (final item in _items)
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      HandCheckbox(
                        checked: item.done,
                        onChanged: (v) => setState(() => item.done = v),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              item.name,
                              style: AppText.body(20).copyWith(
                                decoration: item.done
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: AppColors.red,
                                decorationThickness: 2,
                                color: item.done
                                    ? AppColors.ink.withValues(alpha: 0.6)
                                    : AppColors.ink,
                              ),
                            ),
                            if (item.record) const Stamp('РЕКОРД'),
                          ],
                        ),
                      ),
                      Text(item.reps, style: AppText.hand(24)),
                    ],
                  ),
                ),
              const Spacer(),
              NotebookButton(
                label: 'Начать тренировку',
                filled: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}
