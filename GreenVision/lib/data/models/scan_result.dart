class ScanResult {
  const ScanResult({
    required this.id,
    required this.imagePath,
    required this.scannedAt,
    required this.categoryId,
    required this.modelLabel,
    required this.confidence,
    this.userId,
  });

  final String id;
  final String imagePath;
  final DateTime scannedAt;
  final String categoryId;
  final String modelLabel;
  final double confidence;
  final int? userId;

  factory ScanResult.fromMap(Map<String, Object?> map) => ScanResult(
    id: map['id']! as String,
    imagePath: map['image_path']! as String,
    scannedAt: DateTime.parse(map['scanned_at']! as String).toLocal(),
    categoryId: map['category_id']! as String,
    modelLabel: map['model_label']! as String,
    confidence: (map['confidence']! as num).toDouble(),
    userId: map['user_id'] as int?,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'image_path': imagePath,
    'scanned_at': scannedAt.toUtc().toIso8601String(),
    'category_id': categoryId,
    'model_label': modelLabel,
    'confidence': confidence,
    if (userId != null) 'user_id': userId,
  };
}
