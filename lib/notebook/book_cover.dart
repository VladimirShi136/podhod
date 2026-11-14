import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_icon.dart';
import 'bookmark_bar.dart';
import 'spiral_painter.dart';

/// Обложка тетради на весь экран. Показывается при запуске, потом
/// открывается (поворачивается вокруг левого края), а под ней уже лежит
/// страница «Сегодня».
///
/// [open] — прогресс открытия обложки (0 закрыта, 1 открыта и убрана).
/// [loading] — прогресс полоски загрузки на обложке.
class IntroOverlay extends StatelessWidget {
  const IntroOverlay({super.key, required this.open, required this.loading});

  final Animation<double> open;
  final Animation<double> loading;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: open,
      builder: (context, _) {
        if (open.value >= 1) return const SizedBox.shrink();
        final t = Curves.easeInOutCubic.transform(open.value);

        return Stack(
          fit: StackFit.expand,
          children: [
            _FlipCover(progress: t, child: BookCover(loading: loading)),
            // Спираль остаётся на месте («на корешке») и поверх закрытой обложки.
            SafeArea(
              child: Stack(
                children: const [
                  Positioned(
                    left: 8,
                    top: 8,
                    bottom: BookmarkBar.height,
                    width: 56,
                    child: IgnorePointer(
                      child: CustomPaint(painter: SpiralPainter()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Поворот обложки вокруг левого края. Знак поворота такой же, как у страниц
/// в notebook_screen.dart: если поменяете там, поменяйте и здесь.
class _FlipCover extends StatelessWidget {
  const _FlipCover({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(math.pi * progress);

    return Offstage(
      // После 90° обложка уже за левым краем экрана, рисовать её незачем.
      offstage: progress >= 0.5,
      child: Transform(
        alignment: Alignment.centerLeft,
        transform: matrix,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35 * progress),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.loading});

  final Animation<double> loading;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8F6339), Color(0xFF4A301C)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // блик сверху слева и затемнение снизу справа
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.5, -0.7),
                radius: 0.9,
                colors: [Color(0x24FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.6, 0.8),
                radius: 0.9,
                colors: [Color(0x47000000), Color(0x00000000)],
              ),
            ),
          ),
          // тиснёная пунктирная рамка
          CustomPaint(
            painter: _DashedBorderPainter(
              EdgeInsets.fromLTRB(
                64,
                20 + safe.top,
                20,
                20 + safe.bottom,
              ),
            ),
          ),
          // резинка-фиксатор
          const Positioned(
            right: 46,
            top: 0,
            bottom: 0,
            width: 22,
            child: ColoredBox(color: Color(0x8C24170D)),
          ),
          // иконка + название ровно по центру экрана
          // (так же расположен логотип на нативном сплеше)
          _FadeIn(
            child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: -0.035,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(42),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x73000000),
                          offset: Offset(0, 14),
                          blurRadius: 28,
                        ),
                        BoxShadow(color: Color(0x59E8C48A), spreadRadius: 4),
                      ],
                    ),
                    child: const AppIcon(size: 190, radius: 42),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Подход',
                  style: AppText.hand(62, color: const Color(0xFFF6E7C8))
                      .copyWith(
                    shadows: const [
                      Shadow(color: Color(0x59000000), offset: Offset(0, 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'дневник тренировок',
                  style: AppText.body(17, color: const Color(0xD9E8C48A)),
                ),
              ],
            ),
          ),
          ),
          _FadeIn(
            child: Align(
              alignment: const Alignment(0, 0.78),
              child: _Loader(progress: loading),
            ),
          ),
        ],
      ),
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 6,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0x4D000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.value.clamp(0.0, 1.0).toDouble(),
            heightFactor: 1,
            child: const ColoredBox(color: Color(0xFFF3D27A)),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter(this.insets);

  final EdgeInsets insets;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x66E8C48A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rrect = RRect.fromLTRBR(
      insets.left,
      insets.top,
      size.width - insets.right,
      size.height - insets.bottom,
      const Radius.circular(10),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 8, metric.length)),
          paint,
        );
        d += 14;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.insets != insets;
}

/// Плавное появление при первом показе: логотип «проявляется» на коричневом
/// фоне, который уже был виден на нативном экране.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      builder: (context, value, child) =>
          Opacity(opacity: value, child: child),
      child: child,
    );
  }
}
