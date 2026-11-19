import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/enums.dart';

enum DeleteResult { deleted, inUse, notCustom, notFound }

/// Операции каталога сверх базовых из ExerciseRepository:
/// путь прогрессии, правка и удаление своих упражнений.
class CatalogRepository {
  CatalogRepository(this._db);

  final AppDatabase _db;

  /// Более лёгкие варианты по цепочке: от самого простого к ближайшему.
  /// Для «Алмазных отжиманий»: Отжимания с колен, Отжимания, Узкие отжимания.
  Future<List<Exercise>> ancestors(Exercise exercise) async {
    final chain = <Exercise>[];
    var parentId = exercise.progressionParentId;
    // Ограничение на случай испорченных данных с циклом.
    var guard = 0;
    while (parentId != null && guard++ < 20) {
      final parent = await (_db.select(_db.exercises)
            ..where((e) => e.id.equals(parentId!)))
          .getSingleOrNull();
      if (parent == null) break;
      chain.insert(0, parent);
      parentId = parent.progressionParentId;
    }
    return chain;
  }

  /// Сколько раз упражнение встречается в тренировках и программах.
  Future<int> usageCount(int exerciseId) async {
    final inWorkouts = await _count('workout_exercises', exerciseId);
    final inPrograms = await _count('program_exercises', exerciseId);
    return inWorkouts + inPrograms;
  }

  Future<int> _count(String table, int exerciseId) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM $table WHERE exercise_id = ?',
          variables: [Variable.withInt(exerciseId)],
        )
        .getSingle();
    return row.read<int>('c');
  }

  /// Меняет название и группу своего упражнения. Возвращает false, если
  /// такое название уже занято другим упражнением.
  Future<bool> updateCustom(
    int id, {
    required String name,
    required MuscleGroup group,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Название не может быть пустым');
    }
    final lower = trimmed.toLowerCase();
    final all = await _db.select(_db.exercises).get();
    for (final e in all) {
      if (e.id != id && e.name.toLowerCase() == lower) return false;
    }
    await (_db.update(_db.exercises)
          ..where((e) => e.id.equals(id) & e.isCustom.equals(true)))
        .write(ExercisesCompanion(name: Value(trimmed), muscleGroup: Value(group)));
    return true;
  }

  /// Удаляет своё упражнение, если оно нигде не используется.
  Future<DeleteResult> deleteCustom(int id) async {
    final exercise = await (_db.select(_db.exercises)
          ..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    if (exercise == null) return DeleteResult.notFound;
    if (!exercise.isCustom) return DeleteResult.notCustom;
    if (await usageCount(id) > 0) return DeleteResult.inUse;
    await (_db.delete(_db.exercises)..where((e) => e.id.equals(id))).go();
    return DeleteResult.deleted;
  }
}
