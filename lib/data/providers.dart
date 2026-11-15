import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/workout_repository.dart';

/// Единственный экземпляр базы данных на всё приложение.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(appDatabaseProvider)),
);

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepository(ref.watch(appDatabaseProvider)),
);

/// Запуск приложения: открывает базу (при первом запуске создаёт таблицы
/// и заполняет каталог). Обложка ждёт этот провайдер, прежде чем открыться.
final appInitProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM exercises')
      .getSingle();
  debugPrint('База данных готова, упражнений в каталоге: ${row.read<int>('c')}');
});
