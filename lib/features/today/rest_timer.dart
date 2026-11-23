import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/paper_lines.dart';
import '../../core/utils/day_key.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../settings/app_settings.dart';
import '../settings/notification_service.dart';
import '../settings/sound_player.dart';

/// Допустимые значения отдыха по умолчанию, секунды.
const restPresets = [30, 60, 90, 120, 180];

/// Сколько секунд отдыха запускать после выполненного подхода.
/// Значение хранится в настройках и переживает перезапуск приложения.
class RestDuration extends Notifier<int> {
  @override
  int build() => ref.watch(settingsProvider).restSeconds;

  void set(int seconds) =>
      ref.read(settingsProvider.notifier).setRestSeconds(seconds);
}

final restDurationProvider = NotifierProvider<RestDuration, int>(
  RestDuration.new,
);

/// Идущий отдых. Хранится время окончания, а не «осталось N секунд»,
/// поэтому после сворачивания приложения отсчёт остаётся верным.
class RestState {
  const RestState({
    required this.endsAt,
    required this.total,
    this.fired = false,
  });

  final DateTime endsAt;

  /// Полная длительность в секундах (для полоски прогресса).
  final int total;

  /// Сигнал об окончании уже подан.
  final bool fired;

  RestState copyWith({DateTime? endsAt, int? total, bool? fired}) => RestState(
    endsAt: endsAt ?? this.endsAt,
    total: total ?? this.total,
    fired: fired ?? this.fired,
  );

  Duration remaining(DateTime now) => endsAt.difference(now);
}

/// Приложение сейчас на экране? В тестах без привязки к движку — нет.
bool _appInForeground() {
  try {
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  } catch (_) {
    return false;
  }
}

class RestTimer extends Notifier<RestState?> with WidgetsBindingObserver {
  @override
  RestState? build() {
    try {
      WidgetsBinding.instance.addObserver(this);
      ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    } catch (_) {
      // нет привязки к движку (юнит-тесты)
    }
    return null;
  }

