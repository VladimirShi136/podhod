import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/data/db/enums.dart';
import 'package:podhod/data/repositories/progress_repository.dart';
import 'package:podhod/features/progress/progress_logic.dart';

ProgressRow row(int id, String name, ExerciseKind kind, String day,
        {int maxReps = 0, int maxSeconds = 0, int totalReps = 0, int totalSeconds = 0, int sets = 3}) =>
    ProgressRow(
      exerciseId: id,
      name: name,
      kind: kind,
      day: day,
      maxReps: maxReps,
      maxSeconds: maxSeconds,
      totalReps: totalReps,
      totalSeconds: totalSeconds,
      sets: sets,
    );

void main() {
  final rows = [
    row(1, 'Отжимания', ExerciseKind.reps, '2026-11-10', maxReps: 15, totalReps: 40),
    row(1, 'Отжимания', ExerciseKind.reps, '2026-11-14', maxReps: 20, totalReps: 50),
    row(1, 'Отжимания', ExerciseKind.reps, '2026-11-12', maxReps: 18, totalReps: 45),
    row(2, 'Планка', ExerciseKind.time, '2026-11-14', maxSeconds: 60, totalSeconds: 150),
  ];

  test('точки упорядочены по дате, рекорд и день рекорда', () {
    final d = buildProgress(rows);
    final push = d.exercises.firstWhere((e) => e.exerciseId == 1);
    expect(push.points.map((p) => p.day),
        ['2026-11-10', '2026-11-12', '2026-11-14']);
    expect(push.bestValue, 20);
    expect(push.bestDay, '2026-11-14');
    expect(push.hasImprovedRecord, isTrue);
    expect(push.format(20), '20');
  });

  test('одна тренировка — не рекорд; время считается в секундах', () {
    final plank = buildProgress(rows).exercises.firstWhere((e) => e.exerciseId == 2);
    expect(plank.bestValue, 60);
    expect(plank.hasImprovedRecord, isFalse);
    expect(plank.format(60), '60 с');
  });

  test('итоги: дни, подходы, повторения без времени', () {
    final t = buildProgress(rows).totals;
    expect(t.workouts, 3);
    expect(t.sets, 12);
    expect(t.reps, 135);
  });

  test('порядок: недавно тренированные первыми; пустая история', () {
    // оба упражнения делали 14 ноября: дальше порядок по алфавиту
    expect(buildProgress(rows).exercises.map((e) => e.exerciseId), [1, 2]);
    final older = [...rows]..removeWhere((r) => r.exerciseId == 1 && r.day == '2026-11-14');
    expect(buildProgress(older).exercises.first.exerciseId, 2);
    expect(buildProgress([]).isEmpty, isTrue);
    expect(shortDate('2026-11-05'), '5.11');
  });
}
