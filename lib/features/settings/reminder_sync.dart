import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/day_key.dart';
import '../today/today_providers.dart';
import 'app_settings.dart';
import 'notification_service.dart';
import 'reminder_plan.dart';

/// Держит расписание напоминаний в соответствии с настройками и историей.
/// Следите за ним из корня приложения: ref.watch(reminderSyncProvider).
final reminderSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(settingsProvider);
  final activeDays = ref.watch(activeDaysProvider).value;
  final service = ref.read(notificationServiceProvider);

  if (!settings.remindersEnabled) {
    service.cancelReminders();
    return;
  }
  if (activeDays == null) return; // ждём загрузки истории

  final now = DateTime.now();
  service.replaceAll(
    planReminders(
      now: now,
      minutes: settings.reminderMinutes,
      weekdays: settings.reminderWeekdays,
      trainedToday: activeDays.contains(dayKey(now)),
    ),
  );
});
