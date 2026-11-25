import 'package:flutter/material.dart';

import '../core/widgets/paper_lines.dart';

const double _ringWidth = 44;
const double _ringHeight = 12;
const double _firstLineY = 40;
const double _ringStep = 2 * kLine;
const double _firstRingY = _firstLineY + kLine - _ringHeight / 2 - kLine / 2;

/// Металлическая спираль вдоль левого края тетради.
class SpiralPainter extends CustomPainter {
  const SpiralPainter({this.scroll}) : super(repaint: scroll);

  final ScrollController? scroll;

  double get _offset {
    final controller = scroll;
    if (controller == null || controller.positions.length != 1) return 0;
    return controller.offset;
  }

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

    for (final y in spiralRingYs(height: size.height, scrollOffset: _offset)) {
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
        Rect.fromCenter(
          center: Offset(7, y + _ringHeight / 2),
          width: 10,
          height: 8,
        ),
        hole,
      );
    }
  }

  @override
  bool shouldRepaint(SpiralPainter oldDelegate) => oldDelegate.scroll != scroll;
}

/// Ring positions half a line above every second ruled line.
List<double> spiralRingYs({
  required double height,
  required double scrollOffset,
}) {
  var y = _firstRingY - scrollOffset;
  if (y + _ringHeight <= 0) {
    final skip = ((-y - _ringHeight) / _ringStep).ceil();
    y += skip * _ringStep;
  }

  final ys = <double>[];
  for (; y < height; y += _ringStep) {
    ys.add(y);
  }
  return ys;
}
