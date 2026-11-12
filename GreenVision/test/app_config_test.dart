import 'package:flutter_test/flutter_test.dart';
import 'package:waste_classification/core/config/app_config.dart';

void main() {
  test('uses the backend API by default', () {
    expect(AppConfig.classifierMode, ClassifierMode.api);
    expect(AppConfig.apiBaseUrl, 'http://localhost:3000/api/v1');
    expect(AppConfig.apiBaseUrl, isNot(endsWith('/classify')));
  });
}
