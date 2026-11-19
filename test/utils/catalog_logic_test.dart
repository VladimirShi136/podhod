import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/data/db/enums.dart';
import 'package:podhod/features/catalog/catalog_logic.dart';
import 'package:podhod/features/progress/progress_logic.dart';

ExerciseProgress progress(ExerciseKind kind, int best) => ExerciseProgress(
      exerciseId: 1,
      name: 'X',
      kind: kind,
      points: [DayPoint(day: '2026-11-10', best: best, total: best, sets: 1)],
    );

void main() {
  test('пороги готовности к более сложному варианту', () {
    expect(readyForHarder(null), isFalse);
    expect(readyForHarder(progress(ExerciseKind.reps, 14)), isFalse);
    expect(readyForHarder(progress(ExerciseKind.reps, 15)), isTrue);
    expect(readyForHarder(progress(ExerciseKind.time, 59)), isFalse);
    expect(readyForHarder(progress(ExerciseKind.time, 60)), isTrue);
  });
}
