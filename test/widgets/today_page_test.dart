import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/core/utils/day_key.dart';
import 'package:podhod/data/db/database.dart';
import 'package:podhod/data/providers.dart';
import 'package:podhod/data/repositories/workout_repository.dart';
import 'package:podhod/features/today/today_page.dart';
import 'package:podhod/notebook/notebook_scope.dart';

void main() {
  late AppDatabase db;
  late WorkoutRepository workouts;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    workouts = WorkoutRepository(db);
  });

  tearDown(() => db.close());

  Future<int> prepareWorkout({
    required bool completeSets,
    int exerciseCount = 1,
  }) async {
    final workoutId = await workouts.ensureWorkout(dayKey(DateTime.now()));
    final exercise = (await db.select(db.exercises).get()).first;
    await workouts.startWorkout(workoutId);
    for (var i = 0; i < exerciseCount; i++) {
      final entryId = await workouts.addExercise(
        workoutId: workoutId,
        exerciseId: exercise.id,
      );
      if (completeSets) {
        final sets = await (db.select(
          db.workoutSets,
        )..where((set) => set.workoutExerciseId.equals(entryId))).get();
        for (final set in sets) {
          await workouts.toggleSet(set.id);
        }
      }
    }
    return workoutId;
  }

  Future<void> pumpTodayPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: NotebookScope(
            goTo: (_) {},
            goBack: () {},
            child: const Scaffold(body: TodayPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('предупреждает о невыполненных подходах и дает отменить', (
    tester,
  ) async {
    final workoutId = await prepareWorkout(completeSets: false);
    await pumpTodayPage(tester);

    await tester.tap(find.text('Завершить тренировку'));
    await tester.pumpAndSettle();

    expect(find.text('Есть невыполненные подходы'), findsOneWidget);
    expect(
      find.text('Осталось 3 подхода. Завершить тренировку всё равно?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    final workout = await (db.select(
      db.workouts,
    )..where((w) => w.id.equals(workoutId))).getSingle();
    expect(workout.finishedAt, isNull);
  });

  testWidgets('после подтверждения завершает тренировку', (tester) async {
    final workoutId = await prepareWorkout(completeSets: false);
    await pumpTodayPage(tester);

    await tester.tap(find.text('Завершить тренировку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Завершить'));
    await tester.pumpAndSettle();

    final workout = await (db.select(
      db.workouts,
    )..where((w) => w.id.equals(workoutId))).getSingle();
    expect(workout.finishedAt, isNotNull);
  });

  testWidgets('не показывает предупреждение, когда все подходы выполнены', (
    tester,
  ) async {
    final workoutId = await prepareWorkout(completeSets: true);
    await pumpTodayPage(tester);

    await tester.tap(find.text('Завершить тренировку'));
    await tester.pumpAndSettle();

    expect(find.text('Есть невыполненные подходы'), findsNothing);
    final workout = await (db.select(
      db.workouts,
    )..where((w) => w.id.equals(workoutId))).getSingle();
    expect(workout.finishedAt, isNotNull);
  });

  testWidgets('кнопка завершения остается доступной при прокрутке списка', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await prepareWorkout(completeSets: false, exerciseCount: 12);
    await pumpTodayPage(tester);

    final finishButton = find.text('Завершить тренировку');
    await tester.scrollUntilVisible(
      finishButton,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finishButton);
    await tester.pumpAndSettle();

    expect(finishButton, findsOneWidget);
    await tester.tap(finishButton);
    await tester.pumpAndSettle();
    expect(find.text('Есть невыполненные подходы'), findsOneWidget);
  });

  testWidgets('редактор упражнения ограничен по высоте и прокручивается', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await prepareWorkout(completeSets: false);
    final entry = (await db.select(db.workoutExercises).get()).single;
    for (var i = 0; i < 20; i++) {
      await workouts.addSet(entry.id, reps: 10);
    }
    final exercise = (await db.select(db.exercises).get()).first;
    await pumpTodayPage(tester);

    await tester.tap(find.text(exercise.name));
    await tester.pumpAndSettle();

    final bottomSheet = find.byType(BottomSheet);
    expect(tester.getSize(bottomSheet).height, lessThan(620));

    final removeButton = find.text('Убрать из тренировки');
    await tester.scrollUntilVisible(
      removeButton,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(removeButton, findsOneWidget);
  });

  testWidgets('надпись о завершении прокручивается вместе с содержимым', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final workoutId = await prepareWorkout(
      completeSets: false,
      exerciseCount: 12,
    );
    await workouts.finishWorkout(workoutId);
    await pumpTodayPage(tester);

    final finishedLabel = find.text('Тренировка завершена ✓');
    await tester.scrollUntilVisible(
      finishedLabel,
      120,
      scrollable: find.byType(Scrollable).first,
    );

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, greaterThan(0));
    expect(finishedLabel, findsOneWidget);
  });
}
