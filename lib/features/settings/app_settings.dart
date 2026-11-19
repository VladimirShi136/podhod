import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Настройки приложения.
class AppSettings {
  const AppSettings({
    this.restSeconds = 60,
    this.remindersEnabled = false,
    this.reminderMinutes = 18 * 60 + 30,
    this.reminderWeekdays = const {1, 3, 5},
  });

  /// Отдых между подходами, секунды.
  final int restSeconds;

  final bool remindersEnabled;

  /// Время напоминания: минут от полуночи.
  final int reminderMinutes;

  /// Дни недели напоминаний: 1 — понедельник … 7 — воскресенье.
  final Set<int> reminderWeekdays;

  AppSettings copyWith({
    int? restSeconds,
    bool? remindersEnabled,
    int? reminderMinutes,
    Set<int>? reminderWeekdays,
  }) =>
      AppSettings(
        restSeconds: restSeconds ?? this.restSeconds,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        reminderWeekdays: reminderWeekdays ?? this.reminderWeekdays,
      );

  String get reminderTimeText {
    final h = (reminderMinutes ~/ 60).toString().padLeft(2, '0');
    final m = (reminderMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static const _kRest = 'rest_seconds';
  static const _kEnabled = 'reminders_enabled';
  static const _kMinutes = 'reminder_minutes';
  static const _kDays = 'reminder_weekdays';

  factory AppSettings.fromPrefs(SharedPreferences prefs) {
    const defaults = AppSettings();
    final days = prefs.getStringList(_kDays);
    return AppSettings(
      restSeconds: prefs.getInt(_kRest) ?? defaults.restSeconds,
      remindersEnabled: prefs.getBool(_kEnabled) ?? defaults.remindersEnabled,
      reminderMinutes: prefs.getInt(_kMinutes) ?? defaults.reminderMinutes,
      reminderWeekdays: days == null
          ? defaults.reminderWeekdays
          : {
              for (final d in days)
                if (int.tryParse(d) case final n? when n >= 1 && n <= 7) n,
            },
    );
  }

  Future<void> saveTo(SharedPreferences prefs) async {
    await prefs.setInt(_kRest, restSeconds);
    await prefs.setBool(_kEnabled, remindersEnabled);
    await prefs.setInt(_kMinutes, reminderMinutes);
    final sorted = reminderWeekdays.toList()..sort();
    await prefs.setStringList(_kDays, [for (final d in sorted) '$d']);
  }
}

/// Хранилище настроек. Значение подставляется в main() при запуске.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider не задан'),
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() =>
      AppSettings.fromPrefs(ref.watch(sharedPreferencesProvider));

  void _update(AppSettings next) {
    state = next;
    next.saveTo(ref.read(sharedPreferencesProvider));
  }

  void setRestSeconds(int seconds) =>
      _update(state.copyWith(restSeconds: seconds));

  void setRemindersEnabled(bool enabled) =>
      _update(state.copyWith(remindersEnabled: enabled));

  void setReminderMinutes(int minutes) =>
      _update(state.copyWith(reminderMinutes: minutes.clamp(0, 24 * 60 - 1)));

  void toggleWeekday(int weekday) {
    final days = {...state.reminderWeekdays};
    if (!days.remove(weekday)) days.add(weekday);
    _update(state.copyWith(reminderWeekdays: days));
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
