import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/enums.dart';
import 'models.dart';

class _PlannedSet {
  const _PlannedSet({this.reps, this.seconds});

  final int? reps;
  final int? seconds;
}

/// Тренировки, упражнения дня и подходы.
class WorkoutRepository {
  WorkoutRepository(this._db);

  final AppDatabase _db;

  /// Сколько подходов и повторений ставится у упражнения, которого
  /// раньше не было в истории.
  static const int defaultSetCount = 3;
  static const int defaultReps = 10;
  static const int defaultSeconds = 30;

  // ───────────────────────── чтение ─────────────────────────

  /// Тренировка за день [day] («ГГГГ-ММ-ДД») или null, если её ещё нет.
  Future<WorkoutDetails?> getDay(String day) async {
    final workout = await _workoutByDay(day);
    if (workout == null) return null;
    return _loadDetails(workout);
  }

  /// То же, но обновляется при любом изменении тренировок, упражнений
  /// и подходов.
  Stream<WorkoutDetails?> watchDay(String day) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.workouts,
            _db.workoutExercises,
            _db.workoutSets,
            _db.exercises,
          },
        )
        .watch()
        .asyncMap((_) => getDay(day));
  }

  /// Дни с тренировками между [fromDay] и [toDay] включительно.
  /// Днём с тренировкой считается день, где есть хотя бы одно упражнение.
  Stream<Set<String>> watchWorkoutDays(String fromDay, String toDay) {
    return _db
        .customSelect(
          'SELECT DISTINCT w.day AS day '
          'FROM workouts w '
          'JOIN workout_exercises we ON we.workout_id = w.id '
          'WHERE w.day BETWEEN ? AND ?',
          variables: [Variable.withString(fromDay), Variable.withString(toDay)],
          readsFrom: {_db.workouts, _db.workoutExercises},
        )
        .watch()
        .map((rows) => {for (final r in rows) r.read<String>('day')});
  }

  /// Дни, в которые выполнен хотя бы один подход (новые первыми).
  Stream<List<String>> watchActiveDays() {
    return _db
        .customSelect(
          'SELECT DISTINCT w.day AS day '
          'FROM workouts w '
          'JOIN workout_exercises we ON we.workout_id = w.id '
          'JOIN workout_sets s ON s.workout_exercise_id = we.id '
          'WHERE s.done = 1 '
          'ORDER BY w.day DESC',
          readsFrom: {_db.workouts, _db.workoutExercises, _db.workoutSets},
        )
        .watch()
        .map((rows) => [for (final r in rows) r.read<String>('day')]);
  }

  /// Выполненные подходы из последней тренировки ДО дня [beforeDay],
  /// в которой было это упражнение. Нужны для подсказки «в прошлый раз было…».
  Future<List<WorkoutSet>> lastSets(
    int exerciseId, {
    required String beforeDay,
  }) async {
    final latest = _db.select(_db.workoutExercises).join([
      innerJoin(
        _db.workouts,
        _db.workouts.id.equalsExp(_db.workoutExercises.workoutId),
      ),
    ])
      ..where(
        _db.workoutExercises.exerciseId.equals(exerciseId) &
            _db.workouts.day.isSmallerThanValue(beforeDay),
      )
      ..orderBy([
        OrderingTerm.desc(_db.workouts.day),
        OrderingTerm.desc(_db.workoutExercises.id),
      ])
      ..limit(1);

    final row = await latest.getSingleOrNull();
    if (row == null) return [];

    final entryId = row.readTable(_db.workoutExercises).id;
    return (_db.select(_db.workoutSets)
          ..where(
            (s) => s.workoutExerciseId.equals(entryId) & s.done.equals(true),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.setIndex)]))
        .get();
  }

  /// Личный рекорд по упражнению (учитываются только выполненные подходы).
  Future<PersonalBest> bestOf(int exerciseId) async {
    final row = await _db
        .customSelect(
          'SELECT MAX(s.reps) AS best_reps, MAX(s.seconds) AS best_seconds '
          'FROM workout_sets s '
          'JOIN workout_exercises we ON we.id = s.workout_exercise_id '
          'WHERE we.exercise_id = ? AND s.done = 1',
          variables: [Variable.withInt(exerciseId)],
          readsFrom: {_db.workoutSets, _db.workoutExercises},
        )
        .getSingle();

    return PersonalBest(
      reps: row.readNullable<int>('best_reps'),
      seconds: row.readNullable<int>('best_seconds'),
    );
  }

  /// Рекорд по упражнению среди тренировок ДО дня [day].
  Future<PersonalBest> bestBefore(int exerciseId, String day) async {
    final row = await _db
        .customSelect(
          'SELECT MAX(s.reps) AS best_reps, MAX(s.seconds) AS best_seconds '
          'FROM workout_sets s '
          'JOIN workout_exercises we ON we.id = s.workout_exercise_id '
          'JOIN workouts w ON w.id = we.workout_id '
          'WHERE we.exercise_id = ? AND s.done = 1 AND w.day < ?',
          variables: [Variable.withInt(exerciseId), Variable.withString(day)],
          readsFrom: {_db.workoutSets, _db.workoutExercises, _db.workouts},
        )
        .getSingle();
    return PersonalBest(
      reps: row.readNullable<int>('best_reps'),
      seconds: row.readNullable<int>('best_seconds'),
    );
  }

  // ───────────────────────── запись ─────────────────────────

  /// Возвращает id тренировки за [day], при необходимости создаёт её.
  Future<int> ensureWorkout(String day) async {
    final existing = await _workoutByDay(day);
    if (existing != null) return existing.id;
    return _db.into(_db.workouts).insert(WorkoutsCompanion.insert(day: day));
  }

  /// Добавляет упражнение в конец списка дня и сразу создаёт подходы:
  /// как в прошлый раз (повторения те же, но не отмечены) либо 3 по умолчанию.
  /// Возвращает id записи «упражнение в тренировке».
  Future<int> addExercise({
    required int workoutId,
    required int exerciseId,
  }) {
    return _db.transaction(() async {
      final workout = await (_db.select(_db.workouts)
            ..where((w) => w.id.equals(workoutId)))
          .getSingle();
      final exercise = await (_db.select(_db.exercises)
            ..where((e) => e.id.equals(exerciseId)))
          .getSingle();

      final maxPosition = _db.workoutExercises.position.max();
      final positionRow = await (_db.selectOnly(_db.workoutExercises)
            ..addColumns([maxPosition])
            ..where(_db.workoutExercises.workoutId.equals(workoutId)))
          .getSingle();
      final nextPosition = (positionRow.read(maxPosition) ?? -1) + 1;

      final entryId = await _db.into(_db.workoutExercises).insert(
            WorkoutExercisesCompanion.insert(
              workoutId: workoutId,
              exerciseId: exerciseId,
              position: nextPosition,
            ),
          );

      final previous = await lastSets(exerciseId, beforeDay: workout.day);
      final planned = <_PlannedSet>[];
      if (previous.isNotEmpty) {
        for (final s in previous) {
          planned.add(_PlannedSet(reps: s.reps, seconds: s.seconds));
        }
      } else {
        for (var i = 0; i < defaultSetCount; i++) {
          planned.add(
            exercise.kind == ExerciseKind.time
                ? const _PlannedSet(seconds: defaultSeconds)
                : const _PlannedSet(reps: defaultReps),
          );
        }
      }

      await _db.batch((batch) {
        batch.insertAll(_db.workoutSets, [
          for (var i = 0; i < planned.length; i++)
            WorkoutSetsCompanion.insert(
              workoutExerciseId: entryId,
              setIndex: i,
              reps: Value(planned[i].reps),
              seconds: Value(planned[i].seconds),
            ),
        ]);
      });

      return entryId;
    });
  }

  Future<void> removeExercise(int entryId) {
    // Подходы удалятся каскадом.
    return (_db.delete(_db.workoutExercises)
          ..where((e) => e.id.equals(entryId)))
        .go();
  }

  /// Отмечает упражнение выполненным (или снимает отметку) вместе со всеми
  /// его подходами.
  Future<void> setExerciseDone(int entryId, bool done) {
    return _db.transaction(() async {
      await (_db.update(_db.workoutSets)
            ..where((s) => s.workoutExerciseId.equals(entryId)))
          .write(WorkoutSetsCompanion(done: Value(done)));
      await (_db.update(_db.workoutExercises)
            ..where((e) => e.id.equals(entryId)))
          .write(WorkoutExercisesCompanion(done: Value(done)));
    });
  }

  /// Добавляет подход в конец. Упражнение при этом перестаёт быть «выполненным».
  Future<int> addSet(int entryId, {int? reps, int? seconds}) {
    return _db.transaction(() async {
      final maxIndex = _db.workoutSets.setIndex.max();
      final row = await (_db.selectOnly(_db.workoutSets)
            ..addColumns([maxIndex])
            ..where(_db.workoutSets.workoutExerciseId.equals(entryId)))
          .getSingle();
      final next = (row.read(maxIndex) ?? -1) + 1;

      final id = await _db.into(_db.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              workoutExerciseId: entryId,
              setIndex: next,
              reps: Value(reps),
              seconds: Value(seconds),
            ),
          );
      await _syncEntryDone(entryId);
      return id;
    });
  }

  /// Меняет повторения и/или секунды подхода. Не переданное не трогает.
  Future<void> updateSet(int setId, {int? reps, int? seconds}) {
    return (_db.update(_db.workoutSets)..where((s) => s.id.equals(setId)))
        .write(
      WorkoutSetsCompanion(
        reps: reps == null ? const Value.absent() : Value(reps),
        seconds: seconds == null ? const Value.absent() : Value(seconds),
      ),
    );
  }

  /// Переключает «выполнен / не выполнен». Если выполнены все подходы,
  /// упражнение тоже становится выполненным.
  Future<void> toggleSet(int setId) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.workoutSets)
            ..where((s) => s.id.equals(setId)))
          .getSingle();
      await (_db.update(_db.workoutSets)..where((s) => s.id.equals(setId)))
          .write(WorkoutSetsCompanion(done: Value(!row.done)));
      await _syncEntryDone(row.workoutExerciseId);
    });
  }

  Future<void> removeSet(int setId) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.workoutSets)
            ..where((s) => s.id.equals(setId)))
          .getSingle();
      await (_db.delete(_db.workoutSets)..where((s) => s.id.equals(setId)))
          .go();
      await _syncEntryDone(row.workoutExerciseId);
    });
  }

  /// Ставит время начала, если оно ещё не стоит.
  Future<void> startWorkout(int workoutId) async {
    final workout = await (_db.select(_db.workouts)
          ..where((w) => w.id.equals(workoutId)))
        .getSingle();
    if (workout.startedAt != null) return;
    await (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId)))
        .write(WorkoutsCompanion(startedAt: Value(DateTime.now())));
  }

  Future<void> finishWorkout(int workoutId) {
    return (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId)))
        .write(WorkoutsCompanion(finishedAt: Value(DateTime.now())));
  }

  Future<void> reopenWorkout(int workoutId) {
    return (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId)))
        .write(const WorkoutsCompanion(finishedAt: Value(null)));
  }

  Future<void> setNote(int workoutId, String note) {
    return (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId)))
        .write(WorkoutsCompanion(note: Value(note)));
  }

  /// Самочувствие 1..5 или null.
  Future<void> setMood(int workoutId, int? mood) {
    return (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId)))
        .write(WorkoutsCompanion(mood: Value(mood)));
  }

  /// Удаляет тренировку вместе с упражнениями и подходами (каскадом).
  Future<void> deleteWorkout(int workoutId) {
    return (_db.delete(_db.workouts)..where((w) => w.id.equals(workoutId)))
        .go();
  }

  // ───────────────────────── внутреннее ─────────────────────────

  Future<Workout?> _workoutByDay(String day) {
    return (_db.select(_db.workouts)
          ..where((w) => w.day.equals(day))
          ..orderBy([(w) => OrderingTerm.asc(w.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<WorkoutDetails> _loadDetails(Workout workout) async {
    final entryRows = await (_db.select(_db.workoutExercises).join([
      innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.workoutExercises.exerciseId),
      ),
    ])
          ..where(_db.workoutExercises.workoutId.equals(workout.id))
          ..orderBy([OrderingTerm.asc(_db.workoutExercises.position)]))
        .get();

    final entryIds = [
      for (final r in entryRows) r.readTable(_db.workoutExercises).id,
    ];

    final sets = entryIds.isEmpty
        ? <WorkoutSet>[]
        : await (_db.select(_db.workoutSets)
              ..where((s) => s.workoutExerciseId.isIn(entryIds))
              ..orderBy([(s) => OrderingTerm.asc(s.setIndex)]))
            .get();

    final setsByEntry = <int, List<WorkoutSet>>{};
    for (final s in sets) {
      final list = setsByEntry.putIfAbsent(s.workoutExerciseId, () => []);
      list.add(s);
    }

    return WorkoutDetails(
      workout: workout,
      exercises: [
        for (final r in entryRows)
          WorkoutExerciseDetails(
            entry: r.readTable(_db.workoutExercises),
            exercise: r.readTable(_db.exercises),
            sets: setsByEntry[r.readTable(_db.workoutExercises).id] ?? const [],
          ),
      ],
    );
  }

  /// Упражнение выполнено, если все его подходы выполнены.
  Future<void> _syncEntryDone(int entryId) async {
    final sets = await (_db.select(_db.workoutSets)
          ..where((s) => s.workoutExerciseId.equals(entryId)))
        .get();
    final allDone = sets.isNotEmpty && sets.every((s) => s.done);
    await (_db.update(_db.workoutExercises)..where((e) => e.id.equals(entryId)))
        .write(WorkoutExercisesCompanion(done: Value(allDone)));
  }
}
