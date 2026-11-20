import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/db/database.dart';
import '../../data/db/enums.dart';
import '../today/today_providers.dart';

/// Выбор упражнения из каталога. Возвращает выбранное или null.
Future<Exercise?> chooseExercise(BuildContext context) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.9,
      child: _Chooser(),
    ),
  );
}

class _Chooser extends ConsumerStatefulWidget {
  const _Chooser();

  @override
  ConsumerState<_Chooser> createState() => _ChooserState();
}

class _ChooserState extends ConsumerState<_Chooser> {
  MuscleGroup? _group;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final list =
        ref.watch(exerciseCatalogProvider((group: _group, query: _query)));

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
          Text('Выбрать упражнение', style: AppText.hand(30)),
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
                _chip('Все', _group == null, () => setState(() => _group = null)),
                for (final g in MuscleGroup.values)
                  _chip(g.label, _group == g, () => setState(() => _group = g)),
              ],
            ),
          ),
          Expanded(
            child: list.when(
              data: (items) => ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(items[i].name, style: AppText.body(19)),
                  subtitle: Text(
                    '${items[i].muscleGroup.label} · ${items[i].kind.label}',
                    style: AppText.body(14,
                        color: AppColors.ink.withValues(alpha: 0.65)),
                  ),
                  onTap: () => Navigator.of(context).pop(items[i]),
                ),
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
