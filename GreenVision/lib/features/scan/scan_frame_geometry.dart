import 'dart:ui';

abstract final class ScanFrameGeometry {
  static RRect frameFor(Size viewportSize) {
    final frameWidth = viewportSize.width - 48;
    final frameHeight = frameWidth * 1.08;
    return RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(viewportSize.width / 2, viewportSize.height * 0.45),
        width: frameWidth,
        height: frameHeight,
      ),
      const Radius.circular(28),
    );
  }
}
