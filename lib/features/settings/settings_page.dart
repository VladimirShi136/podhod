import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/notebook_widgets.dart';
import '../../core/widgets/paper_lines.dart';
import '../../core/widgets/time_picker.dart';
import '../../notebook/page_header.dart';
import '../today/rest_timer.dart';
import 'app_settings.dart';
import 'notification_service.dart';
import 'settings_providers.dart';

const _weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Настройки: отдых между подходами, напоминания, экспорт и стирание данных.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _exporting = false;

  Future<void> _message(String title, String text) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text(title, style: AppText.hand(28)),
        content: Text(text, style: AppText.body(17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Понятно', style: AppText.body(18)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReminders(bool enable) async {
    final notifier = ref.read(settingsProvider.notifier);
    if (!enable) {
      notifier.setRemindersEnabled(false);
      return;
    }
    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermission();
    if (!mounted) return;
    if (granted) {
      notifier.setRemindersEnabled(true);
    } else {
      await _message(
        'Нет разрешения',
        'Чтобы получать напоминания, разрешите уведомления для приложения '
            'в настройках телефона.',
      );
    }
  }

  Future<void> _export(ExportFormat format) async {
    setState(() => _exporting = true);
    try {
      await exportAndShare(ref, format);
    } catch (e) {
      if (mounted) await _message('Не удалось выгрузить', '$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _erase() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('Стереть все данные?', style: AppText.hand(28)),
        content: Text(
          'Будут удалены все тренировки, программы и ваши упражнения. '
          'Это нельзя отменить. Перед этим можно сделать резервную копию '
          'через экспорт.',
          style: AppText.body(17),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена', style: AppText.body(18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Стереть',
              style: AppText.body(18, color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await ref.read(exportRepositoryProvider).eraseAll();
    if (mounted) await _message('Готово', 'Все данные стёрты.');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Настройки',
            subtitle: 'Напоминания, экспорт, данные',
            showGear: false,
            showBack: true,
          ),
          LineText('Отдых между подходами', style: AppText.hand(26)),
          LineSnap(
            minLines: 2,
            child: Wrap(
              spacing: 8,
              children: [
                for (final p in restPresets)
                  ChoiceChip(
                    label: Text(
                      p >= 60 && p % 60 == 0 ? '${p ~/ 60} мин' : '$p с',
                      style: AppText.body(16),
                    ),
                    selected: settings.restSeconds == p,
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.paper,
                    onSelected: (_) => notifier.setRestSeconds(p),
                  ),
              ],
            ),
          ),
          LineText('Напоминания', style: AppText.hand(26)),
          SizedBox(
            height: 2 * kLine,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Напоминать о тренировке', style: AppText.body(19)),
              value: settings.remindersEnabled,
              activeThumbColor: AppColors.ink,
              onChanged: _toggleReminders,
            ),
          ),
          if (settings.remindersEnabled) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final minutes = await pickTimeOfDay(
                  context,
                  initial: settings.reminderMinutes,
                );
                if (minutes != null) notifier.setReminderMinutes(minutes);
              },
              child: SizedBox(
                height: 2 * kLine,
                child: Row(
                  children: [
                    Expanded(child: Text('Время', style: AppText.body(19))),
                    Text(settings.reminderTimeText, style: AppText.hand(32)),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            LineText('По дням', style: AppText.body(15)),
            LineSnap(
              minLines: 2,
              child: Wrap(
                spacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    ChoiceChip(
                      label: Text(
                        _weekdayLabels[d - 1],
                        style: AppText.body(16),
                      ),
                      selected: settings.reminderWeekdays.contains(d),
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.paper,
                      onSelected: (_) => notifier.toggleWeekday(d),
                    ),
                ],
              ),
            ),
            LineText(
              'Если в этот день вы уже сделали подход, напоминание не придёт. '
              'Расписание обновляется при каждом открытии приложения.',
              style: AppText.body(
                13,
                color: AppColors.ink.withValues(alpha: 0.65),
              ),
            ),
          ],
          LineText('Данные', style: AppText.hand(26)),
          NotebookButton(
            label: 'Резервная копия (JSON)',
            onPressed: _exporting ? null : () => _export(ExportFormat.json),
          ),
          const SizedBox(height: 8),
          NotebookButton(
            label: 'Таблица для Excel (CSV)',
            onPressed: _exporting ? null : () => _export(ExportFormat.csv),
          ),
          TextButton.icon(
            onPressed: _erase,
            icon: const Icon(Icons.delete_outline, color: AppColors.red),
            label: Text(
              'Стереть все данные',
              style: AppText.body(16, color: AppColors.red),
            ),
          ),
          LineText(
            'Подход · версия 1.0.0\nВсе данные хранятся только на этом телефоне.',
            style: AppText.body(
              13,
              color: AppColors.ink.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: kLine),
        ],
      ),
    );
  }
}
