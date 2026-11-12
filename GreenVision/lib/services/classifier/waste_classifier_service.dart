import 'dart:io';
import 'dart:typed_data';

import 'package:waste_classification/data/models/classification_result.dart';

abstract interface class WasteClassifierService {
  Future<ClassificationResult> classify(File imageFile);
  Future<ClassificationResult> classifyBytes(
    Uint8List imageBytes, {
    String filename = 'scan.png',
  });
}

class ClassificationException implements Exception {
  const ClassificationException(this.code, [this.cause]);

  final ClassificationErrorCode code;
  final Object? cause;
}

enum ClassificationErrorCode {
  noConnection,
  timeout,
  invalidResponse,
  unavailable,
}
