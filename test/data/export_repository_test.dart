import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/data/db/database.dart';
import 'package:podhod/data/db/enums.dart';
import 'package:podhod/data/repositories/exercise_repository.dart';
import 'package:podhod/data/repositories/export_repository.dart';
import 'package:podhod/data/repositories/program_repository.dart';
import 'package:podhod/data/repositories/workout_repository.dart';

void main() {
  late AppDatabase db;
  late ExportRepository export;
  late WorkoutRepository workouts;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    export = ExportRepository(db);
    workouts = WorkoutRepository(db);
  });

  tearDown(() => db.close());

  Future<void> fill() async {
    final custom = await ExerciseRepository(db).addCustom(
      name: 'Моё; "особое"',
      group: MuscleGroup.core,
      kind: ExerciseKind.reps,
    );
    final starter = (await db.select(db.exercises).get()).first;
    final w = await workouts.ensureWorkout('2026-11-14');
    final entry = await workouts.addExercise(workoutId: w, exerciseId: starter.id);
    final sets = await (db.select(db.workoutSets)
          ..where((s) => s.workoutExerciseId.equals(entry)))
        .get();
    await workouts.toggleSet(sets.first.id);
    await workouts.setNote(w, 'Хорошо; но "тяжело"');
    await workouts.setMood(w, 4);
    await workouts.addExercise(workoutId: w, exerciseId: custom);

    final programs = ProgramRepository(db);
    final p = await programs.create('Пн');
    await programs.addExercise(p, starter.id);
  }

  test('CSV: BOM, заголовок, экранирование, одна строка на подход', () async {
    await fill();
    final csv = buildCsv(await export.load());
    expect(csv.startsWith('﻿Дата;Упражнение;Группа;'), isTrue);
    final lines = csv.trim().split('\r\n');
    // 3 подхода у стартового + 3 у своего + заголовок
    expect(lines.length, 7);
    expect(csv.contains('"Моё; ""особое"""'), isTrue);
    expect(csv.contains('"Хорошо; но ""тяжело"""'), isTrue);
    expect(lines[1].split(';')[6], 'да');
    expect(lines[2].split(';')[6], 'нет');
  });

  test('JSON: структура резервной копии', () async {
    await fill();
    final json =
        jsonDecode(buildJson(await export.load())) as Map<String, dynamic>;
    expect(json['app'], 'podhod');
    expect(json['version'], 1);
    expect((json['customExercises'] as List).single['name'], 'Моё; "особое"');
    final workout = (json['workouts'] as List).single as Map<String, dynamic>;
    expect(workout['day'], '2026-11-14');
    expect(workout['mood'], 4);
    expect((workout['exercises'] as List), hasLength(2));
    expect((json['programs'] as List).single['name'], 'Пн');
  });

  test('пустая база экспортируется без ошибок', () async {
    final data = await export.load();
    expect(buildCsv(data).trim().split('\r\n'), hasLength(1));
    expect((jsonDecode(buildJson(data)) as Map)['workouts'], isEmpty);
  });

  test('eraseAll стирает данные пользователя, но не стартовый каталог', () async {
    await fill();
    final before = (await db.select(db.exercises).get()).length;
    await export.eraseAll();

    expect(await db.select(db.workouts).get(), isEmpty);
    expect(await db.select(db.workoutSets).get(), isEmpty);
    expect(await db.select(db.programs).get(), isEmpty);
    expect(await db.select(db.programExercises).get(), isEmpty);
    final after = await db.select(db.exercises).get();
    expect(after.length, before - 1);
    expect(after.any((e) => e.isCustom), isFalse);
  });
}
