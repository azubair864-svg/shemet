import 'package:flutter_test/flutter_test.dart';
import 'package:dating_live_app/services/translation_service.dart';

void main() {
  group('TranslationService Tests', () {
    late TranslationService service;

    setUp(() {
      service = TranslationService();
    });

    test('Mock translation returns expected format for Sinhala', () async {
      final result = await service.translate(
        text: 'Hello',
        targetLanguage: 'si',
        isMock: true,
      );
      expect(result, 'Hello (Sinha)');
    });

    test('Mock translation returns expected format for Spanish', () async {
      final result = await service.translate(
        text: 'Hello',
        targetLanguage: 'es',
        isMock: true,
      );
      expect(result, 'Hola (Hello)');
    });

    test('Mock translation fallback works', () async {
      final result = await service.translate(
        text: 'Hello',
        targetLanguage: 'xx',
        isMock: true,
      );
      expect(result, 'Hello [xx]');
    });
  });
}
