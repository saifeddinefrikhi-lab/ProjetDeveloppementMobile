import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waste_classification/services/classifier/api_classifier_service.dart';
import 'package:waste_classification/services/classifier/mock_classifier_service.dart';
import 'package:waste_classification/services/classifier/model_label_mapper.dart';

void main() {
  late Directory temporaryDirectory;
  late File image;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'waste-classifier-test-',
    );
    image = File('${temporaryDirectory.path}/sample.jpg');
    await image.writeAsBytes(List<int>.generate(4096, (index) => index % 256));
  });

  tearDown(() => temporaryDirectory.delete(recursive: true));

  test('mock classifier returns one of the nine model labels', () async {
    final result = await const MockClassifierService().classify(image);

    expect(ModelLabelMapper.labels, contains(result.modelLabel));
    expect(result.confidence, inInclusiveRange(0, 1));
    expect(['organic', 'recyclable', 'other'], contains(result.categoryId));
  });

  test('API classifier parses the contract from the Kaggle notebook', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/predict');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      expect(
        request.headers.containsKey('ngrok-skip-browser-warning'),
        isFalse,
      );
      expect(
        latin1.decode(request.bodyBytes).toLowerCase(),
        contains('content-type: image/jpeg'),
      );
      return http.Response(
        jsonEncode({
          'predicted_class': 'Plastic',
          'confidence': 0.92,
          'all_probabilities': {'Plastic': 0.92, 'Glass': 0.08},
        }),
        200,
      );
    });
    final service = ApiClassifierService(
      baseUrl: 'https://example.test/',
      client: client,
    );

    final result = await service.classify(image);

    expect(result.modelLabel, 'Plastic');
    expect(result.categoryId, 'recyclable');
    expect(result.confidence, 0.92);
    expect(result.allProbabilities['Glass'], 0.08);
  });

  for (final format in {
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  }.entries) {
    test(
      'API classifier sends ${format.key} with the correct MIME type',
      () async {
        final formatImage = File(
          '${temporaryDirectory.path}/sample.${format.key}',
        );
        await formatImage.writeAsBytes([1, 2, 3]);
        final client = MockClient((request) async {
          expect(
            latin1.decode(request.bodyBytes).toLowerCase(),
            contains('content-type: ${format.value}'),
          );
          return http.Response(
            jsonEncode({'predicted_class': 'Metal', 'confidence': 0.8}),
            200,
          );
        });
        final service = ApiClassifierService(
          baseUrl: 'https://example.test',
          client: client,
        );

        final result = await service.classify(formatImage);

        expect(result.modelLabel, 'Metal');
        expect(result.categoryId, 'recyclable');
      },
    );
  }
}
