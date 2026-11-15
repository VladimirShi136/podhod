import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/enums.dart';

/// Каталог упражнений.
class ExerciseRepository {
  ExerciseRepository(this._db);

  final AppDatabase _db;

  /// Все упражнения по алфавиту. Можно отфильтровать по группе мышц
  /// и по строке поиска.
  ///
  /// Поиск делается в Dart, а не в SQL: LIKE в SQLite не различает регистр
  /// только у латиницы, а у кириллицы различает.
  Stream<List<Exercise>> watchAll({MuscleGroup? group, String query = ''}) {
    final select = _db.select(_db.exercises)
      ..orderBy([(e) => OrderingTerm.asc(e.name)]);
    final selected = group;
    if (selected != null) {
      select.where((e) => e.muscleGroup.equalsValue(selected));
    }

    final needle = query.trim().toLowerCase();
    return select.watch().map(
          (all) => needle.isEmpty
              ? all
              : all.where((e) => e.name.toLowerCase().contains(needle)).toList(),
        );
  }

  Future<Exercise?> getById(int id) {
    return (_db.select(_db.exercises)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
  }

  /// Более сложные варианты упражнения (следующие шаги прогрессии).
  Future<List<Exercise>> harderVariants(int exerciseId) {
    return (_db.select(_db.exercises)
          ..where((e) => e.progressionParentId.equals(exerciseId))
          ..orderBy([(e) => OrderingTerm.asc(e.name)]))
        .get();
  }

  /// Более лёгкий вариант упражнения, если он есть.
  Future<Exercise?> easierVariant(Exercise exercise) async {
    final parentId = exercise.progressionParentId;
    if (parentId == null) return null;
    return getById(parentId);
  }

  /// Добавляет своё упражнение. Если упражнение с таким названием уже есть
  /// (без учёта регистра), возвращает его id и ничего не создаёт.
  Future<int> addCustom({
    required String name,
    required MuscleGroup group,
    required ExerciseKind kind,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Название не может быть пустым');
    }

    final lower = trimmed.toLowerCase();
    final all = await _db.select(_db.exercises).get();
    for (final e in all) {
      if (e.name.toLowerCase() == lower) return e.id;
    }

    return _db.into(_db.exercises).insert(
          ExercisesCompanion.insert(
            name: trimmed,
            muscleGroup: group,
            kind: kind,
            isCustom: const Value(true),
          ),
        );
  }
}
