import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/day_key.dart';
import '../../data/providers.dart';
import '../../data/repositories/export_repository.dart';

final exportRepositoryProvider = Provider<ExportRepository>(
  (ref) => ExportRepository(ref.watch(appDatabaseProvider)),
);

enum ExportFormat { json, csv }

/// Собирает файл во временной папке и открывает системное окно «Поделиться»
/// (отправить в почту, мессенджер, сохранить на диск и т. д.).
Future<void> exportAndShare(WidgetRef ref, ExportFormat format) async {
  final data = await ref.read(exportRepositoryProvider).load();
  final text = format == ExportFormat.json ? buildJson(data) : buildCsv(data);
  final ext = format == ExportFormat.json ? 'json' : 'csv';

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/podhod-${dayKey(DateTime.now())}.$ext');
  await file.writeAsString(text);

  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: 'Подход: данные'),
  );
}
