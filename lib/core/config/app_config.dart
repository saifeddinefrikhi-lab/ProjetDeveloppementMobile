enum ClassifierMode { mock, api, gemini, groq, hfInference }

abstract final class AppConfig {
  static const String _mode = String.fromEnvironment(
    'CLASSIFIER_MODE',
    defaultValue: 'groq',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'WASTE_API_BASE_URL',
    defaultValue: '',
  );

  static const String defaultGeminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String defaultGroqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  static const String appVersion = '1.0.11';

  static ClassifierMode get classifierMode {
    final mode = _mode.trim().toLowerCase();
    if (mode == 'mock') return ClassifierMode.mock;
    if (mode == 'api') return ClassifierMode.api;
    if (mode == 'gemini') return ClassifierMode.gemini;
    if (mode == 'groq') return ClassifierMode.groq;
    return ClassifierMode.hfInference;
  }
}
