import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Страница тетради: бумага, линейка, красное поле, тень у переплёта.
/// Растягивается на всё доступное место.
///
/// Линейка едет вместе с содержимым: страница отдаёт своей прокрутке общий
/// контроллер (через PrimaryScrollController), а рисунок линий следит за его
/// смещением. Поэтому любой вертикальный список или SingleChildScrollView
/// внутри страницы листается «вместе с бумагой» без дополнительного кода.
/// Красное поле, тень и спираль остаются на месте как часть переплёта.
class PaperPage extends StatefulWidget {
  const PaperPage({
    super.key,
    required this.child,
    // Верх 12: первая линия (y = 40) приходится на 28 px от начала содержимого,
    // поэтому блоки высотой кратной 28 лежат ровно между линиями.
    this.padding = const EdgeInsets.fromLTRB(66, 12, 16, 12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  State<PaperPage> createState() => PaperPageState();
}

class PaperPageState extends State<PaperPage> {
  final ScrollController _scroll = ScrollController();

  /// Насколько содержимое страницы прокручено вверх (для тестов).
  @visibleForTesting
  double get scrollOffset =>
      _scroll.positions.length == 1 ? _scroll.offset : 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: PaperPainter(scroll: _scroll),
          child: PrimaryScrollController(
            controller: _scroll,
            // на любой платформе, не только на телефонах
            automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
            child: ScrollConfiguration(
              behavior: const PaperScrollBehavior(),
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Прокрутка страницы тетради: у края лист слегка «пружинит» (как на iOS),
/// а не растягивается. Растяжка Android 12+ тянет только картинку содержимого,
/// не меняя смещения, поэтому линейка оставалась бы на месте. С пружинной
/// физикой смещение реально выходит за край, и линейка движется вместе с
/// текстом.
class PaperScrollBehavior extends MaterialScrollBehavior {
  const PaperScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

/// Вертикальные позиции линий в окне высотой [height] при прокрутке
/// содержимого на [scrollOffset]. Первая линия лежит на [firstLineY] и уезжает
/// вверх вместе с содержимым; выше неё линий нет, пока страница не прокручена.
List<double> ruleLineYs({
  required double height,
  required double scrollOffset,
  double firstLineY = 40,
  double lineSpacing = 28,
}) {
  final ys = <double>[];
  var y = firstLineY - scrollOffset;
  if (y < 0) {
    // пропускаем строки, которые уже уехали за верхний край
    final skip = (-y / lineSpacing).ceil();
    y += skip * lineSpacing;
  }
  for (; y < height; y += lineSpacing) {
    ys.add(y);
  }
  return ys;
}

class PaperPainter extends CustomPainter {
  PaperPainter({
    this.scroll,
    this.lineSpacing = 28,
    this.firstLineY = 40,
    this.marginX = 54,
  }) : super(repaint: scroll);

  final ScrollController? scroll;
  final double lineSpacing;
  final double firstLineY;
  final double marginX;

  double get _offset {
    final s = scroll;
    if (s == null || s.positions.length != 1) return 0;
    return s.offset;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // бумага
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.paper);

    // линейка (едет вместе с содержимым)
    final rule = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1.2;
    for (final y in ruleLineYs(
      height: size.height,
      scrollOffset: _offset,
      firstLineY: firstLineY,
      lineSpacing: lineSpacing,
    )) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }

    // красное поле
    canvas.drawLine(
      Offset(marginX, 0),
      Offset(marginX, size.height),
      Paint()
        ..color = AppColors.margin
        ..strokeWidth = 1.4,
    );

    // тень у переплёта (слева)
    final shadowRect = Rect.fromLTWH(0, 0, 14, size.height);
    canvas.drawRect(
      shadowRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x40000000), Color(0x00000000)],
        ).createShader(shadowRect),
    );
  }

  @override
  bool shouldRepaint(PaperPainter old) =>
      old.scroll != scroll ||
      old.lineSpacing != lineSpacing ||
      old.firstLineY != firstLineY ||
      old.marginX != marginX;
}
