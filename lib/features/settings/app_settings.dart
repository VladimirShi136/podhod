import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rest_sound.dart';

/// Настройки приложения.
class AppSettings {
  const AppSettings({
    this.restSeconds = 60,
    this.remindersEnabled = false,
    this.reminderMinutes = 18 * 60 + 30,
    this.reminderWeekdays = const {1, 3, 5},
    this.restSoundEnabled = true,
    this.restSoundId = 'bell',
  });

  /// Отдых между подходами, секунды.
  final int restSeconds;

  final bool remindersEnabled;

  /// Время напоминания: минут от полуночи.
  final int reminderMinutes;

  /// Дни недели напоминаний: 1 — понедельник … 7 — воскресенье.
  final Set<int> reminderWeekdays;

  /// Звук сигнала окончания отдыха: включён ли и какой.
  final bool restSoundEnabled;
  final String restSoundId;

  RestSound get restSound => RestSound.fromId(restSoundId);

  /// Звук для уведомления; null, если звук выключен (останется вибрация).
  RestSound? get activeRestSound => restSoundEnabled ? restSound : null;

  AppSettings copyWith({
    int? restSeconds,
    bool? remindersEnabled,
    int? reminderMinutes,
    Set<int>? reminderWeekdays,
    bool? restSoundEnabled,
    String? restSoundId,
  }) =>
      AppSettings(
        restSeconds: restSeconds ?? this.restSeconds,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        reminderWeekdays: reminderWeekdays ?? this.reminderWeekdays,
        restSoundEnabled: restSoundEnabled ?? this.restSoundEnabled,
        restSoundId: restSoundId ?? this.restSoundId,
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
  static const _kSoundOn = 'rest_sound_enabled';
  static const _kSoundId = 'rest_sound_id';

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
      restSoundEnabled: prefs.getBool(_kSoundOn) ?? defaults.restSoundEnabled,
      restSoundId: prefs.getString(_kSoundId) ?? defaults.restSoundId,
    );
  }

  /// Настройки для резервной копии.
  Map<String, Object?> toJson() => {
        'restSeconds': restSeconds,
        'remindersEnabled': remindersEnabled,
        'reminderMinutes': reminderMinutes,
        'reminderWeekdays': (reminderWeekdays.toList()..sort()),
        'restSoundEnabled': restSoundEnabled,
        'restSoundId': restSoundId,
      };

  /// Читает настройки из копии; чего не хватает или что испорчено — остаётся
  /// как в [base].
  static AppSettings fromJson(Map<String, dynamic> json, AppSettings base) {
    final days = json['reminderWeekdays'];
    return base.copyWith(
      restSeconds: json['restSeconds'] is int
          ? (json['restSeconds'] as int).clamp(5, 3600)
          : null,
      remindersEnabled: json['remindersEnabled'] as bool?,
      reminderMinutes: json['reminderMinutes'] is int
          ? (json['reminderMinutes'] as int).clamp(0, 24 * 60 - 1)
          : null,
      reminderWeekdays: days is List
          ? {
              for (final d in days)
                if (d is int && d >= 1 && d <= 7) d,
            }
          : null,
      restSoundEnabled: json['restSoundEnabled'] as bool?,
      restSoundId: json['restSoundId'] is String
          ? RestSound.fromId(json['restSoundId'] as String).name
          : null,
    );
  }

  Future<void> saveTo(SharedPreferences prefs) async {
    await prefs.setInt(_kRest, restSeconds);
    await prefs.setBool(_kEnabled, remindersEnabled);
    await prefs.setInt(_kMinutes, reminderMinutes);
    final sorted = reminderWeekdays.toList()..sort();
    await prefs.setStringList(_kDays, [for (final d in sorted) '$d']);
    await prefs.setBool(_kSoundOn, restSoundEnabled);
    await prefs.setString(_kSoundId, restSoundId);
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

  void setRestSoundEnabled(bool enabled) =>
      _update(state.copyWith(restSoundEnabled: enabled));

  void setRestSound(RestSound sound) =>
      _update(state.copyWith(restSoundId: sound.name));

  /// Заменяет все настройки (восстановление из копии).
  void replaceAll(AppSettings next) => _update(next);

  void toggleWeekday(int weekday) {
    final days = {...state.reminderWeekdays};
    if (!days.remove(weekday)) days.add(weekday);
    _update(state.copyWith(reminderWeekdays: days));
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
