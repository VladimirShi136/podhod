import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/enums.dart';
import 'program_repository.dart';

class ExportEntry {
  const ExportEntry({required this.exercise, required this.sets});

  final Exercise exercise;
  final List<WorkoutSet> sets;
}

class ExportWorkout {
  const ExportWorkout({required this.workout, required this.entries});

  final Workout workout;
  final List<ExportEntry> entries;
}

/// Все данные пользователя для выгрузки.
class ExportData {
  const ExportData({
    required this.exportedAt,
    required this.workouts,
    required this.programs,
    required this.customExercises,
  });

  final DateTime exportedAt;
  final List<ExportWorkout> workouts;
  final List<ProgramDetails> programs;
  final List<Exercise> customExercises;
}

/// Экспорт данных (резервная копия JSON и таблица CSV) и полная очистка.
class ExportRepository {
  ExportRepository(this._db);

  final AppDatabase _db;

  Future<ExportData> load({DateTime? now}) async {
    final workouts = await (_db.select(_db.workouts)
          ..orderBy([
            (w) => OrderingTerm.asc(w.day),
            (w) => OrderingTerm.asc(w.id),
          ]))
        .get();

    final entryRows = await (_db.select(_db.workoutExercises).join([
      innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.workoutExercises.exerciseId),
      ),
    ])
          ..orderBy([
            OrderingTerm.asc(_db.workoutExercises.workoutId),
            OrderingTerm.asc(_db.workoutExercises.position),
          ]))
        .get();

    final sets = await (_db.select(_db.workoutSets)
          ..orderBy([
            (s) => OrderingTerm.asc(s.workoutExerciseId),
            (s) => OrderingTerm.asc(s.setIndex),
          ]))
        .get();
    final setsByEntry = <int, List<WorkoutSet>>{};
    for (final s in sets) {
      setsByEntry.putIfAbsent(s.workoutExerciseId, () => []).add(s);
    }

    final entriesByWorkout = <int, List<ExportEntry>>{};
    for (final r in entryRows) {
      final entry = r.readTable(_db.workoutExercises);
      entriesByWorkout.putIfAbsent(entry.workoutId, () => []).add(
            ExportEntry(
              exercise: r.readTable(_db.exercises),
              sets: setsByEntry[entry.id] ?? const [],
            ),
          );
    }

    final programs = await ProgramRepository(_db).watchAll().first;
    final custom = await (_db.select(_db.exercises)
          ..where((e) => e.isCustom.equals(true))
          ..orderBy([(e) => OrderingTerm.asc(e.name)]))
        .get();

    return ExportData(
      exportedAt: now ?? DateTime.now(),
      workouts: [
        for (final w in workouts)
          ExportWorkout(
            workout: w,
            entries: entriesByWorkout[w.id] ?? const [],
          ),
      ],
      programs: programs,
      customExercises: custom,
    );
  }

  /// Стирает тренировки, программы и свои упражнения.
  /// Стартовый каталог остаётся.
  Future<void> eraseAll() {
    return _db.transaction(() async {
      await _db.delete(_db.workouts).go(); // упражнения и подходы — каскадом
      await _db.delete(_db.programs).go();
      await (_db.delete(_db.exercises)..where((e) => e.isCustom.equals(true)))
          .go();
    });
  }
}

// ───────────────────────── форматы ─────────────────────────

String _csvCell(String value) {
  // разделитель «;» — так таблицу правильно откроют русские Excel и Numbers
  if (value.contains(';') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Таблица: одна строка на подход. Начинается с BOM, чтобы Excel
/// правильно прочитал кириллицу.
String buildCsv(ExportData data) {
  final lines = <String>[
    [
      'Дата',
      'Упражнение',
      'Группа',
      'Подход',
      'Повторения',
      'Секунды',
      'Выполнен',
      'Самочувствие',
      'Заметка',
    ].join(';'),
  ];
  for (final w in data.workouts) {
    for (final e in w.entries) {
      for (final s in e.sets) {
        lines.add(
          [
            w.workout.day,
            e.exercise.name,
            e.exercise.muscleGroup.label,
            '${s.setIndex + 1}',
            s.reps?.toString() ?? '',
            s.seconds?.toString() ?? '',
            s.done ? 'да' : 'нет',
            w.workout.mood?.toString() ?? '',
            w.workout.note,
          ].map(_csvCell).join(';'),
        );
      }
    }
  }
  return '﻿${lines.join('\r\n')}\r\n';
}

/// Резервная копия со всеми данными в удобочитаемом JSON.
String buildJson(ExportData data) {
  final map = <String, Object?>{
    'app': 'podhod',
    'version': 1,
    'exportedAt': data.exportedAt.toIso8601String(),
    'customExercises': [
      for (final e in data.customExercises)
        {
          'name': e.name,
          'group': e.muscleGroup.name,
          'kind': e.kind.name,
        },
    ],
    'workouts': [
      for (final w in data.workouts)
        {
          'day': w.workout.day,
          'startedAt': w.workout.startedAt?.toIso8601String(),
          'finishedAt': w.workout.finishedAt?.toIso8601String(),
          'mood': w.workout.mood,
          'note': w.workout.note,
          'exercises': [
            for (final e in w.entries)
              {
                'name': e.exercise.name,
                'kind': e.exercise.kind.name,
                'sets': [
                  for (final s in e.sets)
                    {'reps': s.reps, 'seconds': s.seconds, 'done': s.done},
                ],
              },
          ],
        },
    ],
    'programs': [
      for (final p in data.programs)
        {
          'name': p.program.name,
          'exercises': [
            for (final i in p.items)
              {
                'name': i.exercise.name,
                'sets': i.values.length,
                // повторения (или секунды) каждого подхода
                'values': i.values,
              },
          ],
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}
