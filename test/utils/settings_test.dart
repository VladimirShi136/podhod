import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/features/settings/app_settings.dart';
import 'package:podhod/features/today/rest_timer.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> makeContainer(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('значения по умолчанию', () async {
    final c = await makeContainer({});
    final s = c.read(settingsProvider);
    expect(s.restSeconds, 60);
    expect(s.remindersEnabled, isFalse);
    expect(s.reminderTimeText, '18:30');
    expect(s.reminderWeekdays, {1, 3, 5});
  });

  test('настройки сохраняются и читаются после «перезапуска»', () async {
    final c = await makeContainer({});
    final n = c.read(settingsProvider.notifier);
    n.setRestSeconds(90);
    n.setRemindersEnabled(true);
    n.setReminderMinutes(7 * 60 + 5);
    n.toggleWeekday(1); // убрали понедельник
    n.toggleWeekday(6); // добавили субботу
    await Future<void>.delayed(Duration.zero);

    final prefs = c.read(sharedPreferencesProvider);
    final restored = AppSettings.fromPrefs(prefs);
    expect(restored.restSeconds, 90);
    expect(restored.remindersEnabled, isTrue);
    expect(restored.reminderTimeText, '07:05');
    expect(restored.reminderWeekdays, {3, 5, 6});
  });

  test('отдых по умолчанию берётся из настроек', () async {
    final c = await makeContainer({'rest_seconds': 120});
    expect(c.read(restDurationProvider), 120);
    c.read(restDurationProvider.notifier).set(30);
    expect(c.read(settingsProvider).restSeconds, 30);
    expect(c.read(restDurationProvider), 30);
  });
}
