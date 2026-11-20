import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/features/today/rest_timer.dart';
import 'package:podhod/features/settings/app_settings.dart';
import 'package:podhod/features/settings/notification_service.dart';
import 'package:podhod/features/settings/rest_sound.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends NotificationService {
  DateTime? scheduledFor;
  var cancelCount = 0;

  @override
  Future<void> scheduleRestTimer(DateTime endsAt, RestSound? sound) async {
    scheduledFor = endsAt;
  }

  @override
  Future<void> cancelRestTimer() async {
    cancelCount++;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('таймер отдыха: старт, добавление времени, остановка', () async {
    final notifications = _FakeNotificationService();
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(c.dispose);

    expect(c.read(restTimerProvider), isNull);
    c.read(restTimerProvider.notifier).start(60);
    final s = c.read(restTimerProvider)!;
    expect(s.total, 60);
    expect(s.remaining(DateTime.now()).inSeconds, inInclusiveRange(58, 60));
    expect(notifications.scheduledFor, s.endsAt);

    c.read(restTimerProvider.notifier).adjust(15);
    final adjusted = c.read(restTimerProvider)!;
    expect(adjusted.total, 75);
    expect(notifications.scheduledFor, adjusted.endsAt);

    c.read(restTimerProvider.notifier).adjust(-600);
    expect(c.read(restTimerProvider), isNull);
    expect(notifications.cancelCount, 1);
  });

  test(
    'не отменяет уведомление при окончании, но отменяет при ручной остановке',
    () async {
      final notifications = _FakeNotificationService();
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWithValue(notifications),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(c.dispose);

      final timer = c.read(restTimerProvider.notifier);
      timer.start(60);
      timer.markFired();
      expect(notifications.cancelCount, 0);

      timer.stop(cancelNotification: false);
      expect(notifications.cancelCount, 0);
      timer.start(60);
      timer.stop();
      expect(notifications.cancelCount, 1);
    },
  );

  test('formatCountdown', () {
    expect(formatCountdown(const Duration(seconds: 65)), '1:05');
    expect(formatCountdown(const Duration(milliseconds: 500)), '0:01');
    expect(formatCountdown(Duration.zero), '0:00');
    expect(formatCountdown(const Duration(seconds: -3)), '0:00');
  });
}
