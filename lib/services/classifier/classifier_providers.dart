import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_classification/core/config/app_config.dart';
import 'package:waste_classification/services/classifier/api_classifier_service.dart';
import 'package:waste_classification/services/classifier/gemini_classifier_service.dart';
import 'package:waste_classification/services/classifier/groq_classifier_service.dart';
import 'package:waste_classification/services/classifier/hf_inference_classifier_service.dart';
import 'package:waste_classification/services/classifier/mock_classifier_service.dart';
import 'package:waste_classification/services/classifier/waste_classifier_service.dart';

final classifierServiceProvider = Provider<WasteClassifierService>((ref) {
  switch (AppConfig.classifierMode) {
    case ClassifierMode.groq:
      return GroqClassifierService();
    case ClassifierMode.hfInference:
      return HfInferenceClassifierService();
    case ClassifierMode.gemini:
      return GeminiClassifierService();
    case ClassifierMode.api:
      return ApiClassifierService(baseUrl: AppConfig.apiBaseUrl);
    case ClassifierMode.mock:
      return const MockClassifierService();
  }
});
