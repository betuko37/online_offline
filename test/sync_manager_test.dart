import 'package:flutter_test/flutter_test.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() {
  group('Pruebas de SyncManager con múltiples tablas', () {
    late LocalDB localDB;
    late RemoteDB remoteDB;
    late SyncManager syncManager;

    setUp(() {
      localDB = LocalDB(databaseName: 'test_sync');
      remoteDB = RemoteDB(baseUrl: 'https://test.example.com/api');
      syncManager = SyncManager(
        local: localDB,
        remote: remoteDB,
        tableName: 'usuarios',
        endpoint: 'usuarios',
      );
    });

    test('debería crear SyncManager con configuración correcta', () {
      expect(syncManager.tableName, 'usuarios');
      expect(syncManager.endpoint, 'usuarios');
    });

    test('debería obtener estado de sincronización', () {
      final status = syncManager.getSyncStatus();
      
      expect(status['table_name'], 'usuarios');
      expect(status['endpoint'], 'usuarios');
      expect(status['local_items'], 0);
      expect(status['local_keys'], 0);
    });

    test('debería manejar diferentes tablas y endpoints', () {
      final syncManager2 = SyncManager(
        local: localDB,
        remote: remoteDB,
        tableName: 'productos',
        endpoint: 'api/products',
      );
      
      expect(syncManager2.tableName, 'productos');
      expect(syncManager2.endpoint, 'api/products');
    });

    test('debería crear SyncManager con tabla y endpoint diferentes', () {
      final syncManager3 = SyncManager(
        local: localDB,
        remote: remoteDB,
        tableName: 'configuraciones',
        endpoint: 'settings',
      );
      
      final status = syncManager3.getSyncStatus();
      expect(status['table_name'], 'configuraciones');
      expect(status['endpoint'], 'settings');
    });

    test('debería manejar nombres de tabla con caracteres especiales', () {
      final syncManager4 = SyncManager(
        local: localDB,
        remote: remoteDB,
        tableName: 'user-settings',
        endpoint: 'user-settings',
      );
      
      expect(syncManager4.tableName, 'user-settings');
      expect(syncManager4.endpoint, 'user-settings');
    });

    test('debería manejar endpoints con rutas completas', () {
      final syncManager5 = SyncManager(
        local: localDB,
        remote: remoteDB,
        tableName: 'pedidos',
        endpoint: 'api/v1/orders',
      );
      
      expect(syncManager5.endpoint, 'api/v1/orders');
    });

    test('debería manejar endpoints con parámetros', () {
      final syncManager6 = SyncManager(
        local: localDB,
        remote: remoteDB,
        tableName: 'reportes',
        endpoint: 'reports?type=monthly',
      );
      
      expect(syncManager6.endpoint, 'reports?type=monthly');
    });

    test('debería manejar tablas con números', () {
      final syncManager7 = SyncManager(
        local: localDB,
        remote: remoteDB,
        tableName: 'table_2024',
        endpoint: 'data/2024',
      );
      
      expect(syncManager7.tableName, 'table_2024');
      expect(syncManager7.endpoint, 'data/2024');
    });

    test('debería manejar endpoints con versiones', () {
      final syncManager8 = SyncManager(
        local: localDB,
        remote: remoteDB,
        tableName: 'usuarios_v2',
        endpoint: 'api/v2/users',
      );
      
      expect(syncManager8.tableName, 'usuarios_v2');
      expect(syncManager8.endpoint, 'api/v2/users');
    });

    test('debería manejar tablas con prefijos', () {
      final syncManager9 = SyncManager(
        local: localDB,
        remote: remoteDB,
        tableName: 'app_usuarios',
        endpoint: 'app/users',
      );
      
      expect(syncManager9.tableName, 'app_usuarios');
      expect(syncManager9.endpoint, 'app/users');
    });

    test('debería manejar endpoints con subdominios', () {
      final syncManager10 = SyncManager(
        local: localDB,
        remote: remoteDB,
        tableName: 'analytics',
        endpoint: 'analytics.mysite.com/data',
      );
      
      expect(syncManager10.endpoint, 'analytics.mysite.com/data');
    });
  });
}
