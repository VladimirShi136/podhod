import 'package:drift/drift.dart';

import '../../core/utils/set_values.dart';
import '../db/database.dart';
import '../db/enums.dart';
import 'models.dart';
import 'workout_repository.dart';

/// Упражнение программы вместе с описанием из каталога.
class ProgramItem {
  const ProgramItem({required this.entry, required this.exercise});

  final ProgramExercise entry;
  final Exercise exercise;

  bool get isTime => exercise.kind == ExerciseKind.time;

  /// Значение каждого подхода (повторения или секунды).
  /// Для программ, созданных до учёта отдельных подходов, все равны.
  List<int> get values {
    final plan = decodeSetValues(entry.plan);
    if (plan != null) return plan;
    final value = isTime ? (entry.seconds ?? 30) : (entry.reps ?? 10);
    return List.filled(entry.sets < 1 ? 1 : entry.sets, value);
  }

  /// «3×10», «3×30с» или «6·7·10·11».
  String get summary => formatSetValues(values, isTime: isTime);
}

class ProgramDetails {
  const ProgramDetails({required this.program, required this.items});

  final Program program;
  final List<ProgramItem> items;
}

/// Программы тренировок.
class ProgramRepository {
  ProgramRepository(this._db);

  final AppDatabase _db;

  static const int defaultSets = 3;
  static const int defaultReps = 10;
  static const int defaultSeconds = 30;

  // ───────────────────────── чтение ─────────────────────────

  /// Все программы, новые первыми. Обновляется при любом изменении.
  Stream<List<ProgramDetails>> watchAll() {
    // Важно: drift хранит потоки по тексту запроса и НЕ учитывает readsFrom.
    // Если запрос совпадёт с таким же в другом репозитории (у WorkoutRepository
    // тоже 'SELECT 1'), оба потока склеятся и один перестанет обновляться.
    // Поэтому текст запроса здесь уникальный.
    return _db
        .customSelect(
          'SELECT 1 AS programs_watch',
          readsFrom: {_db.programs, _db.programExercises, _db.exercises},
        )
        .watch()
        .asyncMap((_) => _loadAll());
  }

