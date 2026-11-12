import 'package:flutter_test/flutter_test.dart';
import 'package:waste_classification/data/models/scan_result.dart';

void main() {
  test('round-trips a scan result through the database map', () {
    final original = ScanResult(
      id: 'scan-1',
      imagePath: '/private/scan-1.png',
      scannedAt: DateTime(2026, 7, 14, 20, 15),
      categoryId: 'recyclable',
      modelLabel: 'Glass',
      confidence: 0.94,
    );

    final restored = ScanResult.fromMap(original.toMap());

    expect(restored.id, original.id);
    expect(restored.imagePath, original.imagePath);
    expect(restored.scannedAt, original.scannedAt);
    expect(restored.categoryId, original.categoryId);
    expect(restored.modelLabel, original.modelLabel);
    expect(restored.confidence, original.confidence);
  });
}
