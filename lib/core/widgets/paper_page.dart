import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Страница тетради: бумага, линейка, красное поле, тень у переплёта.
/// Растягивается на всё доступное место.
class PaperPage extends StatelessWidget {
  const PaperPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(66, 14, 16, 12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary пригодится на этапе 2, когда страницы будут листаться.
    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: const PaperPainter(),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class PaperPainter extends CustomPainter {
  const PaperPainter({
    this.lineSpacing = 28,
    this.firstLineY = 40,
    this.marginX = 54,
  });

  final double lineSpacing;
  final double firstLineY;
  final double marginX;

  @override
  void paint(Canvas canvas, Size size) {
    // бумага
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.paper);

    // линейка
    final rule = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1.2;
    for (var y = firstLineY; y < size.height; y += lineSpacing) {
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
      old.lineSpacing != lineSpacing ||
      old.firstLineY != firstLineY ||
      old.marginX != marginX;
}
