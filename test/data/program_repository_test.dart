import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/data/db/database.dart';
import 'package:podhod/data/db/enums.dart';
import 'package:podhod/data/repositories/models.dart';
import 'package:podhod/data/repositories/program_repository.dart';
import 'package:podhod/data/repositories/workout_repository.dart';

void main() {
  late AppDatabase db;
  late ProgramRepository programs;
  late WorkoutRepository workouts;
  late Exercise pushUps;
  late Exercise plank;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    programs = ProgramRepository(db);
    workouts = WorkoutRepository(db);
    final all = await db.select(db.exercises).get();
    pushUps = all.firstWhere((e) => e.kind == ExerciseKind.reps);
    plank = all.firstWhere((e) => e.kind == ExerciseKind.time);
  });

  tearDown(() => db.close());

  test('создание, добавление упражнений со значениями по умолчанию', () async {
    final id = await programs.create('  Фулбоди ');
    await programs.addExercise(id, pushUps.id);
    await programs.addExercise(id, plank.id);

    final d = (await programs.getById(id))!;
    expect(d.program.name, 'Фулбоди');
    expect(d.items.map((i) => i.exercise.id), [pushUps.id, plank.id]);
    expect(d.items[0].summary, '3×10');
    expect(d.items[1].summary, '3×30с');
  });

  test('пустое название не принимается', () async {
    expect(() => programs.create('   '), throwsArgumentError);
  });

  test('редактирование и перестановка', () async {
    final id = await programs.create('A');
    final a = await programs.addExercise(id, pushUps.id);
    final b = await programs.addExercise(id, plank.id);

    await programs.updateItem(a, sets: 4, reps: 15);
    await programs.moveItem(b, -1);

    final d = (await programs.getById(id))!;
    expect(d.items.first.entry.id, b);
    expect(d.items.last.summary, '4×15');

    await programs.moveItem(b, -1); // уже первый: ничего не меняется
    expect((await programs.getById(id))!.items.first.entry.id, b);

    await programs.removeItem(b);
    expect((await programs.getById(id))!.items, hasLength(1));
  });

  test('применение к дню создаёт подходы по программе', () async {
    final id = await programs.create('A');
    final a = await programs.addExercise(id, pushUps.id);
    await programs.addExercise(id, plank.id);
    await programs.updateItem(a, sets: 5, reps: 12);

    final count = await programs.applyToDay(id, '2026-11-16', workouts);
    expect(count, 2);

    final day = (await workouts.getDay('2026-11-16'))!;
    expect(day.exercises, hasLength(2));
    expect(day.exercises[0].sets, hasLength(5));
    expect(day.exercises[0].sets.every((s) => s.reps == 12 && !s.done), isTrue);
    expect(day.exercises[1].sets, hasLength(3));
    expect(day.exercises[1].sets.every((s) => s.seconds == 30), isTrue);

    // повторное применение дописывает в конец
    await programs.applyToDay(id, '2026-11-16', workouts);
    expect((await workouts.getDay('2026-11-16'))!.exercises, hasLength(4));
  });

  test('программа из тренировки и каскадное удаление', () async {
    final w = await workouts.ensureWorkout('2026-11-15');
    final entry =
        await workouts.addExercise(workoutId: w, exerciseId: pushUps.id);
    final sets = await (db.select(db.workoutSets)
          ..where((s) => s.workoutExerciseId.equals(entry)))
        .get();
    await workouts.updateSet(sets.first.id, reps: 20);
    await workouts.addSet(entry, reps: 20);

    final id = await programs.createFromWorkout('Моя', (await workouts.getDay('2026-11-15'))!);
    final d = (await programs.getById(id))!;
    expect(d.items.single.entry.sets, 4);
    expect(d.items.single.entry.reps, 20);

    await programs.delete(id);
    expect(await programs.getById(id), isNull);
    expect(await db.select(db.programExercises).get(), isEmpty);
  });

  test('applyToDay пустой программы ничего не создаёт', () async {
    final id = await programs.create('Пустая');
    expect(await programs.applyToDay(id, '2026-11-20', workouts), 0);
    expect(await workouts.getDay('2026-11-20'), isNull);
  });
  test('применение продолжает нумерацию и снимает «завершена»', () async {
    final w = await workouts.ensureWorkout('2026-11-18');
    await workouts.addExercise(workoutId: w, exerciseId: plank.id);
    await workouts.startWorkout(w);
    await workouts.finishWorkout(w);

    final id = await programs.create('A');
    await programs.addExercise(id, pushUps.id);
    await programs.applyToDay(id, '2026-11-18', workouts);

    final day = (await workouts.getDay('2026-11-18'))!;
    expect(day.exercises.map((e) => e.entry.position), [0, 1]);
    expect(day.workout.finishedAt, isNull);
  });
  test('поток программ не ломает поток тренировки дня', () async {
    // Программы подписываются первыми, как при запуске приложения.
    final programsSub = programs.watchAll().listen((_) {});
    addTearDown(programsSub.cancel);
    final events = <WorkoutDetails?>[];
    final daySub = workouts.watchDay('2026-11-25').listen(events.add);
    addTearDown(daySub.cancel);
    await pumpEventQueue(times: 50);

    final w = await workouts.ensureWorkout('2026-11-25');
    await workouts.addExercise(workoutId: w, exerciseId: pushUps.id);
    await pumpEventQueue(times: 100);

    expect(events.last?.exercises, hasLength(1));
  });
}
