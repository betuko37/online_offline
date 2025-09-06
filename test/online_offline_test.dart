import 'package:flutter_test/flutter_test.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() {
  group('Pruebas de SyncConfig', () {
    test('debería crear SyncConfig con valores por defecto', () {
      const config = SyncConfig();
      
      expect(config.uploadEndpoint, '/items');
      expect(config.downloadEndpoint, '/items');
      expect(config.headers, {'Content-Type': 'application/json'});
    });

    test('debería crear SyncConfig personalizada', () {
      const config = SyncConfig(
        uploadEndpoint: '/api/users',
        downloadEndpoint: '/api/users',
        headers: {'Authorization': 'Bearer token'},
      );
      
      expect(config.uploadEndpoint, '/api/users');
      expect(config.downloadEndpoint, '/api/users');
      expect(config.headers, {'Authorization': 'Bearer token'});
    });
  });

  group('Pruebas de OnlineOfflineManager', () {
    test('debería crear SyncConfig con valores por defecto', () {
      const config = SyncConfig();
      
      expect(config.uploadEndpoint, '/items');
      expect(config.downloadEndpoint, '/items');
      expect(config.headers['Content-Type'], 'application/json');
      expect(config.timeout, Duration(seconds: 10));
      expect(config.syncInterval, Duration(minutes: 30));
    });

    test('debería crear SyncConfig personalizada', () {
      const config = SyncConfig(
        uploadEndpoint: '/api/users',
        downloadEndpoint: '/api/users',
        headers: {'Authorization': 'Bearer token'},
        timeout: Duration(seconds: 30),
        syncInterval: Duration(minutes: 15),
      );
      
      expect(config.uploadEndpoint, '/api/users');
      expect(config.downloadEndpoint, '/api/users');
      expect(config.headers['Authorization'], 'Bearer token');
      expect(config.timeout, Duration(seconds: 30));
      expect(config.syncInterval, Duration(minutes: 15));
    });

    test('debería verificar que OnlineOfflineManager es un tipo válido', () {
      expect(OnlineOfflineManager, isA<Type>());
    });
  });

  group('Pruebas de Integración', () {
    test('debería exportar las clases principales correctamente', () {
      // Prueba que las clases principales se exporten correctamente
      expect(OnlineOfflineManager, isA<Type>());
      expect(SyncConfig, isA<Type>());
    });
  });
}