  Future<ProgramDetails?> getById(int id) async {
    final program = await (_db.select(_db.programs)
          ..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    return program == null ? null : _details(program);
  }

  // ───────────────────────── запись ─────────────────────────

  Future<int> create(String name) {
    return _db
        .into(_db.programs)
        .insert(ProgramsCompanion.insert(name: _clean(name)));
  }

  Future<void> rename(int id, String name) {
    return (_db.update(_db.programs)..where((p) => p.id.equals(id)))
        .write(ProgramsCompanion(name: Value(_clean(name))));
  }

  Future<void> delete(int id) {
    // Упражнения программы удалятся каскадом.
    return (_db.delete(_db.programs)..where((p) => p.id.equals(id))).go();
  }

  /// Добавляет упражнение в конец программы с подходами по умолчанию.
  Future<int> addExercise(int programId, int exerciseId) {
    return _db.transaction(() async {
      final exercise = await (_db.select(_db.exercises)
            ..where((e) => e.id.equals(exerciseId)))
          .getSingle();
      final maxPos = _db.programExercises.position.max();
      final row = await (_db.selectOnly(_db.programExercises)
            ..addColumns([maxPos])
            ..where(_db.programExercises.programId.equals(programId)))
          .getSingle();
      final next = (row.read(maxPos) ?? -1) + 1;
      final isTime = exercise.kind == ExerciseKind.time;

      return _db.into(_db.programExercises).insert(
            ProgramExercisesCompanion.insert(
              programId: programId,
              exerciseId: exerciseId,
              position: next,
              sets: const Value(defaultSets),
              reps: Value(isTime ? null : defaultReps),
              seconds: Value(isTime ? defaultSeconds : null),
              plan: Value(
                encodeSetValues(
                  List.filled(defaultSets, isTime ? defaultSeconds : defaultReps),
                ),
              ),
            ),
          );
    });
  }

  Future<void> removeItem(int itemId) {
    return (_db.delete(_db.programExercises)
          ..where((e) => e.id.equals(itemId)))
        .go();
  }

  /// Задаёт подходы упражнения программы: по одному значению на подход
  /// (повторения или секунды, если [isTime]).
  Future<void> updateItem(
    int itemId, {
    required List<int> values,
    required bool isTime,
  }) {
    final clean = [for (final v in values) v < 1 ? 1 : v];
    if (clean.isEmpty) {
      throw ArgumentError.value(values, 'values', 'Нужен хотя бы один подход');
    }
    return (_db.update(_db.programExercises)
          ..where((e) => e.id.equals(itemId)))
        .write(
      ProgramExercisesCompanion(
        sets: Value(clean.length),
        reps: Value(isTime ? null : clean.first),
        seconds: Value(isTime ? clean.first : null),
        plan: Value(encodeSetValues(clean)),
      ),
    );
  }

  /// Сдвигает упражнение на [delta] позиций (−1 вверх, +1 вниз).
  Future<void> moveItem(int itemId, int delta) {
    return _db.transaction(() async {
      final item = await (_db.select(_db.programExercises)
            ..where((e) => e.id.equals(itemId)))
          .getSingleOrNull();
      if (item == null) return;
      final list = await (_db.select(_db.programExercises)
            ..where((e) => e.programId.equals(item.programId))
            ..orderBy([
              (e) => OrderingTerm.asc(e.position),
              (e) => OrderingTerm.asc(e.id),
            ]))
          .get();
      final i = list.indexWhere((e) => e.id == itemId);
      final j = i + delta;
      if (i < 0 || j < 0 || j >= list.length) return;

      final ids = [for (final e in list) e.id];
      final moved = ids.removeAt(i);
      ids.insert(j, moved);
      for (var k = 0; k < ids.length; k++) {
        await (_db.update(_db.programExercises)
              ..where((e) => e.id.equals(ids[k])))
            .write(ProgramExercisesCompanion(position: Value(k)));
      }
    });
  }

  /// Создаёт программу из упражнений тренировки: подходов столько же,
  /// и у каждого подхода своё значение (6, 7, 10, 11…).
  Future<int> createFromWorkout(String name, WorkoutDetails workout) {
    return _db.transaction(() async {
      final id = await create(name);
      var position = 0;
      for (final d in workout.exercises) {
        final isTime = d.exercise.kind == ExerciseKind.time;
        final fallback = isTime ? defaultSeconds : defaultReps;
        final values = d.sets.isEmpty
            ? List.filled(defaultSets, fallback)
            : [
                for (final s in d.sets)
                  ((isTime ? s.seconds : s.reps) ?? fallback),
              ];
        await _db.into(_db.programExercises).insert(
              ProgramExercisesCompanion.insert(
                programId: id,
                exerciseId: d.exercise.id,
                position: position++,
                sets: Value(values.length),
                reps: Value(isTime ? null : values.first),
                seconds: Value(isTime ? values.first : null),
                plan: Value(encodeSetValues(values)),
              ),
            );
      }
      return id;
    });
  }

  /// Добавляет упражнения программы в тренировку дня [day] (дописывает
  /// в конец, существующее не трогает). Возвращает, сколько добавлено.
  Future<int> applyToDay(
    int programId,
    String day,
    WorkoutRepository workouts,
  ) async {
    final details = await getById(programId);
    if (details == null || details.items.isEmpty) return 0;

    final workoutId = await workouts.ensureWorkout(day);
    await _db.transaction(() async {
      final maxPos = _db.workoutExercises.position.max();
      final posRow = await (_db.selectOnly(_db.workoutExercises)
            ..addColumns([maxPos])
            ..where(_db.workoutExercises.workoutId.equals(workoutId)))
          .getSingle();
      var position = (posRow.read(maxPos) ?? -1) + 1;

      for (final item in details.items) {
        // Подходы берём из программы, а не «как в прошлый раз», поэтому
        // записи создаём напрямую, без WorkoutRepository.addExercise.
        final entryId = await _db.into(_db.workoutExercises).insert(
              WorkoutExercisesCompanion.insert(
                workoutId: workoutId,
                exerciseId: item.exercise.id,
                position: position++,
              ),
            );
        await _db.batch((batch) {
          final values = item.values;
          batch.insertAll(_db.workoutSets, [
            for (var i = 0; i < values.length; i++)
              WorkoutSetsCompanion.insert(
                workoutExerciseId: entryId,
                setIndex: i,
                reps: Value(item.isTime ? null : values[i]),
                seconds: Value(item.isTime ? values[i] : null),
              ),
          ]);
        });
      }
      // Если тренировка дня была завершена, она снова становится «идущей».
      await _db.customUpdate(
        'UPDATE workouts SET finished_at = NULL WHERE id = ?',
        variables: [Variable.withInt(workoutId)],
        updates: {_db.workouts},
      );
    });
    return details.items.length;
  }

  // ───────────────────────── внутреннее ─────────────────────────

  String _clean(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Название не может быть пустым');
    }
    return trimmed.length > 60 ? trimmed.substring(0, 60) : trimmed;
  }

  Future<List<ProgramDetails>> _loadAll() async {
    final programs = await (_db.select(_db.programs)
          ..orderBy([
            (p) => OrderingTerm.desc(p.createdAt),
            (p) => OrderingTerm.desc(p.id),
          ]))
        .get();
    return [for (final p in programs) await _details(p)];
  }

  Future<ProgramDetails> _details(Program program) async {
    final query = _db.select(_db.programExercises).join([
      innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.programExercises.exerciseId),
      ),
    ])
      ..where(_db.programExercises.programId.equals(program.id))
      ..orderBy([
        OrderingTerm.asc(_db.programExercises.position),
        OrderingTerm.asc(_db.programExercises.id),
      ]);
    final rows = await query.get();
    return ProgramDetails(
      program: program,
      items: [
        for (final r in rows)
          ProgramItem(
            entry: r.readTable(_db.programExercises),
            exercise: r.readTable(_db.exercises),
          ),
      ],
    );
  }
}
