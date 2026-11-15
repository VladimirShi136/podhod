import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Кружок подхода с номером. Закрашен, если подход выполнен.
class SetBubble extends StatelessWidget {
  const SetBubble({
    super.key,
    required this.number,
    required this.done,
    this.onTap,
    this.size = 18,
  });

  final int number;
  final bool done;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        // зона нажатия больше самого кружка
        width: size + 6,
        height: size + 6,
        child: Center(
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.ink : Colors.transparent,
              border: Border.all(color: AppColors.ink, width: 1.5),
            ),
            child: Text(
              '$number',
              style: AppText.body(
                size * 0.6,
                color: done ? AppColors.paper : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
