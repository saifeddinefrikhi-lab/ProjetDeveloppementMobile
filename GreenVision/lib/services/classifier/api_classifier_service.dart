import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:waste_classification/data/models/classification_result.dart';
import 'package:waste_classification/services/classifier/model_label_mapper.dart';
import 'package:waste_classification/services/classifier/waste_classifier_service.dart';

class ApiClassifierService implements WasteClassifierService {
  ApiClassifierService({
    required this.baseUrl,
    this.endpointPath = '/predict',
    this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String endpointPath;
  final Future<String?> Function()? tokenProvider;
  final http.Client _client;
  // A free Hugging Face Space can need extra time for its first request after
  // sleeping. Keep the retry, but allow each attempt to cover a cold start.
  static const _timeout = Duration(seconds: 60);

  @override
  Future<ClassificationResult> classify(File imageFile) async {
    return _classifyRequest(() => _send(imageFile));
  }

  @override
  Future<ClassificationResult> classifyBytes(
    Uint8List imageBytes, {
    String filename = 'scan.png',
  }) async {
    return _classifyRequest(() => _sendBytes(imageBytes, filename: filename));
  }

  Future<ClassificationResult> _classifyRequest(
    Future<ClassificationResult> Function() request,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await request().timeout(_timeout);
      } on SocketException catch (error) {
        lastError = error;
        if (attempt == 1) {
          throw ClassificationException(
            ClassificationErrorCode.noConnection,
            error,
          );
        }
      } on http.ClientException catch (error) {
        lastError = error;
        if (attempt == 1) {
          throw ClassificationException(
            ClassificationErrorCode.noConnection,
            error,
          );
        }
      } on TimeoutException catch (error) {
        lastError = error;
        if (attempt == 1) {
          throw ClassificationException(ClassificationErrorCode.timeout, error);
        }
      } on ClassificationException {
        rethrow;
      } on Object catch (error) {
        throw ClassificationException(
          ClassificationErrorCode.unavailable,
          error,
        );
      }
    }
    throw ClassificationException(
      ClassificationErrorCode.unavailable,
      lastError,
    );
  }

  Future<ClassificationResult> _send(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return _sendBytes(bytes, filename: p.basename(imageFile.path));
  }

  Future<ClassificationResult> _sendBytes(
    Uint8List bytes, {
    required String filename,
  }) async {
    final endpoint = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/'
      '${endpointPath.replaceAll(RegExp(r'^/+'), '')}',
    );
    final request = http.MultipartRequest('POST', endpoint)
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: filename,
          contentType: _imageMediaType(filename),
        ),
      );
    final token = await tokenProvider?.call();
    if (tokenProvider != null && (token == null || token.trim().isEmpty)) {
      throw const ClassificationException(
        ClassificationErrorCode.unavailable,
        'Authentication required',
      );
    }
    if (token != null && token.trim().isNotEmpty) {
      request.headers['authorization'] = 'Bearer ${token.trim()}';
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 401) {
      throw const ClassificationException(
        ClassificationErrorCode.unavailable,
        'Authentication expired',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ClassificationException(ClassificationErrorCode.unavailable);
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] is Map
          ? json['data'] as Map<String, dynamic>
          : json;
      final label = data['predicted_class'] as String;
      final confidence = (data['confidence'] as num)
          .toDouble()
          .clamp(0, 1)
          .toDouble();
      final rawProbabilities = data['all_probabilities'];
      final probabilities = rawProbabilities is Map
          ? rawProbabilities.map(
              (key, value) =>
                  MapEntry(key.toString(), (value as num).toDouble()),
            )
          : <String, double>{};

      return ClassificationResult(
        modelLabel: label,
        categoryId: ModelLabelMapper.categoryIdFor(label),
        confidence: confidence,
        allProbabilities: probabilities,
      );
    } on ClassificationException {
      rethrow;
    } on Object catch (error) {
      throw ClassificationException(
        ClassificationErrorCode.invalidResponse,
        error,
      );
    }
  }

  MediaType _imageMediaType(String imagePath) {
    return switch (p.extension(imagePath).toLowerCase()) {
      '.jpg' || '.jpeg' => MediaType('image', 'jpeg'),
      '.png' => MediaType('image', 'png'),
      '.webp' => MediaType('image', 'webp'),
      _ => MediaType('application', 'octet-stream'),
    };
  }
}
