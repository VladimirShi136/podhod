import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/data/db/database.dart';
import 'package:podhod/data/repositories/progress_repository.dart';
import 'package:podhod/data/repositories/workout_repository.dart';
import 'package:podhod/features/progress/progress_logic.dart';

void main() {
  late AppDatabase db;
  late WorkoutRepository workouts;
  late ProgressRepository progress;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    workouts = WorkoutRepository(db);
    progress = ProgressRepository(db);
  });

  tearDown(() => db.close());

  test('в прогресс попадают только выполненные подходы', () async {
    final exercise = (await db.select(db.exercises).get()).first;
    final w1 = await workouts.ensureWorkout('2026-11-10');
    final e1 = await workouts.addExercise(workoutId: w1, exerciseId: exercise.id);
    final sets1 = await (db.select(db.workoutSets)
          ..where((s) => s.workoutExerciseId.equals(e1)))
        .get();
    // выполняем два подхода из трёх
    await workouts.toggleSet(sets1[0].id);
    await workouts.toggleSet(sets1[1].id);

    // день без выполненных подходов не должен попасть в данные
    final w2 = await workouts.ensureWorkout('2026-11-11');
    await workouts.addExercise(workoutId: w2, exerciseId: exercise.id);

    final rows = await progress.watchRows().first;
    expect(rows, hasLength(1));
    expect(rows.single.day, '2026-11-10');
    expect(rows.single.sets, 2);

    final data = buildProgress(rows);
    expect(data.totals.workouts, 1);
    expect(data.exercises.single.sessions, 1);
  });
}
