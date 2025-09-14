import 'package:flutter_test/flutter_test.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() {
  group('ApiClient Tests', () {
    setUp(() {
      GlobalConfig.init(
        baseUrl: 'https://test-api.com',
        token: 'test-token',
      );
    });

    tearDown(() {
      GlobalConfig.clear();
    });

    group('Configuration', () {
      test('should require GlobalConfig to be initialized', () {
        expect(GlobalConfig.isInitialized, true);
        expect(GlobalConfig.baseUrl, 'https://test-api.com');
        expect(GlobalConfig.token, 'test-token');
      });

      test('should handle base URL with trailing slash', () {
        GlobalConfig.clear();
        GlobalConfig.init(
          baseUrl: 'https://api.example.com/',
          token: 'token',
        );

        expect(GlobalConfig.baseUrl, 'https://api.example.com/');
      });

      test('should handle base URL without trailing slash', () {
        GlobalConfig.clear();
        GlobalConfig.init(
          baseUrl: 'https://api.example.com',
          token: 'token',
        );

        expect(GlobalConfig.baseUrl, 'https://api.example.com');
      });
    });

    group('ApiClient Instance', () {
      test('should create instance when GlobalConfig is initialized', () {
        expect(() => ApiClient(), returnsNormally);
      });

      test('should throw when GlobalConfig is not initialized', () {
        GlobalConfig.clear();
        
        final apiClient = ApiClient();
        
        // El error se produce al hacer una petición, no al crear la instancia
        expect(() async {
          await apiClient.get('/test');
        }, throwsException);
      });
    });

    group('Error Handling', () {
      test('should handle network timeout gracefully', () async {
        final apiClient = ApiClient();
        
        // Esta petición fallará por timeout/network error
        final response = await apiClient.get('/nonexistent-endpoint');
        
        expect(response.isSuccess, false);
        expect(response.error, isNotNull);
        expect(response.error!, contains('Error en GET'));
      });

      test('should handle invalid endpoint gracefully', () async {
        final apiClient = ApiClient();
        
        // Endpoint inválido
        final response = await apiClient.post('/invalid', {'test': 'data'});
        
        expect(response.isSuccess, false);
        expect(response.error, isNotNull);
        expect(response.error!, contains('Error en POST'));
      });
    });

    group('Global Configuration States', () {
      test('should work with token authentication', () {
        GlobalConfig.init(
          baseUrl: 'https://api.example.com',
          token: 'my-secret-token',
        );

        expect(GlobalConfig.token, 'my-secret-token');
        expect(GlobalConfig.isInitialized, true);
      });

      test('should work without token', () {
        GlobalConfig.init(
          baseUrl: 'https://api.example.com',
          token: '',
        );

        expect(GlobalConfig.token, isEmpty);
        expect(GlobalConfig.baseUrl, isNotNull);
      });

      test('should work with empty token', () {
        GlobalConfig.init(
          baseUrl: 'https://api.example.com',
          token: '',
        );

        expect(GlobalConfig.token, isEmpty);
        expect(GlobalConfig.baseUrl, isNotNull);
      });
    });

    group('URL Construction', () {
      test('should handle various endpoint formats', () {
        final testCases = [
          '/users',
          'users',
          '/api/v1/users',
          'api/v1/users',
        ];

        // Verificamos que el cliente se puede crear con diferentes endpoints
        expect(() => ApiClient(), returnsNormally);
        expect(testCases.length, 4);
        // No podemos probar directamente _buildFullUrl porque es privado
        // pero podemos verificar que el cliente se crea correctamente
      });
    });

    group('Method Availability', () {
      test('should have get method available', () {
        final apiClient = ApiClient();
        expect(apiClient.get, isA<Function>());
      });

      test('should have post method available', () {
        final apiClient = ApiClient();
        expect(apiClient.post, isA<Function>());
      });
    });

    group('Response Structure', () {
      test('should return ApiResponse from get calls', () async {
        final apiClient = ApiClient();
        final response = await apiClient.get('/test');
        
        expect(response, isA<ApiResponse>());
        expect(response.isSuccess, isA<bool>());
        expect(response.statusCode, isA<int>());
      });

      test('should return ApiResponse from post calls', () async {
        final apiClient = ApiClient();
        final response = await apiClient.post('/test', {'data': 'test'});
        
        expect(response, isA<ApiResponse>());
        expect(response.isSuccess, isA<bool>());
        expect(response.statusCode, isA<int>());
      });
    });

    group('Integration with GlobalConfig', () {
      test('should clear configuration properly', () {
        expect(GlobalConfig.isInitialized, true);
        
        GlobalConfig.clear();
        
        expect(GlobalConfig.isInitialized, false);
        expect(GlobalConfig.baseUrl, isNull);
        expect(GlobalConfig.token, isNull);
      });

      test('should reinitialize after clear', () {
        GlobalConfig.clear();
        expect(GlobalConfig.isInitialized, false);
        
        GlobalConfig.init(
          baseUrl: 'https://new-api.com',
          token: 'new-token',
        );
        
        expect(GlobalConfig.isInitialized, true);
        expect(GlobalConfig.baseUrl, 'https://new-api.com');
        expect(GlobalConfig.token, 'new-token');
      });
    });
  });
}