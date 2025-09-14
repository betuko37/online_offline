import 'package:flutter_test/flutter_test.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() {
  group('GlobalConfig Tests', () {
    tearDown(() {
      // Limpiar configuración después de cada test
      GlobalConfig.clear();
    });

    test('should initialize correctly', () {
      GlobalConfig.init(
        baseUrl: 'https://test-api.com',
        token: 'test-token',
      );

      expect(GlobalConfig.isInitialized, true);
      expect(GlobalConfig.baseUrl, 'https://test-api.com');
      expect(GlobalConfig.token, 'test-token');
    });

    test('should clear configuration', () {
      GlobalConfig.init(
        baseUrl: 'https://test-api.com',
        token: 'test-token',
      );

      GlobalConfig.clear();

      expect(GlobalConfig.isInitialized, false);
      expect(GlobalConfig.baseUrl, null);
      expect(GlobalConfig.token, null);
    });

    test('should handle null values', () {
      GlobalConfig.init(
        baseUrl: 'https://test-api.com',
        token: 'test-token',
      );

      expect(GlobalConfig.baseUrl, isNotNull);
      expect(GlobalConfig.token, isNotNull);
    });
  });
}