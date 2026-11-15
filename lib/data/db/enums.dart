/// Группы мышц. В базе хранятся по имени (chest, back, ...), поэтому
/// значения нельзя переименовывать без миграции.
enum MuscleGroup { chest, shoulders, back, arms, legs, core, fullBody }

extension MuscleGroupLabel on MuscleGroup {
  String get label => switch (this) {
        MuscleGroup.chest => 'Грудь',
        MuscleGroup.shoulders => 'Плечи',
        MuscleGroup.back => 'Спина',
        MuscleGroup.arms => 'Руки',
        MuscleGroup.legs => 'Ноги',
        MuscleGroup.core => 'Пресс',
        MuscleGroup.fullBody => 'Всё тело',
      };
}

/// Как измеряется упражнение: повторениями или временем (планка).
enum ExerciseKind { reps, time }

extension ExerciseKindLabel on ExerciseKind {
  String get label => switch (this) {
        ExerciseKind.reps => 'Повторения',
        ExerciseKind.time => 'Время',
      };
}
