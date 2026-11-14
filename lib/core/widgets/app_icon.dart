import 'package:flutter/material.dart';

/// Иконка приложения, нарисованная кодом (те же координаты, что в app-icon.svg).
/// Используется на обложке; PNG для лаунчера лежат в assets/icon/.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.size, this.radius = 0});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: AppIconPainter()),
      ),
    );
  }
}

class AppIconPainter extends CustomPainter {
  const AppIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 512, size.height / 512);

    // бумага
    final full = Rect.fromLTWH(0, 0, 512, 512);
    canvas.drawRect(
      full,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.5),
          radius: 0.9,
          colors: [Color(0xFFFFFDF4), Color(0xFFF1E8CF)],
        ).createShader(full),
    );

    // линейка
    final rule = Paint()
      ..color = const Color(0xFFCFE0EE)
      ..strokeWidth = 4;
    for (var y = 64.0; y <= 448; y += 64) {
      canvas.drawLine(Offset(0, y), Offset(512, y), rule);
    }

    // поле
    canvas.drawLine(
      const Offset(84, 0),
      const Offset(84, 512),
      Paint()
        ..color = const Color(0xFFE8A3A3)
        ..strokeWidth = 5,
    );

    // «пятёрка»: четыре палочки
    final ink = Paint()
      ..color = const Color(0xFF2B3A67)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(168, 112), const Offset(172, 400), ink);
    canvas.drawLine(const Offset(236, 106), const Offset(238, 404), ink);
    canvas.drawLine(const Offset(304, 112), const Offset(301, 400), ink);
    canvas.drawLine(const Offset(372, 108), const Offset(375, 396), ink);

    // косая красная черта
    final red = Paint()
      ..color = const Color(0xFFC0392B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(128, 376)
        ..cubicTo(206, 330, 300, 240, 392, 130),
      red,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(AppIconPainter oldDelegate) => false;
}
