import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/day_key.dart';
import '../../core/utils/plural.dart';
import '../../core/widgets/notebook_widgets.dart';
import '../../core/widgets/paper_lines.dart';
import '../../notebook/page_header.dart';
import 'exercise_progress_sheet.dart';
import 'progress_logic.dart';
import 'progress_providers.dart';

/// Прогресс: общие итоги и личные рекорды по упражнениям.
class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  /// Рекорд, поставленный не позже этого числа дней назад, помечаем штампом.
  static const _freshDays = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(progressProvider).value;
    final now = DateTime.now();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Прогресс',
            subtitle: 'Объём и личные рекорды',
          ),
          if (data == null)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (data.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: kLine),
              child: LineText(
                'Здесь появятся итоги и рекорды, когда вы отметите первые '
                'подходы на странице «Сегодня».',
                style: TextStyle(
                  fontFamily: AppText.bodyFamily,
                  fontSize: 18,
                  color: AppColors.ink,
                ),
              ),
            )
          else ...[
            _Totals(totals: data.totals),
            LineText('Рекорды', style: AppText.hand(28)),
            const SizedBox(height: kLine),
            for (final e in data.exercises)
              _RecordRow(
                progress: e,
                fresh:
                    e.hasImprovedRecord &&
                    now.difference(parseDayKey(e.bestDay)).inDays <= _freshDays,
                onTap: () => showExerciseProgress(context, e.exerciseId),
              ),
            const SizedBox(height: kLine),
          ],
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals});

  final ProgressTotals totals;

  @override
  Widget build(BuildContext context) {
    // три строки тетради: число на двух, подпись на третьей
    Widget cell(int n, String label) => Expanded(
      child: SizedBox(
        height: 3 * kLine,
        child: Column(
          children: [
            SizedBox(
              height: 2 * kLine,
              child: Center(child: Text('$n', style: AppText.hand(40))),
            ),
            LineText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.body(14),
            ),
          ],
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cell(
          totals.workouts,
          plural(totals.workouts, 'тренировка', 'тренировки', 'тренировок'),
        ),
        cell(totals.sets, plural(totals.sets, 'подход', 'подхода', 'подходов')),
        cell(
          totals.reps,
          plural(totals.reps, 'повторение', 'повторения', 'повторений'),
        ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.progress,
    required this.fresh,
    required this.onTap,
  });

  final ExerciseProgress progress;
  final bool fresh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = formatDayShort(parseDayKey(progress.lastDay));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: LineSnap(
        minLines: 3,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LineText(
                    progress.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(19),
                  ),
                  LineText(
                    '${progress.sessions} '
                    '${plural(progress.sessions, 'тренировка', 'тренировки', 'тренировок')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      13,
                      color: AppColors.ink.withValues(alpha: 0.65),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: LineText(
                          'Последняя $last',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            13,
                            color: AppColors.ink.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                      if (fresh) ...[
                        const SizedBox(width: 6),
                        const Stamp('РЕКОРД'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            LineText(
              progress.format(progress.bestValue),
              style: AppText.hand(28),
            ),
            SizedBox(
              height: kLine,
              child: Center(
                child: Icon(Icons.chevron_right, color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
