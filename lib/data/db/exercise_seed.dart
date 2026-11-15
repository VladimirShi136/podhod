import 'package:drift/drift.dart';

import 'database.dart';
import 'enums.dart';

class _Seed {
  const _Seed(
    this.name,
    this.group, {
    this.kind = ExerciseKind.reps,
    this.easier,
  });

  final String name;
  final MuscleGroup group;
  final ExerciseKind kind;

  /// Название более лёгкого упражнения в цепочке прогрессии.
  /// Оно должно стоять в списке РАНЬШЕ этого.
  final String? easier;
}

/// Стартовый каталог: воркаут и упражнения с собственным весом.
const _catalog = <_Seed>[
  // Грудь
  _Seed('Отжимания с колен', MuscleGroup.chest),
  _Seed('Отжимания', MuscleGroup.chest, easier: 'Отжимания с колен'),
  _Seed('Широкие отжимания', MuscleGroup.chest, easier: 'Отжимания'),
  _Seed('Узкие отжимания', MuscleGroup.chest, easier: 'Отжимания'),
  _Seed('Алмазные отжимания', MuscleGroup.chest, easier: 'Узкие отжимания'),
  _Seed('Отжимания с ногами на возвышении', MuscleGroup.chest,
      easier: 'Отжимания'),
  _Seed('Отжимания на одной руке', MuscleGroup.chest,
      easier: 'Отжимания с ногами на возвышении'),

  // Плечи
  _Seed('Пайк-отжимания', MuscleGroup.shoulders),
  _Seed('Отжимания в стойке на руках', MuscleGroup.shoulders,
      easier: 'Пайк-отжимания'),

  // Спина
  _Seed('Австралийские подтягивания', MuscleGroup.back),
  _Seed('Подтягивания', MuscleGroup.back, easier: 'Австралийские подтягивания'),
  _Seed('Подтягивания обратным хватом', MuscleGroup.back,
      easier: 'Австралийские подтягивания'),
  _Seed('Подтягивания узким хватом', MuscleGroup.back, easier: 'Подтягивания'),
  _Seed('Супермен', MuscleGroup.back),

  // Руки
  _Seed('Обратные отжимания от скамьи', MuscleGroup.arms),
  _Seed('Отжимания на брусьях', MuscleGroup.arms,
      easier: 'Обратные отжимания от скамьи'),

  // Ноги
  _Seed('Приседания', MuscleGroup.legs),
  _Seed('Выпады', MuscleGroup.legs, easier: 'Приседания'),
  _Seed('Болгарские сплит-приседания', MuscleGroup.legs, easier: 'Выпады'),
  _Seed('Приседания-пистолетик', MuscleGroup.legs,
      easier: 'Болгарские сплит-приседания'),
  _Seed('Прыжки из приседа', MuscleGroup.legs, easier: 'Приседания'),
  _Seed('Ягодичный мостик', MuscleGroup.legs),
  _Seed('Подъёмы на носки', MuscleGroup.legs),

  // Пресс
  _Seed('Скручивания', MuscleGroup.core),
  _Seed('Подъём ног лёжа', MuscleGroup.core),
  _Seed('Подъём ног в висе', MuscleGroup.core, easier: 'Подъём ног лёжа'),
  _Seed('Велосипед', MuscleGroup.core),
  _Seed('Альпинист', MuscleGroup.core),
  _Seed('Планка', MuscleGroup.core, kind: ExerciseKind.time),
  _Seed('Боковая планка', MuscleGroup.core,
      kind: ExerciseKind.time, easier: 'Планка'),

  // Всё тело
  _Seed('Берпи', MuscleGroup.fullBody),
  _Seed('Прыжки «звёздочка»', MuscleGroup.fullBody),
  _Seed('Бег на месте', MuscleGroup.fullBody, kind: ExerciseKind.time),
];

/// Заполняет каталог при первом создании базы.
Future<void> seedExercises(AppDatabase db) async {
  final ids = <String, int>{};

  for (final seed in _catalog) {
    final parentId = seed.easier == null ? null : ids[seed.easier!];
    assert(
      seed.easier == null || parentId != null,
      'Упражнение «${seed.easier}» должно стоять в каталоге раньше «${seed.name}»',
    );

    ids[seed.name] = await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            name: seed.name,
            muscleGroup: seed.group,
            kind: seed.kind,
            progressionParentId: Value(parentId),
          ),
        );
  }
}
