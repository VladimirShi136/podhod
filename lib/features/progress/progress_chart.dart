import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Одна точка графика: подпись по оси X и значение.
class ChartPoint {
  const ChartPoint(this.label, this.value);

  final String label;
  final int value;
}

/// Простой график «от руки»: ломаная чернилами, точки, красный рекорд.
class ProgressChart extends StatelessWidget {
  const ProgressChart({super.key, required this.points, this.height = 180});

  final List<ChartPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _ChartPainter(points)),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points);

  final List<ChartPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const left = 34.0, right = 10.0, top = 10.0, bottom = 26.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);

    final realMax = points.map((p) => p.value).reduce(math.max);
    var maxV = realMax;
    var minV = points.map((p) => p.value).reduce(math.min);
    if (maxV == minV) {
      // одна точка или ровная линия: даём воздух сверху и снизу
      maxV += 1;
      minV = math.max(0, minV - 1);
    }
    final span = (maxV - minV).toDouble();

    Offset at(int i) {
      final x = points.length == 1
          ? plot.center.dx
          : plot.left + plot.width * i / (points.length - 1);
      final y = plot.bottom - plot.height * (points[i].value - minV) / span;
      return Offset(x, y);
    }

    // сетка
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1.2;
    for (var i = 0; i <= 3; i++) {
      final y = plot.top + plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }

    // подписи по оси Y
    _text(canvas, '$maxV', Offset(0, plot.top - 8), 13, align: _Align.left);
    _text(canvas, '$minV', Offset(0, plot.bottom - 8), 13, align: _Align.left);

    // линия
    if (points.length > 1) {
      final path = Path()..moveTo(at(0).dx, at(0).dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(at(i).dx, at(i).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // точки; рекорд (первый максимум) красный и крупнее
    final recordIndex = points.indexWhere((p) => p.value == realMax);
    for (var i = 0; i < points.length; i++) {
      final isRecord = i == recordIndex && points.length > 1;
      canvas.drawCircle(
        at(i),
        isRecord ? 6 : 4,
        Paint()..color = isRecord ? AppColors.red : AppColors.ink,
      );
    }

    // подписи по оси X: первая и последняя
    _text(canvas, points.first.label, Offset(plot.left, size.height - 20), 13,
        align: _Align.left);
    if (points.length > 1) {
      _text(canvas, points.last.label, Offset(plot.right, size.height - 20), 13,
          align: _Align.right);
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor,
    double size, {
    required _Align align,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppText.body(size, color: AppColors.ink.withValues(alpha: 0.7)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == _Align.right ? anchor.dx - tp.width : anchor.dx;
    tp.paint(canvas, Offset(dx, anchor.dy));
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.points != points;
}

enum _Align { left, right }
