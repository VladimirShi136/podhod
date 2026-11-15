import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/progress_repository.dart';
import 'progress_logic.dart';

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(appDatabaseProvider)),
);

final progressProvider = StreamProvider<ProgressData>((ref) {
  return ref.watch(progressRepositoryProvider).watchRows().map(buildProgress);
});
