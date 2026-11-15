import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/day_key.dart';
import '../../core/utils/streak.dart';
import '../../data/db/database.dart';
import '../../data/db/enums.dart';
import '../../data/providers.dart';
import '../../data/repositories/models.dart';

/// Какой день показывает страница «Сегодня». По умолчанию сегодняшний;
/// календарь (этап 6) сможет переключать на любой другой.
class SelectedDay extends Notifier<String> {
  bool _followsToday = true;

  @override
  String build() => dayKey(DateTime.now());

  void select(String day) {
    _followsToday = day == dayKey(DateTime.now());
    state = day;
  }

  /// Если приложение пролежало в фоне до следующего дня, переходим на новый день.
  void refreshToday() {
    if (!_followsToday) return;
    final today = dayKey(DateTime.now());
    if (state != today) state = today;
  }
}

final selectedDayProvider =
    NotifierProvider<SelectedDay, String>(SelectedDay.new);

/// Тренировка выбранного дня (null, если её ещё нет). Обновляется сама.
final workoutDayProvider = StreamProvider<WorkoutDetails?>((ref) {
  final day = ref.watch(selectedDayProvider);
  return ref.watch(workoutRepositoryProvider).watchDay(day);
});

/// Дни, в которые выполнен хотя бы один подход (новые первыми).
final activeDaysProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(workoutRepositoryProvider).watchActiveDays();
});

final streakProvider = Provider<int>((ref) {
  final days = ref.watch(activeDaysProvider).value ?? const <String>[];
  return currentStreak(days, DateTime.now());
});

final workoutNumberProvider = Provider<int>((ref) {
  final day = ref.watch(selectedDayProvider);
  final days = ref.watch(activeDaysProvider).value ?? const <String>[];
  return workoutNumber(days, day);
});

/// Подходы из прошлой тренировки с этим упражнением: (id упражнения, день).
final lastSetsProvider =
    FutureProvider.autoDispose.family<List<WorkoutSet>, (int, String)>(
  (ref, key) {
    return ref
        .watch(workoutRepositoryProvider)
        .lastSets(key.$1, beforeDay: key.$2);
  },
);

/// Лучший результат по упражнению до указанного дня: (id упражнения, день).
final bestBeforeProvider =
    FutureProvider.autoDispose.family<PersonalBest, (int, String)>(
  (ref, key) {
    return ref.watch(workoutRepositoryProvider).bestBefore(key.$1, key.$2);
  },
);

/// Каталог упражнений с фильтром по группе и поиском.
final exerciseCatalogProvider = StreamProvider.autoDispose
    .family<List<Exercise>, ({MuscleGroup? group, String query})>(
  (ref, filter) {
    return ref
        .watch(exerciseRepositoryProvider)
        .watchAll(group: filter.group, query: filter.query);
  },
);
