import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/notebook/spiral_painter.dart';

void main() {
  group('spiralRingYs', () {
    test('starts half a line above the second rule and skips one line', () {
      expect(spiralRingYs(height: 180, scrollOffset: 0), [48, 104, 160]);
    });

    test('rings follow the page scroll, including overscroll', () {
      expect(spiralRingYs(height: 150, scrollOffset: 10), [38, 94]);
      expect(spiralRingYs(height: 150, scrollOffset: -10), [58, 114]);
    });

    test('skips rings already above the viewport', () {
      expect(spiralRingYs(height: 120, scrollOffset: 200), [16, 72]);
    });
  });
}
