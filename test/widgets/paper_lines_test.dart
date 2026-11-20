import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podhod/core/widgets/paper_lines.dart';

Widget host(Widget child, {double textScale = 1, double width = 300}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  group('LineSnap', () {
    Future<double> heightOf(WidgetTester tester, double childHeight,
        {int minLines = 1}) async {
      await tester.pumpWidget(host(
        LineSnap(
          minLines: minLines,
          child: SizedBox(key: const Key('c'), height: childHeight),
        ),
      ));
      return tester.getSize(find.byType(LineSnap)).height;
    }

    testWidgets('округляет вверх до целого числа строк', (tester) async {
      expect(await heightOf(tester, 10), 28);
      expect(await heightOf(tester, 28), 28);
      expect(await heightOf(tester, 29), 56);
      expect(await heightOf(tester, 57), 84);
    });

    testWidgets('учитывает минимум строк', (tester) async {
      expect(await heightOf(tester, 10, minLines: 2), 56);
      expect(await heightOf(tester, 60, minLines: 2), 84);
    });

    testWidgets('центрирует содержимое', (tester) async {
      await tester.pumpWidget(host(
        const LineSnap(
          minLines: 2,
          child: SizedBox(key: Key('c'), height: 20),
        ),
      ));
      final top = tester.getTopLeft(find.byKey(const Key('c'))).dy;
      expect(top, 18);
    });
  });

  group('LineText', () {
    const style = TextStyle(fontSize: 19);

    testWidgets('каждая строка занимает ровно одну строку тетради',
        (tester) async {
      await tester.pumpWidget(host(const LineText('Коротко', style: style)));
      expect(tester.getSize(find.byType(LineText)).height, 28);

      await tester.pumpWidget(host(
        const LineText('Очень длинный текст который точно не влезет', style: style),
        width: 120,
      ));
      final lines = tester.getSize(find.byType(LineText)).height / 28;
      expect(lines, greaterThan(1));
      expect(lines, lines.roundToDouble());
    });

    testWidgets('крупный системный шрифт не меняет высоту строки',
        (tester) async {
      await tester.pumpWidget(
        host(const LineText('Коротко', style: style), textScale: 2),
      );
      expect(tester.getSize(find.byType(LineText)).height, 28);
    });
  });
}
