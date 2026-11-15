import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/program_repository.dart';

final programRepositoryProvider = Provider<ProgramRepository>(
  (ref) => ProgramRepository(ref.watch(appDatabaseProvider)),
);

final programsProvider = StreamProvider<List<ProgramDetails>>((ref) {
  return ref.watch(programRepositoryProvider).watchAll();
});
