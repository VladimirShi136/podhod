import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/db/database.dart';
import '../../data/db/enums.dart';

class CustomExerciseData {
  const CustomExerciseData(this.name, this.group, this.kind);

  final String name;
  final MuscleGroup group;
  final ExerciseKind kind;
}

/// Окно «своё упражнение». Если передан [edit], правится существующее:
/// тип (повторения/время) тогда менять нельзя, чтобы не сломать историю.
Future<CustomExerciseData?> showCustomExerciseDialog(
  BuildContext context, {
  Exercise? edit,
}) {
  return showDialog<CustomExerciseData>(
    context: context,
    builder: (_) => _Dialog(edit: edit),
  );
}

class _Dialog extends StatefulWidget {
  const _Dialog({this.edit});

  final Exercise? edit;

  @override
  State<_Dialog> createState() => _DialogState();
}

class _DialogState extends State<_Dialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.edit?.name ?? '');
  late MuscleGroup _group = widget.edit?.muscleGroup ?? MuscleGroup.fullBody;
  late ExerciseKind _kind = widget.edit?.kind ?? ExerciseKind.reps;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.edit != null;
    return AlertDialog(
      backgroundColor: AppColors.paper,
      title: Text(editing ? 'Изменить упражнение' : 'Своё упражнение',
          style: AppText.hand(28)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: !editing,
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
            if (!editing) ...[
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
              : () => Navigator.of(context)
                  .pop(CustomExerciseData(_name.text.trim(), _group, _kind)),
          child: Text(editing ? 'Сохранить' : 'Добавить',
              style: AppText.body(18)),
        ),
      ],
    );
  }
}
