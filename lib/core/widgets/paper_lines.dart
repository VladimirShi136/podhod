import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Шаг линейки тетради, пикселей.
const double kLine = 28;

/// Текст, каждая строка которого занимает ровно одну строку тетради (28 px),
/// поэтому он «стоит на линии» и при переносе на вторую строку.
///
/// Системный масштаб шрифта увеличивает сами буквы (не больше чем на 15 %),
/// но не высоту строки: иначе тетрадная сетка поплыла бы.
class LineText extends StatelessWidget {
  const LineText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style.fontSize ?? 14;
    final scaled = math.min(
      MediaQuery.textScalerOf(context).scale(base),
      base * 1.15,
    );
    final height = kLine / scaled;
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      textScaler: TextScaler.noScaling,
      style: style.copyWith(fontSize: scaled, height: height),
      strutStyle: StrutStyle(
        fontFamily: style.fontFamily,
        fontSize: scaled,
        height: height,
        forceStrutHeight: true,
      ),
    );
  }
}

/// Округляет высоту содержимого вверх до целого числа строк тетради и
/// центрирует его в этой высоте. Годится для строк списков с переменной
/// высотой (длинные названия и т. п.), чтобы всё, что ниже, не съезжало
/// с линий.
class LineSnap extends SingleChildRenderObjectWidget {
  const LineSnap({super.key, super.child, this.minLines = 1});

  /// Минимальная высота в строках.
  final int minLines;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderLineSnap(minLines);

  @override
  void updateRenderObject(BuildContext context, RenderLineSnap renderObject) {
    renderObject.minLines = minLines;
  }
}

class RenderLineSnap extends RenderShiftedBox {
  RenderLineSnap(this._minLines) : super(null);

  int _minLines;

  set minLines(int value) {
    if (value == _minLines) return;
    _minLines = value;
    markNeedsLayout();
  }

  double _snap(double height) {
    final lines = math.max(_minLines, (height / kLine - 1e-6).ceil());
    return lines * kLine;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final c = child;
    if (c == null) return constraints.constrain(Size(0, _minLines * kLine));
    final s = c.getDryLayout(constraints);
    return constraints.constrain(Size(s.width, _snap(s.height)));
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.constrain(Size(0, _minLines * kLine));
      return;
    }
    c.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(Size(c.size.width, _snap(c.size.height)));
    (c.parentData! as BoxParentData).offset =
        Offset(0, (size.height - c.size.height) / 2);
  }
}
