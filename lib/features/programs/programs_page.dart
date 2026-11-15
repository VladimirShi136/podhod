import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/day_key.dart';
import '../../core/utils/plural.dart';
import '../../core/widgets/input_dialogs.dart';
import '../../core/widgets/notebook_widgets.dart';
import '../../data/providers.dart';
import '../../data/repositories/program_repository.dart';
import '../../notebook/notebook_scope.dart';
import '../../notebook/page_header.dart';
import '../today/today_providers.dart';
import 'program_sheet.dart';
import 'programs_providers.dart';

/// Программы: сохранённые комплексы упражнений, которые добавляются
/// в тренировку одним нажатием.
class ProgramsPage extends ConsumerWidget {
  const ProgramsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs = ref.watch(programsProvider).value;

    void open(int id) {
      // Навигацию по тетради берём здесь: у окна поверх страницы своего
      // NotebookScope нет.
      final scope = NotebookScope.of(context);
      showProgramSheet(
        context,
        programId: id,
        onApplied: (day) {
          ref.read(selectedDayProvider.notifier).select(day);
          scope.goTo(0);
        },
      );
    }

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Программы',
                subtitle: 'Сохранённые комплексы',
              ),
              if (programs == null)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (programs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Программа — это заготовка тренировки, например '
                    '«Понедельник: грудь». Создайте её или сохраните '
                    'сегодняшнюю тренировку, а потом добавляйте в любой день '
                    'одним нажатием.',
                    style: AppText.body(18),
                  ),
                )
              else
                for (final p in programs)
                  _ProgramRow(details: p, onTap: () => open(p.program.id)),
              const Spacer(),
              const SizedBox(height: 12),
              NotebookButton(
                label: '+ Новая программа',
                filled: true,
                onPressed: () async {
                  final name = await askText(
                    context,
                    title: 'Название программы',
                    hint: 'Например, «Понедельник: грудь»',
                  );
                  if (name == null || name.trim().isEmpty) return;
                  final id =
                      await ref.read(programRepositoryProvider).create(name);
                  if (context.mounted) open(id);
                },
              ),
              const SizedBox(height: 10),
              NotebookButton(
                label: 'Из сегодняшней тренировки',
                onPressed: () => _fromToday(context, ref, open),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _fromToday(
    BuildContext context,
    WidgetRef ref,
    void Function(int id) open,
  ) async {
    final today = await ref
        .read(workoutRepositoryProvider)
        .getDay(dayKey(DateTime.now()));
    if (!context.mounted) return;

    if (today == null || today.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.paper,
          title: Text('Пока нечего сохранять', style: AppText.hand(28)),
          content: Text(
            'В сегодняшней тренировке нет упражнений. Добавьте их на '
            'странице «Сегодня» и вернитесь сюда.',
            style: AppText.body(17),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Понятно', style: AppText.body(18)),
            ),
          ],
        ),
      );
      return;
    }

    final name = await askText(
      context,
      title: 'Название программы',
      hint: 'Например, «Фулбоди»',
    );
    if (name == null || name.trim().isEmpty) return;
    final id =
        await ref.read(programRepositoryProvider).createFromWorkout(name, today);
    if (context.mounted) open(id);
  }
}

class _ProgramRow extends StatelessWidget {
  const _ProgramRow({required this.details, required this.onTap});

  final ProgramDetails details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = details.items.length;
    final names = details.items.map((e) => e.exercise.name).join(', ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(details.program.name, style: AppText.body(20)),
                    Text(
                      n == 0
                          ? 'пока пусто'
                          : '$n ${plural(n, 'упражнение', 'упражнения', 'упражнений')}: $names',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(14,
                          color: AppColors.ink.withValues(alpha: 0.65)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}
