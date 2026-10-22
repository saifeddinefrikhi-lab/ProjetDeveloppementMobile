class ClassificationResult {
  const ClassificationResult({
    required this.modelLabel,
    required this.categoryId,
    required this.confidence,
    this.allProbabilities = const {},
  });

  final String modelLabel;
  final String categoryId;
  final double confidence;
  final Map<String, double> allProbabilities;
}
