import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/notebook_widgets.dart';
import '../../core/widgets/paper_lines.dart';
import '../../data/providers.dart';
import '../../data/repositories/models.dart';
import 'rest_timer.dart';
import 'set_bubble.dart';
import 'sets_format.dart';
import 'today_providers.dart';

/// Строка упражнения на странице дня: галочка, название, кружки подходов,
/// справа краткий итог.
class ExerciseRow extends ConsumerWidget {
  const ExerciseRow({
    super.key,
    required this.details,
    required this.day,
    required this.onOpen,
  });

  final WorkoutExerciseDetails details;
  final String day;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = details.exercise.kind;
    final entry = details.entry;
    final repo = ref.read(workoutRepositoryProvider);
    final best = ref
        .watch(bestBeforeProvider((details.exercise.id, day)))
        .value;
    final record = isRecord(details.sets, kind, best);
    final done = entry.done;

    return LineSnap(
      minLines: 2,
      child: Row(
        children: [
          HandCheckbox(
            checked: done,
            animate: true,
            onChanged: (v) => repo.setExerciseDone(entry.id, v),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                                alignment: Alignment.centerLeft,
                                children: [...previousChildren, ?currentChild],
                              ),
                          child: Text(
                            details.exercise.name,
                            key: ValueKey(done),
                            style: AppText.body(19).copyWith(
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: AppColors.red,
                              decorationThickness: 2,
                              color: done
                                  ? AppColors.ink.withValues(alpha: 0.6)
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < details.sets.length;
                                      i++
                                    )
                                      SetBubble(
                                        number: i + 1,
                                        done: details.sets[i].done,
                                        onTap: () => toggleSetWithRest(
                                          ref,
                                          details.sets[i],
                                          day,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (record) ...[
                              const SizedBox(width: 6),
                              const Stamp('РЕКОРД'),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 92),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          setsSummary(details.sets, kind),
                          style: AppText.hand(24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
