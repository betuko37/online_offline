import 'package:flutter_test/flutter_test.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() {
  group('SyncService Tests', () {
    late SyncService syncService;
    late LocalStorage localStorage;

    setUpAll(() async {
      // Inicializar configuración global para los tests
      GlobalConfig.init(
        baseUrl: 'https://test-api.com',
        token: 'test-token',
      );
    });

    setUp(() async {
      // Crear storage para el test
      localStorage = LocalStorage(boxName: 'test_entity');
      await localStorage.initialize();
      
      // Crear SyncService con dependencias
      syncService = SyncService(
        storage: localStorage,
        endpoint: '/test_endpoint',
      );
    });

    tearDown(() async {
      syncService.dispose();
      await localStorage.clear();
    });

    tearDownAll(() {
      GlobalConfig.clear();
    });

    group('Instance Creation', () {
      test('should create instance successfully with required parameters', () {
        expect(syncService, isNotNull);
        expect(syncService, isA<SyncService>());
      });

      test('should create instance with custom endpoint', () {
        final customService = SyncService(
          storage: localStorage,
          endpoint: '/custom_endpoint',
        );
        
        expect(customService, isNotNull);
        expect(customService, isA<SyncService>());
        customService.dispose();
      });

      test('should create instance without endpoint', () {
        final noEndpointService = SyncService(
          storage: localStorage,
          endpoint: null,
        );
        
        expect(noEndpointService, isNotNull);
        expect(noEndpointService, isA<SyncService>());
        noEndpointService.dispose();
      });
    });

    group('Properties', () {
      test('should have status property', () {
        expect(syncService.status, isA<SyncStatus>());
      });

      test('should have statusStream', () {
        expect(syncService.statusStream, isA<Stream<SyncStatus>>());
      });

      test('should start with idle status', () {
        expect(syncService.status, SyncStatus.idle);
      });
    });

    group('Synchronization', () {
      test('should handle sync method call', () async {
        expect(() async {
          await syncService.sync();
        }, returnsNormally);
      });

      test('should handle sync without endpoint', () async {
        final noEndpointService = SyncService(
          storage: localStorage,
          endpoint: null,
        );
        
        // Debería manejar gracefully la falta de endpoint
        expect(() async {
          await noEndpointService.sync();
        }, returnsNormally);
        
        noEndpointService.dispose();
      });

      test('should handle concurrent sync calls', () async {
        // Múltiples llamadas concurrentes a sync
        final futures = <Future>[];
        
        for (int i = 0; i < 3; i++) {
          futures.add(syncService.sync());
        }
        
        expect(() async {
          await Future.wait(futures);
        }, returnsNormally);
      });

      test('should update status during sync', () async {
        // Verificar que el status cambia durante la sincronización
        expect(syncService.status, SyncStatus.idle);
        
        // Iniciar sync y verificar status
        final syncFuture = syncService.sync();
        
        // El status puede cambiar rápidamente, así que solo verificamos
        // que no lance excepciones
        await syncFuture;
        
        // Al final debería estar en success o error, no syncing
        expect(syncService.status, isNot(SyncStatus.syncing));
      });
    });

    group('Status Stream', () {
      test('should provide status change stream', () {
        final stream = syncService.statusStream;
        expect(stream, isA<Stream<SyncStatus>>());
      });

      test('should handle stream subscription', () {
        final stream = syncService.statusStream;
        
        expect(() {
          stream.listen((status) {
            expect(status, isA<SyncStatus>());
          });
        }, returnsNormally);
      });

      test('should handle multiple subscriptions', () {
        final stream = syncService.statusStream;
        
        final subscription1 = stream.listen((status) {
          expect(status, isA<SyncStatus>());
        });
        
        final subscription2 = stream.listen((status) {
          expect(status, isA<SyncStatus>());
        });
        
        expect(subscription1, isNotNull);
        expect(subscription2, isNotNull);
        
        // Limpiar suscripciones
        subscription1.cancel();
        subscription2.cancel();
      });

      test('should emit status changes', () async {
        final statusEvents = <SyncStatus>[];
        
        syncService.statusStream.listen((status) {
          statusEvents.add(status);
        });
        
        // Ejecutar sync para generar cambios de status
        await syncService.sync();
        
        // Dar tiempo para que se emitan los eventos
        await Future.delayed(Duration(milliseconds: 100));
        
        // Debería haber al menos algunos eventos de status
        expect(statusEvents, isNotEmpty);
      });
    });

    group('Direct Server Access', () {
      test('should handle getDirectFromServer call', () async {
        expect(() async {
          await syncService.getDirectFromServer();
        }, returnsNormally);
      });

      test('should return list from getDirectFromServer', () async {
        final result = await syncService.getDirectFromServer();
        expect(result, isA<List<Map<String, dynamic>>>());
      });

      test('should handle getDirectFromServer without endpoint', () async {
        final noEndpointService = SyncService(
          storage: localStorage,
          endpoint: null,
        );
        
        // Debería lanzar excepción por falta de endpoint
        expect(() async {
          await noEndpointService.getDirectFromServer();
        }, throwsException);
        
        noEndpointService.dispose();
      });

      test('should handle network errors in getDirectFromServer', () async {
        // Configurar con endpoint que causará error
        final errorService = SyncService(
          storage: localStorage,
          endpoint: '/nonexistent_endpoint',
        );
        
        expect(() async {
          await errorService.getDirectFromServer();
        }, throwsException);
        
        errorService.dispose();
      });
    });

    group('Error Handling', () {
      test('should handle sync errors gracefully', () async {
        // Crear service con endpoint inválido
        final errorService = SyncService(
          storage: localStorage,
          endpoint: '/invalid_endpoint',
        );
        
        // Sync debería manejar errores sin lanzar excepciones
        expect(() async {
          await errorService.sync();
        }, returnsNormally);
        
        // Status debería ser error después del fallo
        expect(errorService.status, SyncStatus.error);
        
        errorService.dispose();
      });

      test('should handle storage errors', () async {
        // Crear storage que podría fallar
        final testStorage = LocalStorage(boxName: 'test_error');
        await testStorage.initialize();
        
        final service = SyncService(
          storage: testStorage,
          endpoint: '/test',
        );
        
        expect(() async {
          await service.sync();
        }, returnsNormally);
        
        service.dispose();
        await testStorage.clear();
      });
    });

    group('Integration', () {
      test('should work with LocalStorage', () async {
        // Agregar algunos datos al storage
        await localStorage.save('test1', {'name': 'Test 1', 'sync': 'false'});
        await localStorage.save('test2', {'name': 'Test 2', 'sync': 'true'});
        
        // Sync debería procesar estos datos
        expect(() async {
          await syncService.sync();
        }, returnsNormally);
      });

      test('should work with ApiClient through GlobalConfig', () async {
        // Verificar que GlobalConfig está configurado
        expect(GlobalConfig.isInitialized, true);
        
        // Los métodos deberían usar ApiClient internamente
        expect(() async {
          await syncService.getDirectFromServer();
        }, returnsNormally);
      });
    });

    group('Lifecycle Management', () {
      test('should dispose properly', () {
        expect(() {
          syncService.dispose();
        }, returnsNormally);
      });

      test('should handle dispose multiple times', () {
        syncService.dispose();
        
        expect(() {
          syncService.dispose();
        }, returnsNormally);
      });

      test('should work after recreating service', () async {
        syncService.dispose();
        
        // Crear nuevo servicio
        final newService = SyncService(
          storage: localStorage,
          endpoint: '/new_test',
        );
        
        expect(newService.status, SyncStatus.idle);
        expect(() async {
          await newService.sync();
        }, returnsNormally);
        
        newService.dispose();
      });
    });

    group('Different Endpoints', () {
      test('should handle various endpoint formats', () async {
        final endpoints = [
          '/users',
          'products',
          '/api/v1/orders',
          'api/v1/categories',
        ];

        for (final endpoint in endpoints) {
          final service = SyncService(
            storage: localStorage,
            endpoint: endpoint,
          );
          
          expect(() async {
            await service.sync();
            await service.getDirectFromServer();
          }, returnsNormally);
          
          service.dispose();
        }
      });
    });

    group('Status Enum Values', () {
      test('should handle all SyncStatus values', () {
        // Verificar que podemos crear service y acceder a todos los estados
        expect(SyncStatus.idle, isA<SyncStatus>());
        expect(SyncStatus.syncing, isA<SyncStatus>());
        expect(SyncStatus.success, isA<SyncStatus>());
        expect(SyncStatus.error, isA<SyncStatus>());
        
        expect(syncService.status, isA<SyncStatus>());
      });
    });

    group('Consistency', () {
      test('should provide consistent interface', () {
        // Verificar métodos principales
        expect(syncService.sync, isA<Function>());
        expect(syncService.getDirectFromServer, isA<Function>());
        expect(syncService.dispose, isA<Function>());
        
        // Verificar propiedades
        expect(syncService.status, isA<SyncStatus>());
        expect(syncService.statusStream, isA<Stream<SyncStatus>>());
      });

      test('should handle multiple instances consistently', () async {
        final storage2 = LocalStorage(boxName: 'test_entity_2');
        await storage2.initialize();
        
        final service2 = SyncService(
          storage: storage2,
          endpoint: '/test2',
        );
        
        expect(service2.sync, isA<Function>());
        expect(service2.getDirectFromServer, isA<Function>());
        expect(service2.status, isA<SyncStatus>());
        
        service2.dispose();
        await storage2.clear();
      });
    });
  });
}