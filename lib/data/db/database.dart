import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'enums.dart';
import 'exercise_seed.dart';
import 'tables.dart';

// Файл создаёт build_runner: dart run build_runner build
part 'database.g.dart';

@DriftDatabase(
  tables: [
    Exercises,
    Workouts,
    WorkoutExercises,
    WorkoutSets,
    Programs,
    ProgramExercises,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Без аргументов открывает файл на устройстве.
  /// В тестах сюда передают базу в памяти.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Увеличивайте при каждом изменении таблиц и добавляйте шаг в [migration].
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedExercises(this);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Версия 2: программы тренировок.
            await m.createTable(programs);
            await m.createTable(programExercises);
          }
        },
        beforeOpen: (details) async {
          // Без этого SQLite не будет выполнять каскадное удаление.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'podhod',
    native: const DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );
}
