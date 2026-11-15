import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/enums.dart';
import 'models.dart';
import 'workout_repository.dart';

/// Упражнение программы вместе с описанием из каталога.
class ProgramItem {
  const ProgramItem({required this.entry, required this.exercise});

  final ProgramExercise entry;
  final Exercise exercise;

  /// «3×10» или «3×30с».
  String get summary {
    final isTime = exercise.kind == ExerciseKind.time;
    final value = isTime ? (entry.seconds ?? 30) : (entry.reps ?? 10);
    return '${entry.sets}×$value${isTime ? 'с' : ''}';
  }
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
            ),
          );
    });
  }

  Future<void> removeItem(int itemId) {
    return (_db.delete(_db.programExercises)
          ..where((e) => e.id.equals(itemId)))
        .go();
  }

  /// Меняет число подходов и повторения (или секунды) упражнения программы.
  Future<void> updateItem(
    int itemId, {
    required int sets,
    int? reps,
    int? seconds,
  }) {
    return (_db.update(_db.programExercises)
          ..where((e) => e.id.equals(itemId)))
        .write(
      ProgramExercisesCompanion(
        sets: Value(sets < 1 ? 1 : sets),
        reps: reps == null ? const Value.absent() : Value(reps),
        seconds: seconds == null ? const Value.absent() : Value(seconds),
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
  /// повторения (секунды) берутся из первого подхода.
  Future<int> createFromWorkout(String name, WorkoutDetails workout) {
    return _db.transaction(() async {
      final id = await create(name);
      var position = 0;
      for (final d in workout.exercises) {
        final isTime = d.exercise.kind == ExerciseKind.time;
        final first = d.sets.isEmpty ? null : d.sets.first;
        await _db.into(_db.programExercises).insert(
              ProgramExercisesCompanion.insert(
                programId: id,
                exerciseId: d.exercise.id,
                position: position++,
                sets: Value(d.sets.isEmpty ? defaultSets : d.sets.length),
                reps: Value(isTime ? null : (first?.reps ?? defaultReps)),
                seconds:
                    Value(isTime ? (first?.seconds ?? defaultSeconds) : null),
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
          batch.insertAll(_db.workoutSets, [
            for (var i = 0; i < item.entry.sets; i++)
              WorkoutSetsCompanion.insert(
                workoutExerciseId: entryId,
                setIndex: i,
                reps: Value(item.entry.reps),
                seconds: Value(item.entry.seconds),
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
