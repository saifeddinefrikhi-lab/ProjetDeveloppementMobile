import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waste_classification/services/classifier/groq_classifier_service.dart';
import 'package:waste_classification/services/classifier/waste_classifier_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GroqClassifierService', () {
    test('throws groq_api_key_missing when no key is configured', () async {
      final service = GroqClassifierService(apiKey: '');

      expect(
        () => service.classifyBytes(Uint8List.fromList([1, 2, 3])),
        throwsA(
          isA<ClassificationException>()
              .having((e) => e.code, 'code', ClassificationErrorCode.unavailable)
              .having((e) => e.cause, 'cause', 'groq_api_key_missing'),
        ),
      );
    });

    test('classifies image successfully when Groq API key is valid', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.groq.com/openai/v1/chat/completions');
        expect(request.headers['Authorization'], 'Bearer gsk_test_key_12345');
        expect(request.headers['Content-Type'], contains('application/json'));
        expect(request.headers['User-Agent'], 'WasteClassification/1.0');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'qwen/qwen3.8-27b');
        expect(body['response_format']['type'], 'json_object');

        final messages = body['messages'] as List;
        final content = messages[0]['content'] as List;
        expect(content[0]['type'], 'text');
        expect(content[1]['type'], 'image_url');
        expect(content[1]['image_url']['url'], startsWith('data:image/jpeg;base64,'));

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': jsonEncode({
                    'predicted_class': 'Plastic',
                    'category_id': 'recyclable',
                    'confidence': 0.94,
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final service = GroqClassifierService(apiKey: 'gsk_test_key_12345', client: mockClient);
      final result = await service.classifyBytes(
        Uint8List.fromList([10, 20, 30]),
        filename: 'item.jpg',
      );

      expect(result.modelLabel, 'Plastic');
      expect(result.categoryId, 'recyclable');
      expect(result.confidence, 0.94);
      expect(result.allProbabilities['Plastic'], 0.94);
    });

    test('handles 401 invalid key response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Invalid API Key', 'type': 'invalid_request_error'},
          }),
          401,
        );
      });

      final service = GroqClassifierService(apiKey: 'gsk_invalid_key', client: mockClient);

      expect(
        () => service.classifyBytes(Uint8List.fromList([1, 2, 3])),
        throwsA(
          isA<ClassificationException>()
              .having((e) => e.code, 'code', ClassificationErrorCode.unavailable)
              .having((e) => e.cause, 'cause', 'groq_invalid_key'),
        ),
      );
    });

    test('handles 429 rate limit response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Rate limit exceeded', 'type': 'tokens'},
          }),
          429,
        );
      });

      final service = GroqClassifierService(apiKey: 'gsk_valid_key', client: mockClient);

      expect(
        () => service.classifyBytes(Uint8List.fromList([1, 2, 3])),
        throwsA(
          isA<ClassificationException>()
              .having((e) => e.code, 'code', ClassificationErrorCode.unavailable)
              .having((e) => e.cause, 'cause', 'groq_rate_limit'),
        ),
      );
    });

    test('classifies File via classify method', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/bottle.png');
      await tempFile.writeAsBytes([1, 2, 3, 4]);

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List;
        final content = messages[0]['content'] as List;
        expect(content[1]['image_url']['url'], startsWith('data:image/png;base64,'));

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': jsonEncode({
                    'predicted_class': 'Glass',
                    'category_id': 'recyclable',
                    'confidence': 0.88,
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final service = GroqClassifierService(apiKey: 'gsk_test_key_12345', client: mockClient);
      final result = await service.classify(tempFile);

      expect(result.modelLabel, 'Glass');
      expect(result.categoryId, 'recyclable');
      expect(result.confidence, 0.88);

      await tempDir.delete(recursive: true);
    });
  });
}
