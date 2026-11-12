import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:waste_classification/core/config/app_config.dart';
import 'package:waste_classification/data/local/groq_preferences.dart';
import 'package:waste_classification/data/models/classification_result.dart';
import 'package:waste_classification/services/classifier/model_label_mapper.dart';
import 'package:waste_classification/services/classifier/waste_classifier_service.dart';

class GroqClassifierService implements WasteClassifierService {
  GroqClassifierService({
    String? apiKey,
    http.Client? client,
    this.model = 'qwen/qwen3.8-27b',
  })  : _apiKeyOverride = apiKey,
        _client = client ?? http.Client();

  final String? _apiKeyOverride;
  final http.Client _client;
  final String model;
  static const _timeout = Duration(seconds: 45);
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  Future<String?> _resolveApiKey() async {
    final override = _apiKeyOverride;
    if (override != null) {
      return override.trim().isEmpty ? null : override.trim();
    }
    final userKey = await groqPreferences.getApiKey();
    if (userKey != null && userKey.trim().isNotEmpty) {
      return userKey.trim();
    }
    if (AppConfig.defaultGroqApiKey.trim().isNotEmpty) {
      return AppConfig.defaultGroqApiKey.trim();
    }
    return null;
  }

  Future<String> _resolveModel() async {
    final savedModel = await groqPreferences.getModel();
    if (savedModel != null && savedModel.trim().isNotEmpty) {
      return savedModel.trim();
    }
    return model;
  }

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
    final apiKey = await _resolveApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[Groq] API key is missing');
      throw const ClassificationException(
        ClassificationErrorCode.unavailable,
        'groq_api_key_missing',
      );
    }

    final activeModel = await _resolveModel();
    final mimeType = _mimeTypeFor(filename);
    final base64Image = base64Encode(imageBytes);

    const prompt = '''
You are an expert waste classification AI. Analyze the image and identify the main waste item.
Classify the item into EXACTLY ONE of the following valid labels:
- Cardboard
- Food Organics
- Glass
- Metal
- Miscellaneous Trash
- Paper
- Plastic
- Textile Trash
- Vegetation

And determine its category:
- "organic" (for Food Organics, Vegetation)
- "recyclable" (for Cardboard, Glass, Metal, Paper, Plastic)
- "other" (for Miscellaneous Trash, Textile Trash)

Respond ONLY with a valid JSON object matching this exact structure:
{
  "predicted_class": "<One of the 9 labels above>",
  "category_id": "<organic, recyclable, or other>",
  "confidence": <confidence score between 0.60 and 0.99>
}
''';

    final requestBody = jsonEncode({
      'model': activeModel,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:$mimeType;base64,$base64Image',
              },
            },
          ],
        },
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.1,
      'max_completion_tokens': 512,
    });

    try {
      debugPrint('[Groq] POST $_endpoint with model $activeModel (${imageBytes.length} bytes)');
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'User-Agent': 'WasteClassification/1.0',
            },
            body: requestBody,
          )
          .timeout(_timeout);

      debugPrint('[Groq] HTTP ${response.statusCode}');
      if (response.body.isNotEmpty) {
        debugPrint('[Groq] Body: ${response.body.substring(0, response.body.length.clamp(0, 400))}');
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ClassificationException(
          ClassificationErrorCode.unavailable,
          'groq_invalid_key',
        );
      }

      if (response.statusCode == 429) {
        throw const ClassificationException(
          ClassificationErrorCode.unavailable,
          'groq_rate_limit',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ClassificationException(
          ClassificationErrorCode.unavailable,
        );
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = jsonResponse['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw const ClassificationException(
          ClassificationErrorCode.invalidResponse,
        );
      }

      final firstChoice = choices.first as Map<String, dynamic>;
      final message = firstChoice['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw const ClassificationException(
          ClassificationErrorCode.invalidResponse,
        );
      }

      final cleanJsonText = content
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*$', multiLine: true), '')
          .trim();

      final parsedData = jsonDecode(cleanJsonText) as Map<String, dynamic>;
      var rawLabel = parsedData['predicted_class']?.toString() ?? 'Miscellaneous Trash';

      // Match label with canonical labels in ModelLabelMapper
      final canonicalLabel = ModelLabelMapper.labels.firstWhere(
        (l) => l.toLowerCase() == rawLabel.trim().toLowerCase(),
        orElse: () => rawLabel,
      );

      final confidence =
          (parsedData['confidence'] as num?)?.toDouble().clamp(0.5, 0.99) ?? 0.90;
      final categoryId = parsedData['category_id']?.toString() ??
          ModelLabelMapper.categoryIdFor(canonicalLabel);

      return ClassificationResult(
        modelLabel: canonicalLabel,
        categoryId: categoryId,
        confidence: confidence,
        allProbabilities: {canonicalLabel: confidence},
      );
    } on SocketException catch (e) {
      debugPrint('[Groq] SocketException: $e');
      throw ClassificationException(ClassificationErrorCode.noConnection, e);
    } on TimeoutException catch (e) {
      debugPrint('[Groq] TimeoutException: $e');
      throw ClassificationException(ClassificationErrorCode.timeout, e);
    } on ClassificationException {
      rethrow;
    } catch (e, st) {
      debugPrint('[Groq] Unexpected error: $e\n$st');
      throw ClassificationException(ClassificationErrorCode.unavailable, e);
    }
  }

  String _mimeTypeFor(String filename) {
    return switch (p.extension(filename).toLowerCase()) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
