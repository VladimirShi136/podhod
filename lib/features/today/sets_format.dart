import '../../data/db/database.dart';
import '../../data/db/enums.dart';
import '../../data/repositories/models.dart';

/// Значение подхода: секунды для упражнений на время, иначе повторения.
int? setValue(WorkoutSet s, ExerciseKind kind) =>
    kind == ExerciseKind.time ? s.seconds : s.reps;

/// «4×15», «3×60с» или «15·14·12», если подходы разные.
String setsSummary(List<WorkoutSet> sets, ExerciseKind kind) {
  if (sets.isEmpty) return '—';
  final unit = kind == ExerciseKind.time ? 'с' : '';
  final values = [for (final s in sets) setValue(s, kind) ?? 0];
  if (values.every((v) => v == values.first)) {
    return '${values.length}×${values.first}$unit';
  }
  return '${values.join('·')}$unit';
}

/// Рекорд: лучший выполненный подход сегодня больше прежнего рекорда.
/// Если раньше упражнение не делали, рекордом не считаем.
bool isRecord(
  List<WorkoutSet> sets,
  ExerciseKind kind,
  PersonalBest? before,
) {
  if (before == null) return false;
  final previous = kind == ExerciseKind.time ? before.seconds : before.reps;
  if (previous == null) return false;
  var best = 0;
  for (final s in sets) {
    if (!s.done) continue;
    final v = setValue(s, kind) ?? 0;
    if (v > best) best = v;
  }
  return best > previous;
}

/// Текст рекорда для подсказки («20» или «60 с»).
String? bestText(PersonalBest? best, ExerciseKind kind) {
  if (best == null) return null;
  if (kind == ExerciseKind.time) {
    return best.seconds == null ? null : '${best.seconds} с';
  }
  return best.reps == null ? null : '${best.reps}';
}
