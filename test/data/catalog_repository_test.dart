import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/data/db/database.dart';
import 'package:podhod/data/db/enums.dart';
import 'package:podhod/data/repositories/catalog_repository.dart';
import 'package:podhod/data/repositories/exercise_repository.dart';
import 'package:podhod/data/repositories/program_repository.dart';
import 'package:podhod/data/repositories/workout_repository.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository catalog;
  late ExerciseRepository exercises;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    catalog = CatalogRepository(db);
    exercises = ExerciseRepository(db);
  });

  tearDown(() => db.close());

  Future<Exercise> byName(String name) =>
      (db.select(db.exercises)..where((e) => e.name.equals(name))).getSingle();

  test('путь прогрессии: от самого простого к ближайшему', () async {
    final diamond = await byName('Алмазные отжимания');
    final chain = await catalog.ancestors(diamond);
    expect(chain.map((e) => e.name),
        ['Отжимания с колен', 'Отжимания', 'Узкие отжимания']);

    final root = await byName('Отжимания с колен');
    expect(await catalog.ancestors(root), isEmpty);
  });

  test('своё упражнение: правка и проверка занятого названия', () async {
    final id = await exercises.addCustom(
      name: 'Моё',
      group: MuscleGroup.core,
      kind: ExerciseKind.reps,
    );
    expect(await catalog.updateCustom(id, name: 'Моё новое', group: MuscleGroup.legs), isTrue);
    final e = await byName('Моё новое');
    expect(e.muscleGroup, MuscleGroup.legs);

    // название стартового упражнения занято (без учёта регистра)
    expect(await catalog.updateCustom(id, name: 'отжимания', group: MuscleGroup.legs), isFalse);
    // своё название можно «обновить» тем же значением
    expect(await catalog.updateCustom(id, name: 'моё новое', group: MuscleGroup.legs), isTrue);
  });

  test('удаление: стартовые и используемые не удаляются', () async {
    final starter = await byName('Отжимания');
    expect(await catalog.deleteCustom(starter.id), DeleteResult.notCustom);
    expect(await catalog.deleteCustom(99999), DeleteResult.notFound);

    final id = await exercises.addCustom(
      name: 'Своё',
      group: MuscleGroup.arms,
      kind: ExerciseKind.reps,
    );
    final workouts = WorkoutRepository(db);
    final w = await workouts.ensureWorkout('2026-11-16');
    await workouts.addExercise(workoutId: w, exerciseId: id);
    expect(await catalog.usageCount(id), 1);
    expect(await catalog.deleteCustom(id), DeleteResult.inUse);

    await workouts.deleteWorkout(w);
    final programs = ProgramRepository(db);
    final p = await programs.create('P');
    await programs.addExercise(p, id);
    expect(await catalog.deleteCustom(id), DeleteResult.inUse);

    await programs.delete(p);
    expect(await catalog.deleteCustom(id), DeleteResult.deleted);
    expect(await exercises.getById(id), isNull);
  });
}
