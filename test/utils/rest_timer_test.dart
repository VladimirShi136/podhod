import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/features/today/rest_timer.dart';

void main() {
  test('таймер отдыха: старт, добавление времени, остановка', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    expect(c.read(restTimerProvider), isNull);
    c.read(restTimerProvider.notifier).start(60);
    final s = c.read(restTimerProvider)!;
    expect(s.total, 60);
    expect(s.remaining(DateTime.now()).inSeconds, inInclusiveRange(58, 60));

    c.read(restTimerProvider.notifier).adjust(15);
    expect(c.read(restTimerProvider)!.total, 75);

    c.read(restTimerProvider.notifier).adjust(-600);
    expect(c.read(restTimerProvider), isNull);
  });

  test('formatCountdown', () {
    expect(formatCountdown(const Duration(seconds: 65)), '1:05');
    expect(formatCountdown(const Duration(milliseconds: 500)), '0:01');
    expect(formatCountdown(Duration.zero), '0:00');
    expect(formatCountdown(const Duration(seconds: -3)), '0:00');
  });
}
