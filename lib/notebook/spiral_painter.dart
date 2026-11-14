import 'package:flutter/material.dart';

/// Металлическая спираль вдоль левого края тетради.
class SpiralPainter extends CustomPainter {
  const SpiralPainter();

  static const double _step = 34;
  static const double _ringWidth = 44;
  static const double _ringHeight = 12;

  @override
  void paint(Canvas canvas, Size size) {
    // тень от переплёта
    final strip = Rect.fromLTWH(0, 0, 34, size.height);
    canvas.drawRect(
      strip,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x33000000), Color(0x00000000)],
        ).createShader(strip),
    );

    final shadow = Paint()
      ..color = const Color(0x59000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);
    final hole = Paint()..color = const Color(0xCC2A2118);

    for (var y = 14.0; y < size.height - _ringHeight; y += _step) {
      final ring = RRect.fromRectAndRadius(
        Rect.fromLTWH(4, y, _ringWidth, _ringHeight),
        const Radius.circular(8),
      );

      canvas.drawRRect(ring.shift(const Offset(0, 2)), shadow);

      canvas.drawRRect(
        ring,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8E8EA), Color(0xFF8C8F98), Color(0xFFD8D9DE)],
            stops: [0, 0.55, 1],
          ).createShader(ring.outerRect),
      );

      // отверстие в бумаге, в которое уходит кольцо
      canvas.drawOval(
        Rect.fromCenter(center: Offset(7, y + _ringHeight / 2), width: 10, height: 8),
        hole,
      );
    }
  }

  @override
  bool shouldRepaint(SpiralPainter oldDelegate) => false;
}
