import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

class CameraFrameCropper {
  const CameraFrameCropper();

  ui.Rect sourceRectFor({
    required ui.Size imageSize,
    required ui.Size viewportSize,
    required ui.Rect frameRect,
  }) {
    if (imageSize.isEmpty || viewportSize.isEmpty || frameRect.isEmpty) {
      throw ArgumentError('Image, viewport, and frame sizes must be positive.');
    }

    final scale = math.max(
      viewportSize.width / imageSize.width,
      viewportSize.height / imageSize.height,
    );
    final displayedWidth = imageSize.width * scale;
    final displayedHeight = imageSize.height * scale;
    final offsetX = (viewportSize.width - displayedWidth) / 2;
    final offsetY = (viewportSize.height - displayedHeight) / 2;

    final sourceRect = ui.Rect.fromLTRB(
      ((frameRect.left - offsetX) / scale).clamp(0, imageSize.width),
      ((frameRect.top - offsetY) / scale).clamp(0, imageSize.height),
      ((frameRect.right - offsetX) / scale).clamp(0, imageSize.width),
      ((frameRect.bottom - offsetY) / scale).clamp(0, imageSize.height),
    );
    if (sourceRect.isEmpty) {
      throw StateError('The scan frame does not overlap the captured image.');
    }
    return sourceRect;
  }

  Future<File> cropPreview({
    required ui.Image image,
    required ui.Size viewportSize,
    required ui.Rect frameRect,
  }) async {
    final bytes = await cropPreviewBytes(
      image: image,
      viewportSize: viewportSize,
      frameRect: frameRect,
    );
    final output = File(
      '${Directory.systemTemp.path}/scan_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await output.writeAsBytes(bytes, flush: true);
    return output;
  }

  Future<Uint8List> cropPreviewBytes({
    required ui.Image image,
    required ui.Size viewportSize,
    required ui.Rect frameRect,
  }) async {
    final sourceRect = sourceRectFor(
      imageSize: ui.Size(image.width.toDouble(), image.height.toDouble()),
      viewportSize: viewportSize,
      frameRect: frameRect,
    );
    final outputWidth = math.max(1, sourceRect.width.round());
    final outputHeight = math.max(1, sourceRect.height.round());
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      sourceRect,
      ui.Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(outputWidth, outputHeight);
    try {
      final pngData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (pngData == null) {
        throw StateError('Unable to encode the cropped camera image.');
      }
      return pngData.buffer.asUint8List(
        pngData.offsetInBytes,
        pngData.lengthInBytes,
      );
    } finally {
      croppedImage.dispose();
      picture.dispose();
    }
  }
}

const cameraFrameCropper = CameraFrameCropper();
