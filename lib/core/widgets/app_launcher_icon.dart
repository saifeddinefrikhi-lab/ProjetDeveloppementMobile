import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:waste_classification/core/theme/app_colors.dart';

/// The in-app version of the Android launcher mark.
///
/// Its geometry and colors mirror `android/app/src/main/res/drawable/app_icon.xml`.
class AppLauncherIcon extends StatelessWidget {
  const AppLauncherIcon({this.size = 44, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _AppLauncherIconPainter()),
      ),
    );
  }
}

class _AppLauncherIconPainter extends CustomPainter {
  const _AppLauncherIconPainter();

  static const _viewportSize = 108.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / _viewportSize;
    final offset = Offset(
      (size.width - (_viewportSize * scale)) / 2,
      (size.height - (_viewportSize * scale)) / 2,
    );
    canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..scale(scale);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, _viewportSize, _viewportSize),
        const Radius.circular(25),
      ),
      Paint()..color = AppColors.launcherBackground,
    );

    final frame = Path()
      ..addRect(const Rect.fromLTWH(24, 24, 18, 5))
      ..addRect(const Rect.fromLTWH(24, 24, 5, 18))
      ..addRect(const Rect.fromLTWH(66, 24, 18, 5))
      ..addRect(const Rect.fromLTWH(79, 24, 5, 18))
      ..addRect(const Rect.fromLTWH(24, 66, 5, 18))
      ..addRect(const Rect.fromLTWH(24, 79, 18, 5))
      ..addRect(const Rect.fromLTWH(79, 66, 5, 18))
      ..addRect(const Rect.fromLTWH(66, 79, 18, 5));
    canvas.drawPath(frame, Paint()..color = AppColors.launcherFrame);

    final leaf = Path()
      ..moveTo(69, 37)
      ..cubicTo(55, 37, 42, 43, 38, 54)
      ..cubicTo(34, 65, 41, 73, 51, 73)
      ..cubicTo(64, 73, 71, 57, 69, 37)
      ..close();
    canvas.drawPath(leaf, Paint()..color = AppColors.primaryDark);

    final vein = Path()
      ..moveTo(48, 64)
      ..cubicTo(53, 55, 59, 49, 66, 44)
      ..lineTo(64, 42)
      ..cubicTo(56, 47, 49, 54, 44, 63)
      ..close();
    canvas.drawPath(vein, Paint()..color = AppColors.launcherBackground);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
