import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  // Replace with your actual Google Cloud Translation API Key
  final String _apiKey = 'YOUR_API_KEY_HERE'; 
  final String _baseUrl = 'https://translation.googleapis.com/language/translate/v2';

  // Supported languages (subset for demo)
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'si': 'Sinhala',
    'es': 'Spanish',
    'fr': 'French',
    'hi': 'Hindi',
    'zh': 'Chinese',
    'ar': 'Arabic',
    'ru': 'Russian',
  };

  /// Translates text to the target language.
  /// 
  /// Returns the translated text.
  /// If [isMock] is true, it returns a simulated translation for testing without an API key.
  Future<String> translate({
    required String text,
    required String targetLanguage,
    bool isMock = true, 
  }) async {
    if (isMock) {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      return _mockTranslation(text, targetLanguage);
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        body: jsonEncode({
          'q': text,
          'target': targetLanguage,
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['translations'][0]['translatedText'];
      } else {
        
        return text; // Return original on failure
      }
    } catch (e) {
      
      return text;
    }
  }

  // Simple mock translator for demo purposes
  String _mockTranslation(String text, String targetLang) {
    if (targetLang == 'si') return '$text (Sinha)';
    if (targetLang == 'es') return 'Hola ($text)';
    if (targetLang == 'fr') return 'Bonjour ($text)';
    return '$text [$targetLang]';
  }
}
