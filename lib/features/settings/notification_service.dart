import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';

/// Вся работа с системными уведомлениями собрана здесь. Если плагин
/// изменит свой интерфейс, править нужно только этот файл.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'workout_reminders',
      'Напоминания о тренировках',
      channelDescription: 'Напоминание вовремя сделать тренировку',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Просит разрешение на уведомления (Android 13+). true — разрешено.
  Future<bool> requestPermission() async {
    try {
      await _init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (e) {
      debugPrint('Разрешение на уведомления: $e');
      return false;
    }
  }

  /// Заменяет все запланированные напоминания на [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    try {
      await _init();
      await _plugin.cancelAll();
      for (final r in reminders) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          // Абсолютный момент времени: берём его из локального DateTime,
          // поэтому часовой пояс определять отдельно не нужно.
          scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Не удалось запланировать напоминания: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _init();
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Не удалось отменить напоминания: $e');
    }
  }
}
