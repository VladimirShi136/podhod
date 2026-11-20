import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/day_key.dart';
import '../../core/utils/plural.dart';
import '../../core/widgets/notebook_widgets.dart';
import '../../data/db/enums.dart';
import '../../data/providers.dart';
import '../programs/program_picker.dart';
import '../today/today_providers.dart';
import 'custom_exercise_dialog.dart';
import 'exercise_info_sheet.dart';

/// Каталог упражнений. После добавления в сегодняшнюю тренировку вызывает
/// [onAddedToday] (например, чтобы перелистнуть тетрадь на «Сегодня»).
Future<void> showCatalog(
  BuildContext context, {
  required VoidCallback onAddedToday,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: CatalogSheet(onAddedToday: onAddedToday),
    ),
  );
}

class CatalogSheet extends ConsumerStatefulWidget {
  const CatalogSheet({super.key, required this.onAddedToday});

  final VoidCallback onAddedToday;

  @override
  ConsumerState<CatalogSheet> createState() => _CatalogSheetState();
}

class _CatalogSheetState extends ConsumerState<CatalogSheet> {
  MuscleGroup? _group;
  String _query = '';
  final Set<int> _selected = {};

  void _toggle(int id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  Future<void> _addSelectedToday() async {
    final workouts = ref.read(workoutRepositoryProvider);
    final workoutId = await workouts.ensureWorkout(dayKey(DateTime.now()));
    for (final id in _selected) {
      await workouts.addExercise(workoutId: workoutId, exerciseId: id);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onAddedToday();
  }

  Future<void> _addSelectedToProgram() async {
    final name = await addToProgramFlow(context, ref, _selected.toList());
    if (name != null && mounted) setState(_selected.clear);
  }

  Future<void> _newCustom() async {
    final data = await showCustomExerciseDialog(context);
    if (data == null) return;
    await ref
        .read(exerciseRepositoryProvider)
        .addCustom(name: data.name, group: data.group, kind: data.kind);
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(
      exerciseCatalogProvider((group: _group, query: _query)),
    );
    final selecting = _selected.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Каталог упражнений', style: AppText.hand(30)),
          const SizedBox(height: 6),
          TextField(
            style: AppText.body(18),
            decoration: const InputDecoration(
              hintText: 'Поиск',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip(
                  'Все',
                  _group == null,
                  () => setState(() => _group = null),
                ),
                for (final g in MuscleGroup.values)
                  _chip(g.label, _group == g, () => setState(() => _group = g)),
              ],
            ),
          ),
          if (!selecting)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Нажмите для описания, удерживайте, чтобы выбрать несколько.',
                style: AppText.body(
                  13,
                  color: AppColors.ink.withValues(alpha: 0.6),
                ),
              ),
            ),
          Expanded(
            child: list.when(
              data: (items) => ListView.builder(
                itemCount: items.length + 1,
                itemBuilder: (_, i) {
                  if (i == items.length) {
                    return ListTile(
                      leading: const Icon(Icons.add, color: AppColors.ink),
                      title: Text('Своё упражнение…', style: AppText.body(18)),
                      onTap: _newCustom,
                    );
                  }
                  final e = items[i];
                  final checked = _selected.contains(e.id);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: selecting
                        ? HandCheckbox(
                            checked: checked,
                            onChanged: (_) => _toggle(e.id),
                          )
                        : null,
                    title: Text(e.name, style: AppText.body(19)),
                    subtitle: Text(
                      '${e.muscleGroup.label} · ${e.kind.label}'
                      '${e.isCustom ? ' · своё' : ''}',
                      style: AppText.body(
                        14,
                        color: AppColors.ink.withValues(alpha: 0.65),
                      ),
                    ),
                    onLongPress: () => _toggle(e.id),
                    onTap: () async {
                      if (selecting) {
                        _toggle(e.id);
                        return;
                      }
                      final added = await showExerciseInfo(context, e.id);
                      if (added == true && context.mounted) {
                        Navigator.of(context).pop();
                        widget.onAddedToday();
                      }
                    },
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
            ),
          ),
          if (selecting)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Выбрано: ${_selected.length} '
                            '${plural(_selected.length, 'упражнение', 'упражнения', 'упражнений')}',
                            style: AppText.body(16),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(_selected.clear),
                          child: Text('Сбросить', style: AppText.body(16)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: NotebookButton(
                            label: 'В программу',
                            onPressed: _addSelectedToProgram,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: NotebookButton(
                            label: 'В сегодня',
                            filled: true,
                            onPressed: _addSelectedToday,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: AppText.body(15)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.accent,
        backgroundColor: AppColors.paper,
      ),
    );
  }
}
