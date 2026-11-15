import '../db/database.dart';

/// Упражнение в тренировке вместе с описанием и подходами.
class WorkoutExerciseDetails {
  const WorkoutExerciseDetails({
    required this.entry,
    required this.exercise,
    required this.sets,
  });

  /// Запись «упражнение в этой тренировке» (позиция, отметка «выполнено»).
  final WorkoutExercise entry;

  /// Упражнение из каталога.
  final Exercise exercise;

  /// Подходы по порядку.
  final List<WorkoutSet> sets;

  int get doneSets => sets.where((s) => s.done).length;

  bool get allSetsDone => sets.isNotEmpty && sets.every((s) => s.done);
}

/// Тренировка дня целиком.
class WorkoutDetails {
  const WorkoutDetails({required this.workout, required this.exercises});

  final Workout workout;
  final List<WorkoutExerciseDetails> exercises;

  bool get isEmpty => exercises.isEmpty;
}

/// Личный рекорд по упражнению (только выполненные подходы).
class PersonalBest {
  const PersonalBest({this.reps, this.seconds});

  /// Максимум повторений в одном подходе.
  final int? reps;

  /// Максимум секунд в одном подходе.
  final int? seconds;
}
