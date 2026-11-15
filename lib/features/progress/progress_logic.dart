import '../../data/db/enums.dart';
import '../../data/repositories/progress_repository.dart';

/// Одна точка графика: результат упражнения за день.
class DayPoint {
  const DayPoint({
    required this.day,
    required this.best,
    required this.total,
    required this.sets,
  });

  final String day;

  /// Лучший подход дня (повторения или секунды).
  final int best;

  /// Сумма за день (повторения или секунды).
  final int total;

  final int sets;
}

class ExerciseProgress {
  const ExerciseProgress({
    required this.exerciseId,
    required this.name,
    required this.kind,
    required this.points,
  });

  final int exerciseId;
  final String name;
  final ExerciseKind kind;

  /// Точки по возрастанию дат.
  final List<DayPoint> points;

  int get sessions => points.length;

  String get lastDay => points.last.day;

  int get bestValue =>
      points.map((p) => p.best).reduce((a, b) => a > b ? a : b);

  /// День, когда рекорд был поставлен впервые.
  String get bestDay => points.firstWhere((p) => p.best == bestValue).day;

  /// Рекордом считаем, если улучшили прежний результат (не первый раз).
  bool get hasImprovedRecord => sessions > 1 && bestDay != points.first.day;

  String format(int value) =>
      kind == ExerciseKind.time ? '$value с' : '$value';
}

class ProgressTotals {
  const ProgressTotals({
    required this.workouts,
    required this.sets,
    required this.reps,
  });

  final int workouts;
  final int sets;
  final int reps;
}

class ProgressData {
  const ProgressData({required this.exercises, required this.totals});

  /// Недавно тренированные первыми.
  final List<ExerciseProgress> exercises;
  final ProgressTotals totals;

  bool get isEmpty => exercises.isEmpty;
}

ProgressData buildProgress(List<ProgressRow> rows) {
  final byExercise = <int, List<ProgressRow>>{};
  for (final r in rows) {
    byExercise.putIfAbsent(r.exerciseId, () => []).add(r);
  }

  final exercises = <ExerciseProgress>[];
  for (final list in byExercise.values) {
    list.sort((a, b) => a.day.compareTo(b.day));
    final first = list.first;
    final isTime = first.kind == ExerciseKind.time;
    exercises.add(
      ExerciseProgress(
        exerciseId: first.exerciseId,
        name: first.name,
        kind: first.kind,
        points: [
          for (final r in list)
            DayPoint(
              day: r.day,
              best: isTime ? r.maxSeconds : r.maxReps,
              total: isTime ? r.totalSeconds : r.totalReps,
              sets: r.sets,
            ),
        ],
      ),
    );
  }
  exercises.sort((a, b) {
    final byDay = b.lastDay.compareTo(a.lastDay);
    return byDay != 0 ? byDay : a.name.compareTo(b.name);
  });

  var sets = 0;
  var reps = 0;
  final days = <String>{};
  for (final r in rows) {
    days.add(r.day);
    sets += r.sets;
    if (r.kind == ExerciseKind.reps) reps += r.totalReps;
  }

  return ProgressData(
    exercises: exercises,
    totals: ProgressTotals(workouts: days.length, sets: sets, reps: reps),
  );
}

/// «15.11» из «2026-11-15».
String shortDate(String day) {
  final parts = day.split('-');
  return '${int.parse(parts[2])}.${parts[1]}';
}
