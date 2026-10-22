import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:waste_classification/core/config/app_config.dart';
import 'package:waste_classification/data/local/gemini_preferences.dart';
import 'package:waste_classification/data/models/classification_result.dart';
import 'package:waste_classification/services/classifier/model_label_mapper.dart';
import 'package:waste_classification/services/classifier/waste_classifier_service.dart';

class GeminiClassifierService implements WasteClassifierService {
  GeminiClassifierService({
    http.Client? client,
    this.model = 'gemini-2.0-flash',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String model;
  static const _timeout = Duration(seconds: 60);

  /// Base endpoint — auth is added per request depending on key format.
  static const _baseEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  Future<String?> _resolveApiKey() async {
    final userKey = await geminiPreferences.getApiKey();
    if (userKey != null && userKey.trim().isNotEmpty) {
      return userKey.trim();
    }
    if (AppConfig.defaultGeminiApiKey.trim().isNotEmpty) {
      return AppConfig.defaultGeminiApiKey.trim();
    }
    return null;
  }

  /// Returns the correct URL and headers based on the key format.
  /// - Keys starting with "AIza" → legacy API-key format (?key= query param)
  /// - All other keys (e.g. AQ. service-account tokens) → Bearer token
  ({Uri url, Map<String, String> headers}) _buildRequest(String apiKey) {
    final isLegacyApiKey = apiKey.startsWith('AIza');
    debugPrint('[Gemini] Key format: ${isLegacyApiKey ? "APIKey (?key=)" : "Bearer token (Authorization header)"}');

    final uri = isLegacyApiKey
        ? Uri.parse('$_baseEndpoint/$model:generateContent?key=$apiKey')
        : Uri.parse('$_baseEndpoint/$model:generateContent');

    final headers = {
      'Content-Type': 'application/json',
      if (!isLegacyApiKey) 'Authorization': 'Bearer $apiKey',
    };

    return (url: uri, headers: headers);
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
      throw const ClassificationException(
        ClassificationErrorCode.unavailable,
        'gemini_api_key_missing',
      );
    }

    final mimeType = _mimeTypeFor(filename);
    final base64Image = base64Encode(imageBytes);
    final (:url, :headers) = _buildRequest(apiKey);

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

Return a JSON object with this exact structure:
{
  "predicted_class": "<One of the 9 labels above>",
  "category_id": "<organic, recyclable, or other>",
  "confidence": <confidence score between 0.60 and 0.99>
}
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.1,
      }
    });

    try {
      final response = await _client
          .post(url, headers: headers, body: requestBody)
          .timeout(_timeout);

      debugPrint('[Gemini] HTTP ${response.statusCode}');
      debugPrint('[Gemini] Body: ${response.body.substring(0, response.body.length.clamp(0, 600))}');

      if (response.statusCode == 401 || response.statusCode == 403) {
        // Check for the specific API_KEY_SERVICE_BLOCKED reason
        final body = response.body;
        if (body.contains('API_KEY_SERVICE_BLOCKED')) {
          throw const ClassificationException(
            ClassificationErrorCode.unavailable,
            'gemini_api_not_enabled',
          );
        }
        throw const ClassificationException(
          ClassificationErrorCode.unavailable,
          'gemini_invalid_key',
        );
      }

      if (response.statusCode == 400) {
        // 400 can mean bad request (e.g. wrong key format) — treat as invalid key
        debugPrint('[Gemini] 400 — possible key format mismatch or bad request');
        throw const ClassificationException(
          ClassificationErrorCode.unavailable,
          'gemini_invalid_key',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ClassificationException(
          ClassificationErrorCode.unavailable,
        );
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = jsonResponse['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw const ClassificationException(
          ClassificationErrorCode.invalidResponse,
        );
      }

      final firstCandidate = candidates.first as Map<String, dynamic>;
      final content = firstCandidate['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw const ClassificationException(
          ClassificationErrorCode.invalidResponse,
        );
      }

      final text = parts.first['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw const ClassificationException(
          ClassificationErrorCode.invalidResponse,
        );
      }

      final cleanJsonText = text
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*$', multiLine: true), '')
          .trim();

      final parsedData = jsonDecode(cleanJsonText) as Map<String, dynamic>;
      final predictedClass =
          parsedData['predicted_class']?.toString() ?? 'Miscellaneous Trash';
      final confidence =
          (parsedData['confidence'] as num?)?.toDouble().clamp(0.5, 0.99) ??
              0.90;
      final categoryId = parsedData['category_id']?.toString() ??
          ModelLabelMapper.categoryIdFor(predictedClass);

      return ClassificationResult(
        modelLabel: predictedClass,
        categoryId: categoryId,
        confidence: confidence,
        allProbabilities: {predictedClass: confidence},
      );
    } on SocketException catch (e) {
      debugPrint('[Gemini] SocketException: $e');
      throw ClassificationException(ClassificationErrorCode.noConnection, e);
    } on TimeoutException catch (e) {
      debugPrint('[Gemini] TimeoutException: $e');
      throw ClassificationException(ClassificationErrorCode.timeout, e);
    } on ClassificationException {
      rethrow;
    } catch (e, st) {
      debugPrint('[Gemini] Unexpected error: $e\n$st');
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
