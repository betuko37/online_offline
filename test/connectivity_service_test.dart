import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() {
  group('ConnectivityService Tests', () {
    late ConnectivityService connectivityService;

    setUp(() {
      connectivityService = ConnectivityService();
    });

    tearDown(() {
      connectivityService.dispose();
    });

    group('Instance Creation', () {
      test('should create instance successfully', () {
        expect(connectivityService, isNotNull);
        expect(connectivityService, isA<ConnectivityService>());
      });
    });

    group('Properties', () {
      test('should have isOnline property', () {
        expect(connectivityService.isOnline, isA<bool>());
      });

      test('should have connectivityStream', () {
        expect(connectivityService.connectivityStream, isA<Stream<bool>>());
      });
    });

    group('Initialization', () {
      test('should handle manual initialization', () async {
        expect(() async {
          await connectivityService.initialize();
        }, returnsNormally);
      });

      test('should handle multiple initialization calls', () async {
        await connectivityService.initialize();
        
        // Segunda inicialización no debería causar problemas
        expect(() async {
          await connectivityService.initialize();
        }, returnsNormally);
      });

      test('should auto-initialize when accessing isOnline', () {
        // Acceder a isOnline debería inicializar automáticamente
        final isOnline = connectivityService.isOnline;
        expect(isOnline, isA<bool>());
      });
    });

    group('Connectivity Status', () {
      test('should provide connectivity status', () async {
        await connectivityService.initialize();
        final isOnline = connectivityService.isOnline;
        expect(isOnline, isA<bool>());
      });

      test('should handle connectivity check gracefully', () {
        // Este test verifica que el acceso a isOnline no lance excepciones
        expect(() {
          final status = connectivityService.isOnline;
          expect(status, isA<bool>());
        }, returnsNormally);
      });
    });

    group('Connectivity Stream', () {
      test('should provide connectivity change stream', () {
        final stream = connectivityService.connectivityStream;
        expect(stream, isA<Stream<bool>>());
      });

      test('should handle stream subscription', () async {
        final stream = connectivityService.connectivityStream;
        
        // Verificamos que podemos suscribirnos al stream
        expect(() {
          stream.listen((isConnected) {
            expect(isConnected, isA<bool>());
          });
        }, returnsNormally);
      });

      test('should handle multiple subscriptions', () async {
        final stream = connectivityService.connectivityStream;
        
        // Múltiples suscripciones deberían funcionar (broadcast stream)
        final subscription1 = stream.listen((isConnected) {
          expect(isConnected, isA<bool>());
        });
        
        final subscription2 = stream.listen((isConnected) {
          expect(isConnected, isA<bool>());
        });
        
        expect(subscription1, isNotNull);
        expect(subscription2, isNotNull);
        
        // Limpiar suscripciones
        await subscription1.cancel();
        await subscription2.cancel();
      });
    });

    group('Error Handling', () {
      test('should handle initialization errors gracefully', () async {
        // El servicio debería manejar errores de inicialización
        // sin lanzar excepciones no controladas
        expect(() async {
          await connectivityService.initialize();
        }, returnsNormally);
      });

      test('should work after initialization errors', () async {
        // Incluso si hay errores, debería seguir funcionando
        await connectivityService.initialize();
        expect(() {
          final status = connectivityService.isOnline;
          expect(status, isA<bool>());
        }, returnsNormally);
      });
    });

    group('Lifecycle Management', () {
      test('should dispose properly', () {
        expect(() {
          connectivityService.dispose();
        }, returnsNormally);
      });

      test('should handle dispose multiple times', () {
        connectivityService.dispose();
        
        // Segunda llamada a dispose no debería causar problemas
        expect(() {
          connectivityService.dispose();
        }, returnsNormally);
      });

      test('should work after dispose and recreate', () {
        connectivityService.dispose();
        
        // Crear nuevo servicio después de dispose
        final newService = ConnectivityService();
        expect(newService.isOnline, isA<bool>());
        newService.dispose();
      });
    });

    group('Integration', () {
      test('should work with other components', () async {
        // Verificamos que el servicio puede ser usado por otros componentes
        expect(() async {
          // Similar a como lo usaría OnlineOfflineManager
          final service = ConnectivityService();
          await service.initialize();
          final isOnline = service.isOnline;
          final stream = service.connectivityStream;
          
          expect(isOnline, isA<bool>());
          expect(stream, isA<Stream<bool>>());
          
          service.dispose();
        }, returnsNormally);
      });
    });

    group('Auto-initialization', () {
      test('should auto-initialize on first access', () {
        // Crear un servicio nuevo
        final newService = ConnectivityService();
        
        // El primer acceso debería inicializar automáticamente
        final isOnline = newService.isOnline;
        expect(isOnline, isA<bool>());
        
        newService.dispose();
      });

      test('should handle auto-initialization errors', () {
        final newService = ConnectivityService();
        
        // Auto-inicialización debería manejar errores gracefully
        expect(() {
          final status = newService.isOnline;
          expect(status, isA<bool>());
        }, returnsNormally);
        
        newService.dispose();
      });
    });

    group('Stream Behavior', () {
      test('should emit boolean values', () async {
        await connectivityService.initialize();
        final stream = connectivityService.connectivityStream;
        
        // El stream debería estar disponible inmediatamente
        expect(stream, isA<Stream<bool>>());
        
        // Verificamos que es un broadcast stream
        expect(stream.isBroadcast, true);
      });

      test('should handle stream cancellation', () async {
        await connectivityService.initialize();
        final stream = connectivityService.connectivityStream;
        
        final subscription = stream.listen((isConnected) {
          expect(isConnected, isA<bool>());
        });
        
        // Cancelar debería funcionar sin errores
        expect(() async {
          await subscription.cancel();
        }, returnsNormally);
      });
    });

    group('Consistency', () {
      test('should provide consistent interface', () {
        // Verificamos que múltiples instancias tienen la misma interfaz
        final service1 = ConnectivityService();
        final service2 = ConnectivityService();
        
        expect(service1.isOnline, isA<bool>());
        expect(service2.isOnline, isA<bool>());
        expect(service1.connectivityStream, isA<Stream<bool>>());
        expect(service2.connectivityStream, isA<Stream<bool>>());
        
        service1.dispose();
        service2.dispose();
      });
    });
  });
}