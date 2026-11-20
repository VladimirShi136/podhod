import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/day_key.dart';
import '../../data/providers.dart';
import '../../data/repositories/export_repository.dart';
import 'app_settings.dart';

final exportRepositoryProvider = Provider<ExportRepository>(
  (ref) => ExportRepository(ref.watch(appDatabaseProvider)),
);

/// Открывает системный выбор файла и восстанавливает данные из копии.
/// Возвращает null, если выбор отменён.
Future<RestoreResult?> pickAndRestore(WidgetRef ref) async {
  final file = await openFile();
  if (file == null) return null;
  final text = await file.readAsString();
  final result = await ref.read(exportRepositoryProvider).restoreFromJson(text);
  final saved = result.settings;
  if (saved != null) {
    final notifier = ref.read(settingsProvider.notifier);
    notifier.replaceAll(AppSettings.fromJson(saved, ref.read(settingsProvider)));
  }
  return result;
}

enum ExportFormat { json, csv }

/// Собирает файл во временной папке и открывает системное окно «Поделиться»
/// (отправить в почту, мессенджер, сохранить на диск и т. д.).
Future<void> exportAndShare(WidgetRef ref, ExportFormat format) async {
  final data = await ref.read(exportRepositoryProvider).load();
  final text = format == ExportFormat.json ? buildJson(data, settings: ref.read(settingsProvider).toJson()) : buildCsv(data);
  final ext = format == ExportFormat.json ? 'json' : 'csv';

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/podhod-${dayKey(DateTime.now())}.$ext');
  await file.writeAsString(text);

  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: 'Подход: данные'),
  );
}
