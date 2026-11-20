import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';
import 'rest_sound.dart';

/// Вся работа с системными уведомлениями собрана здесь. Если плагин
/// изменит свой интерфейс, править нужно только этот файл.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool? _notificationsGranted;

  static const _reminderHorizonDays = 14;
  static const _restTimerId = 1000;

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'workout_reminders',
      'Напоминания о тренировках',
      channelDescription: 'Напоминание вовремя сделать тренировку',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Параметры уведомления об окончании отдыха. Звук канала в Android нельзя
  /// поменять после создания, поэтому у каждого звука свой канал.
  /// [sound] == null — без звука (останется вибрация).
  static NotificationDetails _restDetails(RestSound? sound) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        sound == null ? 'rest_timer_silent' : 'rest_timer_${sound.name}',
        sound == null ? 'Таймер отдыха (без звука)' : 'Таймер отдыха: ${sound.label}',
        channelDescription: 'Сигнал об окончании отдыха между подходами',
        importance: Importance.high,
        priority: Priority.high,
        playSound: sound != null,
        sound: sound == null
            ? null
            : RawResourceAndroidNotificationSound(sound.resource),
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: sound != null,
        presentBanner: true,
        presentList: true,
      ),
    );
  }

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Просит разрешение на уведомления. true — разрешено.
  Future<bool> requestPermission() async {
    try {
      await _init();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = android != null
          ? await android.requestNotificationsPermission() ?? true
          : await ios?.requestPermissions(alert: true, sound: true) ?? true;
      _notificationsGranted = granted;
      return granted;
    } catch (e) {
      _notificationsGranted = false;
      debugPrint('Разрешение на уведомления: $e');
      return false;
    }
  }

  Future<bool?> _notificationsEnabled() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) return await android.areNotificationsEnabled();

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return (await ios?.checkPermissions())?.isEnabled;
    } catch (e) {
      debugPrint('Не удалось проверить разрешение на уведомления: $e');
      return null;
    }
  }

  /// Заменяет все запланированные напоминания на [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    try {
      await _init();
      for (var id = 0; id < _reminderHorizonDays; id++) {
        await _plugin.cancel(id: id);
      }
      for (final r in reminders) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          // Абсолютный момент времени: берём его из локального DateTime,
          // поэтому часовой пояс определять отдельно не нужно.
          scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
          notificationDetails: _reminderDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Не удалось запланировать напоминания: $e');
    }
  }

  Future<void> cancelReminders() async {
    try {
      await _init();
      for (var id = 0; id < _reminderHorizonDays; id++) {
        await _plugin.cancel(id: id);
      }
    } catch (e) {
      debugPrint('Не удалось отменить напоминания: $e');
    }
  }

  Future<void> scheduleRestTimer(DateTime endsAt, RestSound? sound) async {
    try {
      await _init();
      final previouslyGranted = _notificationsGranted;
      final enabled = await _notificationsEnabled();
      if (enabled == true) {
        _notificationsGranted = true;
      } else if (enabled == false && previouslyGranted == null) {
        if (!await requestPermission()) return;
      } else if (enabled == false || _notificationsGranted != true) {
        _notificationsGranted = false;
        debugPrint('Уведомления отдыха отключены в настройках устройства');
        return;
      }
      await _plugin.zonedSchedule(
        id: _restTimerId,
        title: 'Отдых закончен',
        body: 'Пора к следующему подходу.',
        scheduledDate: tz.TZDateTime.from(endsAt, tz.UTC),
        notificationDetails: _restDetails(sound),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Не удалось запланировать окончание отдыха: $e');
    }
  }

  Future<void> cancelRestTimer() async {
    try {
      await _init();
      await _plugin.cancel(id: _restTimerId);
    } catch (e) {
      debugPrint('Не удалось отменить уведомление таймера отдыха: $e');
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
