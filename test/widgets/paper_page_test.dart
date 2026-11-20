import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/core/widgets/paper_page.dart';

void main() {
  group('ruleLineYs', () {
    test('без прокрутки линии как раньше: с 40 пикселей через 28', () {
      final ys = ruleLineYs(height: 140, scrollOffset: 0);
      expect(ys, [40, 68, 96, 124]);
    });

    test('при прокрутке линии едут вверх вместе с содержимым', () {
      expect(ruleLineYs(height: 100, scrollOffset: 10), [30, 58, 86]);
    });

    test('линия, ушедшая за верхний край, заменяется следующей', () {
      // на 40 пикселей вверх первая линия на нуле, дальше через 28
      expect(ruleLineYs(height: 60, scrollOffset: 40), [0, 28, 56]);
      // на 50: первая линия на -10 уехала, следующая на 18
      expect(ruleLineYs(height: 60, scrollOffset: 50), [18, 46]);
      // на ровно целое число строк рисунок повторяется
      expect(ruleLineYs(height: 100, scrollOffset: 68),
          ruleLineYs(height: 100, scrollOffset: 40));
    });

    test('растяжка вниз (отрицательное смещение) сдвигает линии вниз', () {
      expect(ruleLineYs(height: 100, scrollOffset: -10), [50, 78]);
    });
  });

  testWidgets('прокрутка внутри страницы передаётся линейке', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PaperPage(
          child: SingleChildScrollView(child: SizedBox(height: 2000)),
        ),
      ),
    );
    final state = tester.state<PaperPageState>(find.byType(PaperPage));
    expect(state.scrollOffset, 0);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -120));
    await tester.pump();
    expect(state.scrollOffset, greaterThan(0));
  });

  testWidgets('у верхнего края смещение уходит в минус, линейка следует за ним',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PaperPage(
          child: SingleChildScrollView(child: SizedBox(height: 2000)),
        ),
      ),
    );
    final state = tester.state<PaperPageState>(find.byType(PaperPage));

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(PaperPage)));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    expect(state.scrollOffset, lessThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.scrollOffset, 0);
  });
}
