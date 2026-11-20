import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/core/utils/set_values.dart';

void main() {
  test('подпись подходов', () {
    expect(formatSetValues([10, 10, 10], isTime: false), '3×10');
    expect(formatSetValues([30, 30], isTime: true), '2×30с');
    expect(formatSetValues([6, 7, 10, 11, 8, 8], isTime: false), '6·7·10·11·8·8');
    expect(formatSetValues([40, 30], isTime: true), '40·30с');
    expect(formatSetValues([], isTime: false), '—');
  });

  test('кодирование и разбор', () {
    expect(encodeSetValues([6, 7, 10]), '6,7,10');
    expect(decodeSetValues('6,7,10'), [6, 7, 10]);
    expect(decodeSetValues(' 6, 7 '), [6, 7]);
    expect(decodeSetValues(null), isNull);
    expect(decodeSetValues(''), isNull);
    expect(decodeSetValues('6,x'), isNull);
    expect(decodeSetValues('0,5'), isNull);
  });
}
