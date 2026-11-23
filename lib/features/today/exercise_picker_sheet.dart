import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/db/database.dart';
import '../../data/db/enums.dart';
import '../../data/providers.dart';
import 'today_providers.dart';

/// Открывает выбор упражнения для добавления в тренировку дня [day].
Future<int?> showExercisePicker(BuildContext context, {required String day}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: ExercisePickerSheet(day: day),
    ),
  );
}

class ExercisePickerSheet extends ConsumerStatefulWidget {
  const ExercisePickerSheet({super.key, required this.day});

  final String day;

  @override
  ConsumerState<ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<ExercisePickerSheet> {
  MuscleGroup? _group;
  String _query = '';

  Future<void> _add(int exerciseId) async {
    final workouts = ref.read(workoutRepositoryProvider);
    final workoutId = await workouts.ensureWorkout(widget.day);
    await workouts.addExercise(workoutId: workoutId, exerciseId: exerciseId);
    if (mounted) Navigator.of(context).pop(exerciseId);
  }

  Future<void> _addCustom() async {
    final result = await showDialog<_CustomExercise>(
      context: context,
      builder: (_) => const _CustomExerciseDialog(),
    );
    if (result == null) return;
    final id = await ref
        .read(exerciseRepositoryProvider)
        .addCustom(name: result.name, group: result.group, kind: result.kind);
    await _add(id);
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(
      exerciseCatalogProvider((group: _group, query: _query)),
    );

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
          Text('Добавить упражнение', style: AppText.hand(30)),
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
          Expanded(
            child: list.when(
              data: (items) => ListView.builder(
                itemCount: items.length + 1,
                itemBuilder: (_, i) {
                  if (i == items.length) {
                    return ListTile(
                      leading: const Icon(Icons.add, color: AppColors.ink),
                      title: Text('Своё упражнение…', style: AppText.body(18)),
                      onTap: _addCustom,
                    );
                  }
                  final Exercise e = items[i];
                  return ListTile(
                    title: Text(e.name, style: AppText.body(19)),
                    subtitle: Text(
                      '${e.muscleGroup.label} · ${e.kind.label}',
                      style: AppText.body(
                        14,
                        color: AppColors.ink.withValues(alpha: 0.65),
                      ),
                    ),
                    onTap: () => _add(e.id),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
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

class _CustomExercise {
  const _CustomExercise(this.name, this.group, this.kind);
  final String name;
  final MuscleGroup group;
  final ExerciseKind kind;
}

class _CustomExerciseDialog extends StatefulWidget {
  const _CustomExerciseDialog();

  @override
  State<_CustomExerciseDialog> createState() => _CustomExerciseDialogState();
}

class _CustomExerciseDialogState extends State<_CustomExerciseDialog> {
  final _name = TextEditingController();
  MuscleGroup _group = MuscleGroup.fullBody;
  ExerciseKind _kind = ExerciseKind.reps;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.paper,
      title: Text('Своё упражнение', style: AppText.hand(28)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              style: AppText.body(19),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Название'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final g in MuscleGroup.values)
                  ChoiceChip(
                    label: Text(g.label, style: AppText.body(14)),
                    selected: _group == g,
                    selectedColor: AppColors.accent,
                    onSelected: (_) => setState(() => _group = g),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final k in ExerciseKind.values)
                  ChoiceChip(
                    label: Text(k.label, style: AppText.body(14)),
                    selected: _kind == k,
                    selectedColor: AppColors.accent,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Отмена', style: AppText.body(18)),
        ),
        TextButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () =>
                    Navigator.of(context)
                        .pop(_CustomExercise(_name.text.trim(), _group, _kind)),
          child: Text('Добавить', style: AppText.body(18)),
        ),
      ],
    );
  }
}
