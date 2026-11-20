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

    await programs.updateItem(a, values: [15, 15, 15, 15], isTime: false);
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
    await programs.updateItem(a, values: [12, 12, 12, 12, 12], isTime: false);

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
    expect(d.items.single.values, [20, 10, 10, 20]);

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
  test('программа из тренировки хранит значение каждого подхода', () async {
    final w = await workouts.ensureWorkout('2026-11-19');
    final entry =
        await workouts.addExercise(workoutId: w, exerciseId: pushUps.id);
    final existing = await (db.select(db.workoutSets)
          ..where((s) => s.workoutExerciseId.equals(entry)))
        .get();
    for (final s in existing) {
      await workouts.removeSet(s.id);
    }
    for (final reps in [6, 7, 10, 11, 8, 8]) {
      await workouts.addSet(entry, reps: reps);
    }

    final id = await programs.createFromWorkout(
      'Подтягивания',
      (await workouts.getDay('2026-11-19'))!,
    );
    final item = (await programs.getById(id))!.items.single;
    expect(item.values, [6, 7, 10, 11, 8, 8]);
    expect(item.summary, '6·7·10·11·8·8');

    // в другом дне получаются те же шесть подходов, а не 6×6
    await programs.applyToDay(id, '2026-11-20', workouts);
    final day = (await workouts.getDay('2026-11-20'))!;
    expect(day.exercises.single.sets.map((s) => s.reps),
        [6, 7, 10, 11, 8, 8]);

    // правка отдельных подходов
    await programs.updateItem(item.entry.id,
        values: [6, 7, 10, 11, 8, 9, 9], isTime: false);
    expect((await programs.getById(id))!.items.single.values,
        [6, 7, 10, 11, 8, 9, 9]);
  });

  test('старая программа без plan читается как «подходы × значение»', () async {
    final id = await programs.create('Старая');
    final item = await programs.addExercise(id, pushUps.id);
    await (db.update(db.programExercises)..where((e) => e.id.equals(item)))
        .write(const ProgramExercisesCompanion(
      sets: Value(4),
      reps: Value(12),
      plan: Value(null),
    ));
    final loaded = (await programs.getById(id))!.items.single;
    expect(loaded.values, [12, 12, 12, 12]);
    expect(loaded.summary, '4×12');
  });
}
