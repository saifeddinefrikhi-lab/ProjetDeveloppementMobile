import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:waste_classification/features/scan/scan_frame_geometry.dart';
import 'package:waste_classification/services/image/camera_frame_cropper.dart';

void main() {
  const cropper = CameraFrameCropper();

  test('keeps coordinates unchanged when image and viewport match', () {
    final source = cropper.sourceRectFor(
      imageSize: const Size(100, 200),
      viewportSize: const Size(100, 200),
      frameRect: const Rect.fromLTRB(10, 20, 90, 180),
    );

    expect(source, const Rect.fromLTRB(10, 20, 90, 180));
  });

  test('reverses the horizontal crop introduced by BoxFit.cover', () {
    final source = cropper.sourceRectFor(
      imageSize: const Size(200, 100),
      viewportSize: const Size(100, 100),
      frameRect: const Rect.fromLTWH(0, 0, 100, 100),
    );

    expect(source, const Rect.fromLTRB(50, 0, 150, 100));
  });

  test('maps the visible scan frame inside a portrait camera image', () {
    const imageSize = Size(3000, 4000);
    const viewportSize = Size(1080, 2200);
    final frameRect = ScanFrameGeometry.frameFor(viewportSize).outerRect;
    final source = cropper.sourceRectFor(
      imageSize: imageSize,
      viewportSize: viewportSize,
      frameRect: frameRect,
    );

    expect(source.left, greaterThan(0));
    expect(source.top, greaterThan(0));
    expect(source.right, lessThan(imageSize.width));
    expect(source.bottom, lessThan(imageSize.height));
    expect(
      source.width / source.height,
      closeTo(frameRect.width / frameRect.height, 0.001),
    );
  });
}
