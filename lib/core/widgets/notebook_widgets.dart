import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Кнопка с «нарисованными от руки» неровными скруглениями.
class NotebookButton extends StatelessWidget {
  const NotebookButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(14),
      topRight: Radius.circular(6),
      bottomRight: Radius.circular(16),
      bottomLeft: Radius.circular(8),
    ),
    side: BorderSide(color: AppColors.ink, width: 2.5),
  );

  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.paper : AppColors.ink;
    return Material(
      color: filled ? AppColors.ink : Colors.transparent,
      shape: _shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: _shape,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Center(
            child: Text(label, style: AppText.body(20, color: fg)),
          ),
        ),
      ),
    );
  }
}

/// Красный штамп («РЕКОРД», «NEW»).
class Stamp extends StatelessWidget {
  const Stamp(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.red, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: AppText.body(14, color: AppColors.red).copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// Жёлтый стикер-заметка.
class Sticker extends StatelessWidget {
  const Sticker(this.text, {super.key, this.fontSize = 13});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.035,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: const BoxDecoration(
          color: AppColors.sticker,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(1, 2),
              blurRadius: 3,
            ),
          ],
        ),
        child: Text(text, style: AppText.body(fontSize)),
      ),
    );
  }
}

/// Чекбокс в клетку с красной «галочкой от руки».
class HandCheckbox extends StatelessWidget {
  const HandCheckbox({super.key, required this.checked, this.onChanged});

  final bool checked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!checked),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CustomPaint(painter: _CheckPainter(checked)),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.checked);

  final bool checked;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)),
      box,
    );

    if (checked) {
      final tick = Paint()
        ..color = AppColors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      // галочка выходит за рамку, как будто поставлена ручкой
      final path = Path()
        ..moveTo(size.width * 0.12, size.height * 0.55)
        ..lineTo(size.width * 0.40, size.height * 0.85)
        ..lineTo(size.width * 1.10, size.height * -0.15);
      canvas.drawPath(path, tick);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.checked != checked;
}
