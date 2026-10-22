import 'dart:io';
import 'dart:typed_data';

import 'package:waste_classification/data/models/classification_result.dart';
import 'package:waste_classification/services/classifier/model_label_mapper.dart';
import 'package:waste_classification/services/classifier/waste_classifier_service.dart';

class MockClassifierService implements WasteClassifierService {
  const MockClassifierService();

  @override
  Future<ClassificationResult> classify(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return classifyBytes(bytes);
  }

  @override
  Future<ClassificationResult> classifyBytes(
    Uint8List imageBytes, {
    String filename = 'scan.png',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    final checksum =
        imageBytes.take(2048).fold<int>(0, (sum, byte) => sum + byte);
    final label =
        ModelLabelMapper.labels[checksum % ModelLabelMapper.labels.length];
    final confidence = 0.58 + ((checksum % 37) / 100);

    return ClassificationResult(
      modelLabel: label,
      categoryId: ModelLabelMapper.categoryIdFor(label),
      confidence: confidence.clamp(0, 0.96).toDouble(),
    );
  }
}
