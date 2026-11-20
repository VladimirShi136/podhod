import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/enums.dart';
import '../../core/utils/set_values.dart';
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

/// Что вернула загрузка из копии.
class RestoreResult {
  const RestoreResult({
    required this.workouts,
    required this.programs,
    this.settings,
  });

  final int workouts;
  final int programs;

  /// Настройки из копии (null, если копия старая и их не содержит).
  final Map<String, dynamic>? settings;
}

List<Map<String, dynamic>> _list(Object? value) => [
      if (value is List)
        for (final v in value)
          if (v is Map<String, dynamic>) v,
    ];

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

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

  /// Восстановление из резервной копии (JSON из [buildJson]).
  ///
  /// Текущие тренировки, программы и свои упражнения заменяются данными
  /// из копии. Сначала копия целиком проверяется, и только потом что-то
  /// стирается, поэтому испорченный файл ничего не сломает.
  /// Бросает [FormatException], если файл не похож на копию «Подхода».
  Future<RestoreResult> restoreFromJson(String text) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Файл не похож на резервную копию.');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != 'podhod') {
      throw const FormatException('Это не резервная копия приложения «Подход».');
    }
    final version = decoded['version'];
    if (version is! int || version > 2) {
      throw const FormatException(
        'Копия сделана более новой версией приложения.',
      );
    }

    final custom = _list(decoded['customExercises']);
    final workouts = _list(decoded['workouts']);
    final programs = _list(decoded['programs']);
    // Проверка структуры до записи в базу.
    for (final w in workouts) {
      final day = w['day'];
      if (day is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
        throw const FormatException('В копии неверная дата тренировки.');
      }
    }

    var workoutCount = 0;
    var programCount = 0;
    await _db.transaction(() async {
      await eraseAll();

      final byName = <String, Exercise>{
        for (final e in await _db.select(_db.exercises).get()) e.name: e,
      };

      Future<Exercise> exerciseNamed(
        String name, {
        Object? group,
        Object? kind,
      }) async {
        final found = byName[name];
        if (found != null) return found;
        final id = await _db.into(_db.exercises).insert(
              ExercisesCompanion.insert(
                name: name.length > 80 ? name.substring(0, 80) : name,
                muscleGroup: _enumByName(MuscleGroup.values, group) ??
                    MuscleGroup.fullBody,
                kind: _enumByName(ExerciseKind.values, kind) ??
                    ExerciseKind.reps,
                isCustom: const Value(true),
              ),
            );
        final created = await (_db.select(_db.exercises)
              ..where((e) => e.id.equals(id)))
            .getSingle();
        return byName[name] = created;
      }

      for (final e in custom) {
        final name = e['name'];
        if (name is String && name.trim().isNotEmpty) {
          await exerciseNamed(name.trim(), group: e['group'], kind: e['kind']);
        }
      }

      for (final w in workouts) {
        final workoutId = await _db.into(_db.workouts).insert(
              WorkoutsCompanion.insert(
                day: w['day'] as String,
                startedAt: Value(_date(w['startedAt'])),
                finishedAt: Value(_date(w['finishedAt'])),
                note: Value(w['note'] is String ? w['note'] as String : ''),
                mood: Value(w['mood'] is int ? w['mood'] as int : null),
              ),
            );
        workoutCount++;
        var position = 0;
        for (final e in _list(w['exercises'])) {
          final name = e['name'];
          if (name is! String || name.trim().isEmpty) continue;
          final exercise =
              await exerciseNamed(name.trim(), kind: e['kind']);
          final sets = _list(e['sets']);
          final entryId = await _db.into(_db.workoutExercises).insert(
                WorkoutExercisesCompanion.insert(
                  workoutId: workoutId,
                  exerciseId: exercise.id,
                  position: position++,
                  done: Value(
                    sets.isNotEmpty && sets.every((s) => s['done'] == true),
                  ),
                ),
              );
          var index = 0;
          for (final s in sets) {
            await _db.into(_db.workoutSets).insert(
                  WorkoutSetsCompanion.insert(
                    workoutExerciseId: entryId,
                    setIndex: index++,
                    reps: Value(s['reps'] is int ? s['reps'] as int : null),
                    seconds:
                        Value(s['seconds'] is int ? s['seconds'] as int : null),
                    done: Value(s['done'] == true),
                  ),
                );
          }
        }
      }

      for (final p in programs) {
        final name = p['name'];
        if (name is! String || name.trim().isEmpty) continue;
        final programId = await _db.into(_db.programs).insert(
              ProgramsCompanion.insert(
                name: name.trim().length > 60
                    ? name.trim().substring(0, 60)
                    : name.trim(),
              ),
            );
        programCount++;
        var position = 0;
        for (final i in _list(p['exercises'])) {
          final exName = i['name'];
          if (exName is! String || exName.trim().isEmpty) continue;
          final exercise = await exerciseNamed(exName.trim());
          final isTime = exercise.kind == ExerciseKind.time;
          final raw = i['values'];
          final values = [
            if (raw is List)
              for (final v in raw)
                if (v is int && v >= 1) v,
          ];
          final plan = values.isEmpty
              ? List.filled(
                  i['sets'] is int && (i['sets'] as int) >= 1
                      ? i['sets'] as int
                      : ProgramRepository.defaultSets,
                  isTime
                      ? ProgramRepository.defaultSeconds
                      : ProgramRepository.defaultReps,
                )
              : values;
          await _db.into(_db.programExercises).insert(
                ProgramExercisesCompanion.insert(
                  programId: programId,
                  exerciseId: exercise.id,
                  position: position++,
                  sets: Value(plan.length),
                  reps: Value(isTime ? null : plan.first),
                  seconds: Value(isTime ? plan.first : null),
                  plan: Value(encodeSetValues(plan)),
                ),
              );
        }
      }
    });

    final settings = decoded['settings'];
    return RestoreResult(
      workouts: workoutCount,
      programs: programCount,
      settings: settings is Map<String, dynamic> ? settings : null,
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
String buildJson(ExportData data, {Map<String, Object?>? settings}) {
  final map = <String, Object?>{
    'app': 'podhod',
    'version': 2,
    'exportedAt': data.exportedAt.toIso8601String(),
    if (settings != null) 'settings': settings,
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
