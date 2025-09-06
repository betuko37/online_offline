import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_offline_sync/flutter_offline_sync.dart';

void main() {
  group('Pruebas de ConflictManager', () {
    late ConflictManager conflictManager;

    setUp(() {
      conflictManager = ConflictManager(
        defaultStrategy: ConflictResolutionStrategy.lastWriteWins,
      );
    });

    test('debería crear ConflictManager con estrategia por defecto', () {
      expect(conflictManager.defaultStrategy, ConflictResolutionStrategy.lastWriteWins);
    });

    test('debería crear ConflictManager con estrategias personalizadas', () {
      final customStrategies = {
        'user_1': ConflictResolutionStrategy.serverWins,
        'user_2': ConflictResolutionStrategy.merge,
      };
      
      final manager = ConflictManager(
        defaultStrategy: ConflictResolutionStrategy.firstWriteWins,
        customStrategies: customStrategies,
      );
      
      expect(manager.defaultStrategy, ConflictResolutionStrategy.firstWriteWins);
      expect(manager.customStrategies['user_1'], ConflictResolutionStrategy.serverWins);
      expect(manager.customStrategies['user_2'], ConflictResolutionStrategy.merge);
    });

    test('debería detectar conflictos entre datos locales y remotos', () {
      final localData = {
        'user_1': {
          'id': 'user_1',
          'nombre': 'Juan Local',
          'email': 'juan.local@email.com',
          'timestamp': '2024-01-15T10:00:00.000Z',
        },
        'user_2': {
          'id': 'user_2',
          'nombre': 'María',
          'email': 'maria@email.com',
          'timestamp': '2024-01-15T10:00:00.000Z',
        },
      };
      
      final serverData = {
        'user_1': {
          'id': 'user_1',
          'nombre': 'Juan Server',
          'email': 'juan.server@email.com',
          'timestamp': '2024-01-15T11:00:00.000Z',
        },
        'user_2': {
          'id': 'user_2',
          'nombre': 'María',
          'email': 'maria@email.com',
          'timestamp': '2024-01-15T10:00:00.000Z',
        },
      };
      
      final conflicts = conflictManager.detectConflicts(localData, serverData);
      
      expect(conflicts.length, 1);
      expect(conflicts[0].id, 'user_1');
      expect(conflicts[0].conflictReason, 'Campos diferentes');
    });

    test('debería resolver conflicto con estrategia lastWriteWins', () {
      final conflict = ConflictInfo(
        id: 'user_1',
        localData: {
          'nombre': 'Juan Local',
          'timestamp': '2024-01-15T10:00:00.000Z',
        },
        serverData: {
          'nombre': 'Juan Server',
          'timestamp': '2024-01-15T11:00:00.000Z',
        },
        localTimestamp: DateTime.parse('2024-01-15T10:00:00.000Z'),
        serverTimestamp: DateTime.parse('2024-01-15T11:00:00.000Z'),
        conflictReason: 'Valor diferente en campo: nombre',
      );
      
      final resolution = conflictManager.resolveConflict(conflict, null);
      
      expect(resolution.id, 'user_1');
      expect(resolution.strategy, ConflictResolutionStrategy.lastWriteWins);
      expect(resolution.wasResolved, true);
      expect(resolution.reason, 'Servidor gana (último timestamp)');
    });

    test('debería resolver conflicto con estrategia serverWins', () {
      final conflict = ConflictInfo(
        id: 'user_1',
        localData: {'nombre': 'Juan Local'},
        serverData: {'nombre': 'Juan Server'},
        localTimestamp: DateTime.now(),
        serverTimestamp: DateTime.now(),
        conflictReason: 'Valor diferente en campo: nombre',
      );
      
      final resolution = conflictManager.resolveConflict(
        conflict, 
        ConflictResolutionStrategy.serverWins,
      );
      
      expect(resolution.strategy, ConflictResolutionStrategy.serverWins);
      expect(resolution.reason, 'Servidor siempre gana');
      expect(resolution.resolvedData, conflict.serverData);
    });

    test('debería resolver conflicto con estrategia clientWins', () {
      final conflict = ConflictInfo(
        id: 'user_1',
        localData: {'nombre': 'Juan Local'},
        serverData: {'nombre': 'Juan Server'},
        localTimestamp: DateTime.now(),
        serverTimestamp: DateTime.now(),
        conflictReason: 'Valor diferente en campo: nombre',
      );
      
      final resolution = conflictManager.resolveConflict(
        conflict, 
        ConflictResolutionStrategy.clientWins,
      );
      
      expect(resolution.strategy, ConflictResolutionStrategy.clientWins);
      expect(resolution.reason, 'Cliente siempre gana');
      expect(resolution.resolvedData, conflict.localData);
    });

    test('debería resolver conflicto con estrategia merge', () {
      final conflict = ConflictInfo(
        id: 'user_1',
        localData: {
          'nombre': 'Juan Local',
          'telefono': '123456789',
        },
        serverData: {
          'nombre': 'Juan Server',
          'email': 'juan@email.com',
        },
        localTimestamp: DateTime.now(),
        serverTimestamp: DateTime.now(),
        conflictReason: 'Valor diferente en campo: nombre',
      );
      
      final resolution = conflictManager.resolveConflict(
        conflict, 
        ConflictResolutionStrategy.merge,
      );
      
      expect(resolution.strategy, ConflictResolutionStrategy.merge);
      expect(resolution.reason, 'Datos fusionados automáticamente');
      expect(resolution.resolvedData['nombre'], 'Juan Server');
      expect(resolution.resolvedData['telefono'], '123456789');
      expect(resolution.resolvedData['email'], 'juan@email.com');
    });

    test('debería manejar conflicto manual', () {
      final conflict = ConflictInfo(
        id: 'user_1',
        localData: {'nombre': 'Juan Local'},
        serverData: {'nombre': 'Juan Server'},
        localTimestamp: DateTime.now(),
        serverTimestamp: DateTime.now(),
        conflictReason: 'Valor diferente en campo: nombre',
      );
      
      final resolution = conflictManager.resolveConflict(
        conflict, 
        ConflictResolutionStrategy.manual,
      );
      
      expect(resolution.strategy, ConflictResolutionStrategy.manual);
      expect(resolution.reason, 'Requiere resolución manual');
      expect(resolution.wasResolved, false);
    });

    test('debería obtener estadísticas de conflictos', () {
      // Crear algunos conflictos
      final conflict1 = ConflictInfo(
        id: 'user_1',
        localData: {'nombre': 'Juan Local'},
        serverData: {'nombre': 'Juan Server'},
        localTimestamp: DateTime.now(),
        serverTimestamp: DateTime.now(),
        conflictReason: 'Conflicto 1',
      );
      
      final conflict2 = ConflictInfo(
        id: 'user_2',
        localData: {'nombre': 'María Local'},
        serverData: {'nombre': 'María Server'},
        localTimestamp: DateTime.now(),
        serverTimestamp: DateTime.now(),
        conflictReason: 'Conflicto 2',
      );
      
      // Resolver conflictos
      conflictManager.resolveConflict(conflict1, ConflictResolutionStrategy.serverWins);
      conflictManager.resolveConflict(conflict2, ConflictResolutionStrategy.manual);
      
      final stats = conflictManager.getConflictStats();
      
      expect(stats['total_conflicts'], 0); // Los conflictos se detectan pero no se almacenan en la lista
      expect(stats['resolved_conflicts'], 1);
      expect(stats['unresolved_conflicts'], 1);
      expect(stats['strategies_used'], contains(ConflictResolutionStrategy.serverWins));
      expect(stats['strategies_used'], contains(ConflictResolutionStrategy.manual));
    });

    test('debería limpiar historial de conflictos', () {
      // Crear conflicto
      final conflict = ConflictInfo(
        id: 'user_1',
        localData: {'nombre': 'Juan Local'},
        serverData: {'nombre': 'Juan Server'},
        localTimestamp: DateTime.now(),
        serverTimestamp: DateTime.now(),
        conflictReason: 'Conflicto',
      );
      
      conflictManager.resolveConflict(conflict, null);
      
      expect(conflictManager.conflicts.length, 0); // Los conflictos no se almacenan automáticamente
      expect(conflictManager.resolutions.length, 1);
      
      conflictManager.clearHistory();
      
      expect(conflictManager.conflicts.length, 0);
      expect(conflictManager.resolutions.length, 0);
    });
  });
}
