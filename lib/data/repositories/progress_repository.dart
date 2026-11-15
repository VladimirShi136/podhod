import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/enums.dart';

/// Итог по одному упражнению за один день (только выполненные подходы).
class ProgressRow {
  const ProgressRow({
    required this.exerciseId,
    required this.name,
    required this.kind,
    required this.day,
    required this.maxReps,
    required this.maxSeconds,
    required this.totalReps,
    required this.totalSeconds,
    required this.sets,
  });

  final int exerciseId;
  final String name;
  final ExerciseKind kind;
  final String day;
  final int maxReps;
  final int maxSeconds;
  final int totalReps;
  final int totalSeconds;
  final int sets;
}

/// Данные для экрана «Прогресс».
class ProgressRepository {
  ProgressRepository(this._db);

  final AppDatabase _db;

  /// Строки «упражнение × день» по всей истории, старые дни первыми.
  /// Обновляется при любом изменении подходов.
  Stream<List<ProgressRow>> watchRows() {
    return _db
        .customSelect(
          'SELECT e.id AS exercise_id, e.name AS name, e.kind AS kind, '
          'w.day AS day, '
          'MAX(COALESCE(s.reps, 0)) AS max_reps, '
          'MAX(COALESCE(s.seconds, 0)) AS max_seconds, '
          'SUM(COALESCE(s.reps, 0)) AS total_reps, '
          'SUM(COALESCE(s.seconds, 0)) AS total_seconds, '
          'COUNT(*) AS sets '
          'FROM workout_sets s '
          'JOIN workout_exercises we ON we.id = s.workout_exercise_id '
          'JOIN workouts w ON w.id = we.workout_id '
          'JOIN exercises e ON e.id = we.exercise_id '
          'WHERE s.done = 1 '
          'GROUP BY e.id, w.day '
          'ORDER BY w.day ASC',
          readsFrom: {
            _db.workoutSets,
            _db.workoutExercises,
            _db.workouts,
            _db.exercises,
          },
        )
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              ProgressRow(
                exerciseId: r.read<int>('exercise_id'),
                name: r.read<String>('name'),
                kind: ExerciseKind.values.byName(r.read<String>('kind')),
                day: r.read<String>('day'),
                maxReps: r.read<int>('max_reps'),
                maxSeconds: r.read<int>('max_seconds'),
                totalReps: r.read<int>('total_reps'),
                totalSeconds: r.read<int>('total_seconds'),
                sets: r.read<int>('sets'),
              ),
          ],
        );
  }
}
