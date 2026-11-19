import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(appDatabaseProvider)),
);

/// Упражнение с путём прогрессии.
class ExerciseInfo {
  const ExerciseInfo({
    required this.exercise,
    required this.easier,
    required this.harder,
  });

  final Exercise exercise;

  /// Цепочка более лёгких вариантов (от самого простого).
  final List<Exercise> easier;

  /// Прямые следующие шаги.
  final List<Exercise> harder;
}

/// Описание упражнения. После правки или удаления обновляйте через
/// ref.invalidate(exerciseInfoProvider(id)).
final exerciseInfoProvider =
    FutureProvider.autoDispose.family<ExerciseInfo?, int>((ref, id) async {
  final exercises = ref.watch(exerciseRepositoryProvider);
  final catalog = ref.watch(catalogRepositoryProvider);
  final exercise = await exercises.getById(id);
  if (exercise == null) return null;
  return ExerciseInfo(
    exercise: exercise,
    easier: await catalog.ancestors(exercise),
    harder: await exercises.harderVariants(id),
  );
});
