import 'package:drift/drift.dart';

import 'enums.dart';

/// Каталог упражнений (стартовые + свои).
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 80).unique()();

  TextColumn get muscleGroup => textEnum<MuscleGroup>()();

  TextColumn get kind => textEnum<ExerciseKind>()();

  /// true для упражнений, добавленных пользователем.
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  /// Более лёгкий вариант в цепочке прогрессии
  /// (например, у «Подтягиваний» это «Австралийские подтягивания»).
  IntColumn get progressionParentId => integer()
      .nullable()
      .references(Exercises, #id, onDelete: KeyAction.setNull)();
}

/// Тренировка за день.
@TableIndex(name: 'workouts_day', columns: {#day})
class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// День в формате ГГГГ-ММ-ДД по местному времени, например «2026-11-14».
  /// Строкой, чтобы календарь не зависел от часовых поясов.
  TextColumn get day => text().withLength(min: 10, max: 10)();

  DateTimeColumn get startedAt => dateTime().nullable()();

  DateTimeColumn get finishedAt => dateTime().nullable()();

  TextColumn get note => text().withDefault(const Constant(''))();

  /// Самочувствие 1..5.
  IntColumn get mood => integer().nullable()();
}

/// Упражнение внутри тренировки.
@TableIndex(name: 'workout_exercises_workout', columns: {#workoutId})
class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();

  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.restrict)();

  /// Порядок в списке дня (с нуля).
  IntColumn get position => integer()();

  BoolColumn get done => boolean().withDefault(const Constant(false))();
}

/// Подход: повторения или секунды, выполнен или нет.
@TableIndex(name: 'workout_sets_entry', columns: {#workoutExerciseId})
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get workoutExerciseId => integer()
      .references(WorkoutExercises, #id, onDelete: KeyAction.cascade)();

  /// Номер подхода (с нуля).
  IntColumn get setIndex => integer()();

  IntColumn get reps => integer().nullable()();

  IntColumn get seconds => integer().nullable()();

  BoolColumn get done => boolean().withDefault(const Constant(false))();
}

/// Программа: сохранённый комплекс упражнений («Понедельник: грудь»).
class Programs extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Упражнение в программе: сколько подходов и по сколько повторений
/// (или секунд, если упражнение на время).
class ProgramExercises extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get programId =>
      integer().references(Programs, #id, onDelete: KeyAction.cascade)();

  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.restrict)();

  /// Порядок в программе (с нуля).
  IntColumn get position => integer()();

  IntColumn get sets => integer().withDefault(const Constant(3))();

  IntColumn get reps => integer().nullable()();

  IntColumn get seconds => integer().nullable()();

  /// Значения каждого подхода через запятую («6,7,10,11,8,8»): повторения
  /// или секунды. Если пусто, берутся `sets` подходов по `reps`/`seconds`.
  TextColumn get plan => text().nullable()();
}
