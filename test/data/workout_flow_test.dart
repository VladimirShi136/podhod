import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/data/db/database.dart';
import 'package:podhod/data/repositories/workout_repository.dart';

void main() {
  late AppDatabase db;
  late WorkoutRepository workouts;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    workouts = WorkoutRepository(db);
  });

  tearDown(() => db.close());

  Future<int> firstExerciseId() async =>
      (await db.select(db.exercises).get()).first.id;

  Future<Workout> workoutOf(int id) =>
      (db.select(db.workouts)..where((w) => w.id.equals(id))).getSingle();

  Future<int> finishedWorkout(String day) async {
    final w = await workouts.ensureWorkout(day);
    await workouts.addExercise(
      workoutId: w,
      exerciseId: await firstExerciseId(),
    );
    await workouts.startWorkout(w);
    await workouts.finishWorkout(w);
    expect((await workoutOf(w)).finishedAt, isNotNull);
    return w;
  }

  test('отметка подхода в завершённой тренировке возобновляет её', () async {
    final w = await finishedWorkout('2026-11-15');
    final entry = (await db.select(db.workoutExercises).get()).single;
    final set = (await db.select(db.workoutSets).get()).first;
    expect(entry.workoutId, w);

    await workouts.toggleSet(set.id);

    final after = await workoutOf(w);
    expect(after.finishedAt, isNull);
    expect(after.startedAt, isNotNull);
  });

  test('добавление подхода и упражнения возобновляет тренировку', () async {
    final w = await finishedWorkout('2026-11-15');
    final entry = (await db.select(db.workoutExercises).get()).single;

    await workouts.addSet(entry.id, reps: 10);
    expect((await workoutOf(w)).finishedAt, isNull);

    await workouts.finishWorkout(w);
    final other = (await db.select(db.exercises).get())[1].id;
    await workouts.addExercise(workoutId: w, exerciseId: other);
    expect((await workoutOf(w)).finishedAt, isNull);
  });

  test('изменение или удаление завершенного упражнения/подхода возобновляет тренировку', () async {
    final w = await finishedWorkout('2026-11-15');
    final entry = (await db.select(db.workoutExercises).get()).single;
    final set = (await db.select(db.workoutSets).get()).first;

    Future<void> expectReopened() async {
      final workout = await workoutOf(w);
      expect(workout.finishedAt, isNull);
      expect(workout.startedAt, isNotNull);
    }

    await workouts.setExerciseDone(entry.id, true);
    await expectReopened();

    await workouts.finishWorkout(w);
    await workouts.updateSet(set.id, reps: 12);
    await expectReopened();

    await workouts.finishWorkout(w);
    await workouts.removeSet(set.id);
    await expectReopened();

    await workouts.finishWorkout(w);
    await workouts.removeExercise(entry.id);
    await expectReopened();
  });

  test('watchActiveDays и bestBefore', () async {
    final id = await firstExerciseId();
    for (final day in ['2026-11-10', '2026-11-12']) {
      final w = await workouts.ensureWorkout(day);
      final entry = await workouts.addExercise(workoutId: w, exerciseId: id);
      final sets = await (db.select(
        db.workoutSets,
      )..where((s) => s.workoutExerciseId.equals(entry))).get();
      await workouts.updateSet(
        sets.first.id,
        reps: day == '2026-11-10' ? 15 : 20,
      );
      await workouts.toggleSet(sets.first.id);
    }
    // день без выполненных подходов не считается
    final empty = await workouts.ensureWorkout('2026-11-13');
    await workouts.addExercise(workoutId: empty, exerciseId: id);

    expect(await workouts.watchActiveDays().first, [
      '2026-11-12',
      '2026-11-10',
    ]);
    expect((await workouts.bestBefore(id, '2026-11-12')).reps, 15);
    expect((await workouts.bestBefore(id, '2026-11-10')).reps, isNull);
  });
}
