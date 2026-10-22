import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:waste_classification/data/models/classification_result.dart';
import 'package:waste_classification/services/classifier/waste_classifier_service.dart';

/// Classifies waste images using HuggingFace's hosted Inference API.
/// Model: yangy50/garbage-classification (cardboard, glass, metal, paper, plastic, trash)
/// No API key required. Optional HF token for higher rate limits.
class HfInferenceClassifierService implements WasteClassifierService {
  HfInferenceClassifierService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const _modelId = 'yangy50/garbage-classification';
  static const _inferenceUrl =
      'https://api-inference.huggingface.co/models/$_modelId';
  static const _timeout = Duration(seconds: 60);
  static const _retryDelay = Duration(seconds: 20);

  /// Maps model output labels → (our display label, category ID)
  static const _labelMap = <String, (String, String)>{
    // yangy50/garbage-classification labels
    'cardboard': ('Cardboard', 'recyclable'),
    'glass': ('Glass', 'recyclable'),
    'metal': ('Metal', 'recyclable'),
    'paper': ('Paper', 'recyclable'),
    'plastic': ('Plastic', 'recyclable'),
    'trash': ('Miscellaneous Trash', 'other'),
    // Alternate label spellings some HF models use
    'brown-glass': ('Glass', 'recyclable'),
    'green-glass': ('Glass', 'recyclable'),
    'white-glass': ('Glass', 'recyclable'),
    'biological': ('Food Organics', 'organic'),
    'organic': ('Food Organics', 'organic'),
    'food organics': ('Food Organics', 'organic'),
    'food_organics': ('Food Organics', 'organic'),
    'vegetation': ('Vegetation', 'organic'),
    'clothes': ('Textile Trash', 'other'),
    'textile': ('Textile Trash', 'other'),
    'shoes': ('Textile Trash', 'other'),
    'battery': ('Miscellaneous Trash', 'other'),
    'miscellaneous trash': ('Miscellaneous Trash', 'other'),
    'miscellaneous_trash': ('Miscellaneous Trash', 'other'),
  };

  @override
  Future<ClassificationResult> classify(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return classifyBytes(bytes, filename: p.basename(imageFile.path));
  }

  @override
  Future<ClassificationResult> classifyBytes(
    Uint8List imageBytes, {
    String filename = 'scan.jpg',
  }) async {
    final mimeType = _mimeType(filename);
    final headers = <String, String>{
      'Content-Type': mimeType,
      'Accept': 'application/json',
    };

    debugPrint('[HFInference] Sending ${imageBytes.length} bytes to $_inferenceUrl');

    try {
      var response = await _client
          .post(Uri.parse(_inferenceUrl), headers: headers, body: imageBytes)
          .timeout(_timeout);

      debugPrint('[HFInference] HTTP ${response.statusCode}');

      // 503 = model is loading — wait and retry once
      if (response.statusCode == 503) {
        debugPrint('[HFInference] Model loading, retrying in ${_retryDelay.inSeconds}s...');
        await Future.delayed(_retryDelay);
        response = await _client
            .post(Uri.parse(_inferenceUrl), headers: headers, body: imageBytes)
            .timeout(_timeout);
        debugPrint('[HFInference] Retry HTTP ${response.statusCode}');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[HFInference] Error body: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
        throw const ClassificationException(ClassificationErrorCode.unavailable);
      }

      debugPrint('[HFInference] Response: ${response.body.substring(0, response.body.length.clamp(0, 300))}');

      final decoded = jsonDecode(response.body);

      // HF Inference API returns a list of {label, score}
      if (decoded is! List || decoded.isEmpty) {
        throw const ClassificationException(ClassificationErrorCode.invalidResponse);
      }

      final topResult = decoded.first as Map<String, dynamic>;
      final rawLabel = (topResult['label'] as String? ?? 'trash').toLowerCase().trim();
      final score = (topResult['score'] as num?)?.toDouble() ?? 0.80;

      final (displayLabel, categoryId) =
          _labelMap[rawLabel] ?? ('Miscellaneous Trash', 'other');

      debugPrint('[HFInference] Classified as: $displayLabel ($rawLabel → $categoryId) @ ${(score * 100).toStringAsFixed(1)}%');

      // Build all probabilities from full list
      final allProbs = <String, double>{};
      for (final item in decoded) {
        final m = item as Map<String, dynamic>;
        final lbl = (m['label'] as String? ?? '').toLowerCase().trim();
        final sc = (m['score'] as num?)?.toDouble() ?? 0.0;
        final (mapped, _) = _labelMap[lbl] ?? ('Miscellaneous Trash', 'other');
        allProbs[mapped] = (allProbs[mapped] ?? 0) + sc;
      }

      return ClassificationResult(
        modelLabel: displayLabel,
        categoryId: categoryId,
        confidence: score.clamp(0.5, 0.99),
        allProbabilities: allProbs,
      );
    } on SocketException catch (e) {
      debugPrint('[HFInference] No connection: $e');
      throw ClassificationException(ClassificationErrorCode.noConnection, e);
    } on TimeoutException catch (e) {
      debugPrint('[HFInference] Timeout: $e');
      throw ClassificationException(ClassificationErrorCode.timeout, e);
    } on ClassificationException {
      rethrow;
    } catch (e, st) {
      debugPrint('[HFInference] Unexpected: $e\n$st');
      throw ClassificationException(ClassificationErrorCode.unavailable, e);
    }
  }

  String _mimeType(String filename) {
    return switch (p.extension(filename).toLowerCase()) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
