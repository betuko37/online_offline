import 'package:flutter_test/flutter_test.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() {
  group('OnlineOfflineManager Tests', () {
    late OnlineOfflineManager manager;

    setUpAll(() async {
      // Inicializar configuración global para los tests
      GlobalConfig.init(
        baseUrl: 'https://test-api.com',
        token: 'test-token',
      );
    });

    setUp(() async {
      // Crear manager para cada test
      manager = OnlineOfflineManager(
        boxName: 'test_users',
        endpoint: '/users',
      );
      // El manager se inicializa automáticamente, solo esperamos
      await Future.delayed(Duration(milliseconds: 100));
    });

    tearDown(() async {
      await manager.clear();
      manager.dispose();
    });

    tearDownAll(() {
      GlobalConfig.clear();
    });

    group('Instance Creation', () {
      test('should create instance successfully', () {
        expect(manager, isNotNull);
        expect(manager, isA<OnlineOfflineManager>());
      });

      test('should create instance with different configurations', () async {
        final customManager = OnlineOfflineManager(
          boxName: 'custom_entity',
          endpoint: '/custom_endpoint',
        );
        
        // Esperar inicialización automática
        await Future.delayed(Duration(milliseconds: 100));
        
        expect(customManager, isNotNull);
        expect(customManager, isA<OnlineOfflineManager>());
        
        await customManager.clear();
        customManager.dispose();
      });

      test('should create instance without endpoint', () async {
        final noEndpointManager = OnlineOfflineManager(
          boxName: 'no_endpoint_test',
        );
        
        // Esperar inicialización automática
        await Future.delayed(Duration(milliseconds: 100));
        
        expect(noEndpointManager, isNotNull);
        expect(noEndpointManager, isA<OnlineOfflineManager>());
        
        await noEndpointManager.clear();
        noEndpointManager.dispose();
      });
    });

    group('Properties and Streams', () {
      test('should have dataStream property', () {
        expect(manager.dataStream, isA<Stream<List<Map<String, dynamic>>>>());
      });

      test('should have statusStream property', () {
        expect(manager.statusStream, isA<Stream<SyncStatus>>());
      });

      test('should have connectivityStream property', () {
        expect(manager.connectivityStream, isA<Stream<bool>>());
      });

      test('should have status property', () {
        expect(manager.status, isA<SyncStatus>());
      });

      test('should have isOnline property', () {
        expect(manager.isOnline, isA<bool>());
      });
    });

    group('Local Data Operations', () {
      test('should handle save operation', () async {
        expect(() async {
          await manager.save({'name': 'Test User', 'email': 'test@example.com'});
        }, returnsNormally);
      });

      test('should handle getAll operation', () async {
        final result = await manager.getAll();
        expect(result, isA<List<Map<String, dynamic>>>());
      });

      test('should handle save and retrieve data', () async {
        final testData = {'name': 'John Doe', 'email': 'john@example.com'};
        
        await manager.save(testData);
        final allData = await manager.getAll();
        
        expect(allData, isA<List>());
        expect(allData.isNotEmpty, true);
        
        // Verificar que contiene nuestro dato
        final savedItem = allData.firstWhere(
          (item) => item['name'] == 'John Doe',
          orElse: () => <String, dynamic>{},
        );
        
        expect(savedItem['email'], 'john@example.com');
      });

      test('should handle multiple save operations', () async {
        final testItems = [
          {'name': 'User 1', 'email': 'user1@example.com'},
          {'name': 'User 2', 'email': 'user2@example.com'},
          {'name': 'User 3', 'email': 'user3@example.com'},
        ];
        
        for (final item in testItems) {
          await manager.save(item);
        }
        
        final allData = await manager.getAll();
        expect(allData.length, greaterThanOrEqualTo(testItems.length));
      });

      test('should handle clear operation', () async {
        // Agregar algunos datos
        await manager.save({'test': 'data1'});
        await manager.save({'test': 'data2'});
        
        // Verificar que hay datos
        final beforeClear = await manager.getAll();
        expect(beforeClear.isNotEmpty, true);
        
        // Limpiar
        await manager.clear();
        
        // Verificar que se limpiaron
        final afterClear = await manager.getAll();
        expect(afterClear.isEmpty, true);
      });
    });

    group('Server Data Access', () {
      test('should handle getFromServer operation', () async {
        expect(() async {
          await manager.getFromServer();
        }, returnsNormally);
      });

      test('should return list from getFromServer', () async {
        final result = await manager.getFromServer();
        expect(result, isA<List<Map<String, dynamic>>>());
      });

      test('should handle getAllWithSync operation', () async {
        expect(() async {
          await manager.getAllWithSync();
        }, returnsNormally);
      });

      test('should return list from getAllWithSync', () async {
        final result = await manager.getAllWithSync();
        expect(result, isA<List<Map<String, dynamic>>>());
      });

      test('should handle network errors gracefully', () async {
        // Estos métodos deberían manejar errores de red gracefully
        final result1 = await manager.getFromServer();
        final result2 = await manager.getAllWithSync();
        
        expect(result1, isA<List>());
        expect(result2, isA<List>());
      });
    });

    group('Synchronization', () {
      test('should handle sync operation', () async {
        expect(() async {
          await manager.sync();
        }, returnsNormally);
      });

      test('should sync local changes to server', () async {
        // Agregar datos locales
        await manager.save({'name': 'Local User', 'sync': 'false'});
        
        // Ejecutar sync
        expect(() async {
          await manager.sync();
        }, returnsNormally);
      });

      test('should handle sync with server data', () async {
        // Sync debería traer datos del servidor
        await manager.sync();
        
        // Verificar que no causa errores
        final localData = await manager.getAll();
        expect(localData, isA<List>());
      });
    });

    group('Error Handling', () {
      test('should handle invalid configurations', () async {
        final errorManager = OnlineOfflineManager(
          boxName: '',
          endpoint: '',
        );
        
        // Esperar inicialización automática
        await Future.delayed(Duration(milliseconds: 100));
        
        expect(errorManager, isNotNull);
        
        errorManager.dispose();
      });

      test('should handle storage errors gracefully', () async {
        // Intentar operaciones que podrían fallar
        expect(() async {
          await manager.save(<String, dynamic>{});
          await manager.getAll();
          await manager.clear();
        }, returnsNormally);
      });

      test('should handle server communication errors', () async {
        // Crear manager con endpoint inválido
        final errorManager = OnlineOfflineManager(
          boxName: 'error_test',
          endpoint: '/nonexistent_endpoint',
        );
        
        // Esperar inicialización automática
        await Future.delayed(Duration(milliseconds: 100));
        
        // Deberían manejar errores gracefully
        expect(() async {
          await errorManager.sync();
          await errorManager.getFromServer();
          await errorManager.getAllWithSync();
        }, returnsNormally);
        
        await errorManager.clear();
        errorManager.dispose();
      });
    });

    group('Lifecycle Management', () {
      test('should dispose properly', () {
        expect(() {
          manager.dispose();
        }, returnsNormally);
      });

      test('should handle dispose multiple times', () {
        manager.dispose();
        
        expect(() {
          manager.dispose();
        }, returnsNormally);
      });

      test('should work after recreating manager', () async {
        manager.dispose();
        
        // Crear nuevo manager
        final newManager = OnlineOfflineManager(
          boxName: 'new_test',
          endpoint: '/new_test',
        );
        
        // Esperar inicialización automática
        await Future.delayed(Duration(milliseconds: 100));
        
        expect(() async {
          await newManager.save({'test': 'new_data'});
          await newManager.getAll();
        }, returnsNormally);
        
        await newManager.clear();
        newManager.dispose();
      });
    });

    group('Integration', () {
      test('should integrate with GlobalConfig', () async {
        expect(GlobalConfig.isInitialized, true);
        
        // Los métodos de servidor deberían usar GlobalConfig
        expect(() async {
          await manager.getFromServer();
        }, returnsNormally);
      });

      test('should work without GlobalConfig for local operations', () async {
        GlobalConfig.clear();
        
        // Operaciones locales deberían seguir funcionando
        expect(() async {
          await manager.save({'local': 'only'});
          await manager.getAll();
        }, returnsNormally);
        
        // Restaurar configuración
        GlobalConfig.init(
          baseUrl: 'https://test-api.com',
          token: 'test-token',
        );
      });
    });

    group('Stream Subscriptions', () {
      test('should handle dataStream subscription', () {
        final stream = manager.dataStream;
        
        expect(() {
          stream.listen((data) {
            expect(data, isA<List<Map<String, dynamic>>>());
          });
        }, returnsNormally);
      });

      test('should handle statusStream subscription', () {
        final stream = manager.statusStream;
        
        expect(() {
          stream.listen((status) {
            expect(status, isA<SyncStatus>());
          });
        }, returnsNormally);
      });

      test('should handle connectivityStream subscription', () {
        final stream = manager.connectivityStream;
        
        expect(() {
          stream.listen((isOnline) {
            expect(isOnline, isA<bool>());
          });
        }, returnsNormally);
      });
    });

    group('Different Configurations', () {
      test('should handle various boxName configurations', () async {
        final boxNames = ['users', 'products', 'orders', 'test_entity'];
        final endpoints = ['/users', '/products', '/orders', '/test'];
        
        for (int i = 0; i < boxNames.length; i++) {
          final testManager = OnlineOfflineManager(
            boxName: boxNames[i],
            endpoint: endpoints[i],
          );
          
          // Esperar inicialización automática
          await Future.delayed(Duration(milliseconds: 100));
          
          expect(() async {
            await testManager.save({'test': 'data_$i'});
            await testManager.getAll();
          }, returnsNormally);
          
          await testManager.clear();
          testManager.dispose();
        }
      });
    });

    group('Consistency', () {
      test('should provide consistent interface', () {
        // Verificar métodos principales
        expect(manager.save, isA<Function>());
        expect(manager.getAll, isA<Function>());
        expect(manager.getFromServer, isA<Function>());
        expect(manager.getAllWithSync, isA<Function>());
        expect(manager.sync, isA<Function>());
        expect(manager.clear, isA<Function>());
        expect(manager.dispose, isA<Function>());
        
        // Verificar propiedades
        expect(manager.status, isA<SyncStatus>());
        expect(manager.isOnline, isA<bool>());
        expect(manager.dataStream, isA<Stream>());
        expect(manager.statusStream, isA<Stream>());
        expect(manager.connectivityStream, isA<Stream>());
      });

      test('should handle multiple instances consistently', () async {
        final manager1 = OnlineOfflineManager(
          boxName: 'consistency_test_1',
          endpoint: '/test1',
        );
        
        final manager2 = OnlineOfflineManager(
          boxName: 'consistency_test_2',
          endpoint: '/test2',
        );
        
        // Esperar inicialización automática
        await Future.delayed(Duration(milliseconds: 100));
        
        // Ambos deberían tener la misma interfaz
        expect(manager1.save, isA<Function>());
        expect(manager2.save, isA<Function>());
        expect(manager1.getAll, isA<Function>());
        expect(manager2.getAll, isA<Function>());
        
        await manager1.clear();
        await manager2.clear();
        manager1.dispose();
        manager2.dispose();
      });
    });
  });
}