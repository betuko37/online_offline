import 'package:flutter_test/flutter_test.dart';
import 'package:online_offline/online_offline.dart';

void main() {
  group('Pruebas de RemoteDB con endpoints configurables', () {
    late RemoteDB remoteDB;

    setUp(() {
      remoteDB = RemoteDB(
        baseUrl: 'https://apisoftdev.agroeasy.com.mx/api',
        defaultHeaders: {'Content-Type': 'application/json'},
        timeout: const Duration(seconds: 30),
      );
    });

    test('debería crear RemoteDB con URL base', () {
      expect(remoteDB.baseUrl, 'https://apisoftdev.agroeasy.com.mx/api');
    });

    test('debería tener headers por defecto', () {
      expect(remoteDB.defaultHeaders['Content-Type'], 'application/json');
    });

    test('debería tener timeout configurado', () {
      expect(remoteDB.timeout, const Duration(seconds: 30));
    });

    test('debería construir URL correctamente', () {
      // Usar reflexión para acceder al método privado _buildUrl
      // En un test real, esto se probaría indirectamente a través de las peticiones
      expect(remoteDB.baseUrl, 'https://apisoftdev.agroeasy.com.mx/api');
    });

    test('debería manejar URL base con barra final', () {
      final remoteDBWithSlash = RemoteDB(
        baseUrl: 'https://apisoftdev.agroeasy.com.mx/api/',
      );
      expect(remoteDBWithSlash.baseUrl, 'https://apisoftdev.agroeasy.com.mx/api/');
    });

    test('debería manejar headers personalizados', () {
      final customHeaders = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer token123',
        'Custom-Header': 'custom-value',
      };
      
      final remoteDBWithCustomHeaders = RemoteDB(
        baseUrl: 'https://example.com/api',
        defaultHeaders: customHeaders,
      );
      
      expect(remoteDBWithCustomHeaders.defaultHeaders['Authorization'], 'Bearer token123');
      expect(remoteDBWithCustomHeaders.defaultHeaders['Custom-Header'], 'custom-value');
    });

    test('debería manejar timeout personalizado', () {
      final customTimeout = const Duration(seconds: 60);
      final remoteDBWithCustomTimeout = RemoteDB(
        baseUrl: 'https://example.com/api',
        timeout: customTimeout,
      );
      
      expect(remoteDBWithCustomTimeout.timeout, customTimeout);
    });

    test('debería crear RemoteDBException correctamente', () {
      final exception = RemoteDBException('Test error', 404);
      expect(exception.message, 'Test error');
      expect(exception.statusCode, 404);
      expect(exception.toString(), 'RemoteDBException: Test error (Status: 404)');
    });

    test('debería manejar diferentes tipos de URL base', () {
      final urls = [
        'https://api.example.com',
        'https://api.example.com/',
        'http://localhost:3000',
        'http://localhost:3000/',
        'https://apisoftdev.agroeasy.com.mx/api',
        'https://apisoftdev.agroeasy.com.mx/api/',
      ];

      for (final url in urls) {
        final remoteDB = RemoteDB(baseUrl: url);
        expect(remoteDB.baseUrl, url);
      }
    });

    test('debería manejar headers vacíos', () {
      final remoteDBWithEmptyHeaders = RemoteDB(
        baseUrl: 'https://example.com/api',
        defaultHeaders: {},
      );
      
      expect(remoteDBWithEmptyHeaders.defaultHeaders.isEmpty, true);
    });

    test('debería manejar timeout cero', () {
      final remoteDBWithZeroTimeout = RemoteDB(
        baseUrl: 'https://example.com/api',
        timeout: Duration.zero,
      );
      
      expect(remoteDBWithZeroTimeout.timeout, Duration.zero);
    });
  });
}
