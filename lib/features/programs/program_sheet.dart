import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/day_key.dart';
import '../../core/widgets/day_picker.dart';
import '../../core/widgets/input_dialogs.dart';
import '../../core/widgets/notebook_widgets.dart';
import '../../data/providers.dart';
import '../../data/repositories/program_repository.dart';
import 'exercise_chooser.dart';
import 'programs_providers.dart';

/// Открывает программу: состав, редактирование, применение к дню.
/// [onApplied] вызывается после добавления в тренировку; ему передают день.
Future<void> showProgramSheet(
  BuildContext context, {
  required int programId,
  required void Function(String day) onApplied,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: ProgramSheet(programId: programId, onApplied: onApplied),
    ),
  );
}

class ProgramSheet extends ConsumerWidget {
  const ProgramSheet({
    super.key,
    required this.programId,
    required this.onApplied,
  });

  final int programId;
  final void Function(String day) onApplied;

  ProgramDetails? _find(List<ProgramDetails>? all) {
    if (all == null) return null;
    for (final p in all) {
      if (p.program.id == programId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = _find(ref.watch(programsProvider).value);
    if (details == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox(height: 80);
    }

    final repo = ref.read(programRepositoryProvider);
    final items = details.items;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final name = await askText(
                  context,
                  title: 'Название программы',
                  initial: details.program.name,
                );
                if (name != null && name.trim().isNotEmpty) {
                  await repo.rename(programId, name);
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(details.program.name, style: AppText.hand(32)),
                  ),
                  const Icon(Icons.edit_outlined, size: 20),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12, right: 8),
                      child: Text(
                        'В программе пока нет упражнений. Добавьте первое.',
                        style: AppText.body(17),
                      ),
                    )
                  : ListView(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          _ItemRow(
                            item: items[i],
                            isFirst: i == 0,
                            isLast: i == items.length - 1,
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: NotebookButton(
                          label: '+ упражнение',
                          onPressed: () async {
                            final e = await chooseExercise(context);
                            if (e != null) {
                              await repo.addExercise(programId, e.id);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: NotebookButton(
                          label: 'Добавить в тренировку',
                          filled: true,
                          onPressed: items.isEmpty
                              ? null
                              : () => _apply(context, ref),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(context, ref),
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.red),
                    label: Text('Удалить программу',
                        style: AppText.body(16, color: AppColors.red)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.paper,
        title: Text('Когда тренируемся?', style: AppText.hand(28)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('today'),
            child: Text('Сегодня', style: AppText.body(19)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('pick'),
            child: Text('Выбрать дату…', style: AppText.body(19)),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;

    DateTime date = DateTime.now();
    if (choice == 'pick') {
      final picked = await pickDay(context, initial: date);
      if (picked == null || !context.mounted) return;
      date = picked;
    }

    final day = dayKey(date);
    try {
      await ref.read(programRepositoryProvider).applyToDay(
            programId,
            day,
            ref.read(workoutRepositoryProvider),
          );
    } catch (e) {
      // Ошибку показываем, а не глотаем: иначе кнопка «ничего не делает».
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.paper,
          title: Text('Не удалось добавить', style: AppText.hand(28)),
          content: SingleChildScrollView(
            child: Text('$e', style: AppText.body(15)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Закрыть', style: AppText.body(18)),
            ),
          ],
        ),
      );
      return;
    }
    if (context.mounted) Navigator.of(context).pop();
    onApplied(day);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('Удалить программу?', style: AppText.hand(28)),
        content: Text('Уже записанные тренировки не изменятся.',
            style: AppText.body(17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена', style: AppText.body(18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                Text('Удалить', style: AppText.body(18, color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(programRepositoryProvider).delete(programId);
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  final ProgramItem item;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(programRepositoryProvider);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _edit(context, repo),
              child: Row(
                children: [
                  Expanded(
                    child: Text(item.exercise.name, style: AppText.body(19)),
                  ),
                  const SizedBox(width: 6),
                  Text(item.summary, style: AppText.hand(26)),
                ],
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Arrow(
                icon: Icons.keyboard_arrow_up,
                enabled: !isFirst,
                onTap: () => repo.moveItem(item.entry.id, -1),
              ),
              _Arrow(
                icon: Icons.keyboard_arrow_down,
                enabled: !isLast,
                onTap: () => repo.moveItem(item.entry.id, 1),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Убрать',
            onPressed: () => repo.removeItem(item.entry.id),
            icon: const Icon(Icons.close),
            color: AppColors.red,
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, ProgramRepository repo) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _ItemEditDialog(
        name: item.exercise.name,
        values: item.values,
        isTime: item.isTime,
      ),
    );
    if (result == null) return;
    await repo.updateItem(item.entry.id, values: result, isTime: item.isTime);
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Icon(
        icon,
        size: 28,
        color: AppColors.ink.withValues(alpha: enabled ? 1 : 0.2),
      ),
    );
  }
}

class _ItemEditDialog extends StatefulWidget {
  const _ItemEditDialog({
    required this.name,
    required this.values,
    required this.isTime,
  });

  final String name;
  final List<int> values;
  final bool isTime;

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
  late final List<int> _values = [...widget.values];

  int get _step => widget.isTime ? 5 : 1;

  void _change(int i, int delta) {
    setState(() {
      final next = _values[i] + delta;
      _values[i] = next < 1 ? 1 : next;
    });
  }

  Future<void> _typeValue(int i) async {
    final v = await askNumber(
      context,
      title: widget.isTime ? 'Секунды' : 'Повторения',
      initial: _values[i],
      suffix: widget.isTime ? 'с' : null,
    );
    if (v != null && v > 0) setState(() => _values[i] = v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.paper,
      title: Text(widget.name, style: AppText.hand(28)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _values.length; i++)
                Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text('${i + 1}', style: AppText.body(18)),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _change(i, -_step),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppColors.ink,
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _typeValue(i),
                      child: SizedBox(
                        width: 64,
                        child: Text(
                          widget.isTime ? '${_values[i]} с' : '${_values[i]}',
                          textAlign: TextAlign.center,
                          style: AppText.hand(30),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _change(i, _step),
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppColors.ink,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Убрать подход',
                      onPressed: _values.length > 1
                          ? () => setState(() => _values.removeAt(i))
                          : null,
                      icon: const Icon(Icons.close),
                      color: AppColors.red,
                    ),
                  ],
                ),
              TextButton(
                onPressed: () => setState(() => _values.add(_values.last)),
                child: Text('+ подход', style: AppText.body(18)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Отмена', style: AppText.body(18)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_values),
          child: Text('Готово', style: AppText.body(18)),
        ),
      ],
    );
  }
}