  /// Пока приложение открыто, сигнал подаёт оно само (звук без уведомления
  /// в шторке). Уведомление нужно, только когда приложение свёрнуто.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final s = state;
    if (s == null) return;
    final notifications = ref.read(notificationServiceProvider);
    switch (lifecycle) {
      case AppLifecycleState.resumed:
        unawaited(notifications.cancelRestTimer());
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (!s.fired && s.endsAt.isAfter(DateTime.now())) {
          unawaited(
            notifications.scheduleRestTimer(
              s.endsAt,
              ref.read(settingsProvider).activeRestSound,
            ),
          );
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _scheduleIfBackground(DateTime endsAt) {
    if (_appInForeground()) return;
    unawaited(
      ref.read(notificationServiceProvider).scheduleRestTimer(
            endsAt,
            ref.read(settingsProvider).activeRestSound,
          ),
    );
  }

  void start(int seconds) {
    final rest = RestState(
      endsAt: DateTime.now().add(Duration(seconds: seconds)),
      total: seconds,
    );
    state = rest;
    _scheduleIfBackground(rest.endsAt);
  }

  /// Добавляет или убирает секунды. Если время вышло, отдых завершается.
  void adjust(int deltaSeconds) {
    final s = state;
    if (s == null) return;
    final newEnd = s.endsAt.add(Duration(seconds: deltaSeconds));
    if (!newEnd.isAfter(DateTime.now())) {
      stop();
      return;
    }
    final adjusted = s.copyWith(
      endsAt: newEnd,
      total: (s.total + deltaSeconds).clamp(1, 3600),
      fired: false,
    );
    state = adjusted;
    _scheduleIfBackground(adjusted.endsAt);
  }

  void markFired() {
    final s = state;
    if (s != null && !s.fired) state = s.copyWith(fired: true);
  }

  void stop({bool cancelNotification = true}) {
    state = null;
    if (cancelNotification) {
      unawaited(ref.read(notificationServiceProvider).cancelRestTimer());
    }
  }
}

final restTimerProvider = NotifierProvider<RestTimer, RestState?>(
  RestTimer.new,
);

/// Переключает подход и, если он стал выполненным сегодня, запускает отдых.
Future<void> toggleSetWithRest(
  WidgetRef ref,
  WorkoutSet set,
  String day,
) async {
  await ref.read(workoutRepositoryProvider).toggleSet(set.id);
  final becameDone = !set.done;
  if (becameDone && day == dayKey(DateTime.now())) {
    ref.read(restTimerProvider.notifier).start(ref.read(restDurationProvider));
  }
}

String formatCountdown(Duration d) {
  final total = d.inMilliseconds <= 0 ? 0 : (d.inMilliseconds / 1000).ceil();
  final m = total ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Полоска таймера отдыха над нижней кнопкой страницы «Сегодня».
class RestTimerBar extends ConsumerStatefulWidget {
  const RestTimerBar({super.key, this.snapToLines = false});

  /// На странице-тетради высота округляется до целого числа строк.
  final bool snapToLines;

  @override
  ConsumerState<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends ConsumerState<RestTimerBar> {
  Timer? _ticker;

  /// Сколько секунд после окончания держим надпись «Отдых закончен».
  static const _lingerSeconds = 6;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    final s = ref.read(restTimerProvider);
    if (s == null) return;
    final now = DateTime.now();
    final left = s.remaining(now);
    if (left <= Duration.zero) {
      if (!s.fired) {
        ref.read(restTimerProvider.notifier).markFired();
        // Сигналим, только если закончилось только что, а не пока приложение
        // было свёрнуто.
        if (-left.inSeconds <= 3) unawaited(_signal());
      }
      if (-left.inSeconds >= _lingerSeconds) {
        ref.read(restTimerProvider.notifier).stop(cancelNotification: false);
        return;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _signal() async {
    // Приложение открыто: звук играем сами, без уведомления в шторке.
    final sound = ref.read(settingsProvider).activeRestSound;
    if (sound != null) unawaited(ref.read(soundPlayerProvider).play(sound));
    for (var i = 0; i < 3; i++) {
      HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(restTimerProvider);
    if (s == null) return const SizedBox.shrink();

    final left = s.remaining(DateTime.now());
    final finished = left <= Duration.zero;
    final progress = finished
        ? 1.0
        : (1 - left.inMilliseconds / (s.total * 1000)).clamp(0.0, 1.0);
    final notifier = ref.read(restTimerProvider.notifier);
    final duration = ref.watch(restDurationProvider);

    final bar = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: finished ? AppColors.accent : AppColors.sticker,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(5),
          bottomRight: Radius.circular(14),
          bottomLeft: Radius.circular(6),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  finished ? 'Отдых закончен — на подход!' : 'Отдых',
                  style: AppText.body(16),
                ),
              ),
              if (!finished)
                Text(formatCountdown(left), style: AppText.hand(36)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.paper,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              if (!finished) ...[
                _MiniButton('−15 с', () => notifier.adjust(-15)),
                _MiniButton('+15 с', () => notifier.adjust(15)),
              ],
              _MiniButton('$duration с по умолч.', () => _pickDefault(context)),
              _MiniButton(finished ? 'Закрыть' : 'Пропустить', notifier.stop),
            ],
          ),
        ],
      ),
    );
    return widget.snapToLines ? LineSnap(child: bar) : bar;
  }

  Future<void> _pickDefault(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Отдых между подходами', style: AppText.hand(30)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in restPresets)
                    ChoiceChip(
                      label: Text(
                        p >= 60 && p % 60 == 0 ? '${p ~/ 60} мин' : '$p с',
                        style: AppText.body(17),
                      ),
                      selected: p == ref.read(restDurationProvider),
                      selectedColor: AppColors.accent,
                      onSelected: (_) => Navigator.of(ctx).pop(p),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) ref.read(restDurationProvider.notifier).set(picked);
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(
          label,
          style: AppText.body(15).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: AppColors.ink,
          ),
        ),
      ),
    );
  }
}
