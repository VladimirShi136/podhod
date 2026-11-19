import '../../data/db/enums.dart';
import '../progress/progress_logic.dart';

/// Порог, после которого пора пробовать более сложный вариант:
/// 15 повторений в одном подходе или 60 секунд.
int readyThreshold(ExerciseKind kind) => kind == ExerciseKind.time ? 60 : 15;

/// Готов ли человек к более сложному варианту: лучший подход достиг порога.
bool readyForHarder(ExerciseProgress? progress) {
  if (progress == null) return false;
  return progress.bestValue >= readyThreshold(progress.kind);
}
