import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/core/utils/day_key.dart';
import 'package:podhod/data/db/database.dart';
import 'package:podhod/data/db/enums.dart';
import 'package:podhod/data/repositories/exercise_repository.dart';
import 'package:podhod/data/repositories/workout_repository.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepository exercises;
  late WorkoutRepository workouts;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    exercises = ExerciseRepository(db);
    workouts = WorkoutRepository(db);
  });

  tearDown(() => db.close());

  Future<Exercise> byName(String name) {
    return (db.select(db.exercises)..where((e) => e.name.equals(name)))
        .getSingle();
  }

  Future<List<WorkoutSet>> setsOf(int entryId) {
    return (db.select(db.workoutSets)
          ..where((s) => s.workoutExerciseId.equals(entryId))
          ..orderBy([(s) => OrderingTerm.asc(s.setIndex)]))
        .get();
  }

  Future<WorkoutExercise> entryById(int id) {
    return (db.select(db.workoutExercises)..where((e) => e.id.equals(id)))
        .getSingle();
  }

  /// Задаёт повторения и отмечает все подходы выполненными.
  Future<void> doSets(int entryId, List<int> reps) async {
    final sets = await setsOf(entryId);
    for (var i = 0; i < reps.length; i++) {
      await workouts.updateSet(sets[i].id, reps: reps[i]);
      await workouts.toggleSet(sets[i].id);
    }
  }

  group('каталог', () {
    test('при создании базы заполняется стартовыми упражнениями', () async {
      final all = await db.select(db.exercises).get();
      expect(all.length, greaterThan(25));
    });

    test('цепочки прогрессии ссылаются на существующие упражнения', () async {
      final pullUps = await byName('Подтягивания');
      final parent = await exercises.easierVariant(pullUps);
      expect(parent?.name, 'Австралийские подтягивания');

      final harder = await exercises.harderVariants(pullUps.id);
      expect(harder.map((e) => e.name), contains('Подтягивания узким хватом'));
    });

    test('поиск работает с кириллицей независимо от регистра', () async {
      final found = await exercises.watchAll(query: 'ОТЖИМ').first;
      expect(found, isNotEmpty);
      expect(found.every((e) => e.name.toLowerCase().contains('отжим')), isTrue);
    });

    test('фильтр по группе мышц', () async {
      final core = await exercises.watchAll(group: MuscleGroup.core).first;
      expect(core.map((e) => e.name), contains('Планка'));
      expect(core.every((e) => e.muscleGroup == MuscleGroup.core), isTrue);
    });

    test('своё упражнение добавляется один раз', () async {
      final a = await exercises.addCustom(
        name: '  Отжимания на кулаках ',
        group: MuscleGroup.chest,
        kind: ExerciseKind.reps,
      );
      final b = await exercises.addCustom(
        name: 'отжимания на кулаках',
        group: MuscleGroup.chest,
        kind: ExerciseKind.reps,
      );
      expect(b, a);
      final e = await exercises.getById(a);
      expect(e?.isCustom, isTrue);
    });
  });

  group('тренировки', () {
    test('новое упражнение получает 3 подхода по умолчанию', () async {
      final pushUps = await byName('Отжимания');
      final plank = await byName('Планка');
      final w = await workouts.ensureWorkout('2026-11-10');

      final e1 = await workouts.addExercise(workoutId: w, exerciseId: pushUps.id);
      final e2 = await workouts.addExercise(workoutId: w, exerciseId: plank.id);

      final s1 = await setsOf(e1);
      expect(s1.length, 3);
      expect(s1.every((s) => s.reps == 10 && s.seconds == null), isTrue);

      final s2 = await setsOf(e2);
      expect(s2.every((s) => s.seconds == 30 && s.reps == null), isTrue);

      expect((await entryById(e1)).position, 0);
      expect((await entryById(e2)).position, 1);
    });

    test('ensureWorkout не создаёт дубликат за один день', () async {
      final a = await workouts.ensureWorkout('2026-11-10');
      final b = await workouts.ensureWorkout('2026-11-10');
      expect(b, a);
    });

    test('подставляет подходы из прошлой тренировки', () async {
      final pushUps = await byName('Отжимания');

      final w1 = await workouts.ensureWorkout('2026-11-10');
      final e1 = await workouts.addExercise(workoutId: w1, exerciseId: pushUps.id);
      await doSets(e1, [15, 14, 12]);

      final w2 = await workouts.ensureWorkout('2026-11-12');
      final e2 = await workouts.addExercise(workoutId: w2, exerciseId: pushUps.id);

      final sets = await setsOf(e2);
      expect(sets.map((s) => s.reps), [15, 14, 12]);
      expect(sets.every((s) => !s.done), isTrue);
    });

    test('упражнение выполнено, когда выполнены все подходы', () async {
      final pushUps = await byName('Отжимания');
      final w = await workouts.ensureWorkout('2026-11-10');
      final e = await workouts.addExercise(workoutId: w, exerciseId: pushUps.id);

      final sets = await setsOf(e);
      for (final s in sets) {
        await workouts.toggleSet(s.id);
      }
      expect((await entryById(e)).done, isTrue);

      await workouts.toggleSet(sets.first.id);
      expect((await entryById(e)).done, isFalse);

      await workouts.addSet(e, reps: 10);
      expect((await setsOf(e)).length, 4);
    });

    test('setExerciseDone отмечает все подходы', () async {
      final squats = await byName('Приседания');
      final w = await workouts.ensureWorkout('2026-11-10');
      final e = await workouts.addExercise(workoutId: w, exerciseId: squats.id);

      await workouts.setExerciseDone(e, true);
      expect((await setsOf(e)).every((s) => s.done), isTrue);
      expect((await entryById(e)).done, isTrue);

      await workouts.setExerciseDone(e, false);
      expect((await setsOf(e)).every((s) => !s.done), isTrue);
    });

    test('удаление тренировки удаляет упражнения и подходы', () async {
      final pushUps = await byName('Отжимания');
      final w = await workouts.ensureWorkout('2026-11-10');
      final e = await workouts.addExercise(workoutId: w, exerciseId: pushUps.id);
      expect((await setsOf(e)).length, 3);

      await workouts.deleteWorkout(w);

      expect(await db.select(db.workoutExercises).get(), isEmpty);
      expect(await db.select(db.workoutSets).get(), isEmpty);
    });

    test('getDay собирает тренировку целиком', () async {
      final pushUps = await byName('Отжимания');
      final squats = await byName('Приседания');
      final w = await workouts.ensureWorkout('2026-11-10');
      await workouts.addExercise(workoutId: w, exerciseId: pushUps.id);
      await workouts.addExercise(workoutId: w, exerciseId: squats.id);

      final day = await workouts.getDay('2026-11-10');
      expect(day, isNotNull);
      expect(day!.exercises.map((e) => e.exercise.name), ['Отжимания', 'Приседания']);
      expect(day.exercises.first.sets.length, 3);
      expect(await workouts.getDay('2026-11-11'), isNull);
    });

    test('watchDay присылает обновления', () async {
      final pushUps = await byName('Отжимания');
      final w = await workouts.ensureWorkout('2026-11-10');

      final next = workouts
          .watchDay('2026-11-10')
          .firstWhere((d) => d != null && d.exercises.length == 1);
      await workouts.addExercise(workoutId: w, exerciseId: pushUps.id);

      final details = await next.timeout(const Duration(seconds: 5));
      expect(details!.exercises.single.exercise.name, 'Отжимания');
    });
  });

  group('рекорды и календарь', () {
    test('bestOf считает только выполненные подходы', () async {
      final pushUps = await byName('Отжимания');
      final w = await workouts.ensureWorkout('2026-11-10');
      final e = await workouts.addExercise(workoutId: w, exerciseId: pushUps.id);

      expect((await workouts.bestOf(pushUps.id)).reps, isNull);

      await doSets(e, [15, 14, 12]);
      // четвёртый подход с большим числом, но не выполнен
      await workouts.addSet(e, reps: 40);

      final best = await workouts.bestOf(pushUps.id);
      expect(best.reps, 15);
      expect(best.seconds, isNull);
    });

    test('дни с тренировками: пустые дни не считаются', () async {
      final pushUps = await byName('Отжимания');

      final w1 = await workouts.ensureWorkout('2026-11-10');
      await workouts.addExercise(workoutId: w1, exerciseId: pushUps.id);
      await workouts.ensureWorkout('2026-11-11'); // без упражнений

      final days = await workouts
          .watchWorkoutDays('2026-11-01', '2026-11-30')
          .first;
      expect(days, {'2026-11-10'});
    });
  });

  group('dayKey', () {
    test('форматирует и разбирает дату', () {
      expect(dayKey(DateTime(2026, 3, 5)), '2026-03-05');
      expect(parseDayKey('2026-11-14'), DateTime(2026, 11, 14));
    });
  });
}
