import 'package:flutter_test/flutter_test.dart';
import 'package:waste_classification/core/config/app_config.dart';

void main() {
  test('uses the Groq Vision API by default', () {
    expect(AppConfig.classifierMode, ClassifierMode.groq);
    expect(
      AppConfig.apiBaseUrl,
      'https://voxnuts947-waste-classification-api.hf.space',
    );
    expect(AppConfig.apiBaseUrl, isNot(endsWith('/predict')));
  });
}
