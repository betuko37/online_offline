import '../local/local_db.dart';
import '../remote/remote_db.dart';
import 'conflict_manager.dart';

/// Gestor de sincronización entre base de datos local y remota
/// Maneja la sincronización de múltiples tablas con endpoints configurables
/// Incluye manejo robusto de conflictos
class SyncManager {
  final LocalDB local;
  final RemoteDB remote;
  final String tableName;
  final String endpoint;
  final ConflictManager conflictManager;

  SyncManager({
    required this.local,
    required this.remote,
    required this.tableName,
    required this.endpoint,
    ConflictResolutionStrategy conflictStrategy = ConflictResolutionStrategy.lastWriteWins,
    Map<String, ConflictResolutionStrategy> customStrategies = const {},
  }) : conflictManager = ConflictManager(
          defaultStrategy: conflictStrategy,
          customStrategies: customStrategies,
        );

  /// Sincroniza los datos entre la base de datos local y la remota
  Future<void> sync() async {
    try {
      print('🔄 Iniciando sincronización con manejo de conflictos...');
      
      // Asegurar que la tabla local existe
      await local.createTable(tableName);
      
      // 1. Obtener datos locales y remotos para comparación
      final localDataRaw = local.getAll(tableName);
      final localData = Map<String, dynamic>.from(localDataRaw);
      final remoteData = await _getRemoteDataAsMap();
      
      // 2. Detectar conflictos
      final conflicts = conflictManager.detectConflicts(localData, remoteData);
      
      if (conflicts.isNotEmpty) {
        print('🚨 Se detectaron ${conflicts.length} conflictos');
        await _handleConflicts(conflicts);
      } else {
        print('✅ No se detectaron conflictos');
      }
      
      // 3. Subir datos locales al servidor (después de resolver conflictos)
      await _uploadLocalData();
      
      // 4. Descargar datos del servidor a local (datos actualizados)
      await _downloadRemoteData();
      
      print('✅ Sincronización completada exitosamente para tabla: $tableName');
    } catch (e) {
      print('❌ Error en sincronización: $e');
      rethrow;
    }
  }

  /// Sube todos los datos locales al servidor
  Future<void> _uploadLocalData() async {
    final localData = local.getAll(tableName);
    
    if (localData.isNotEmpty) {
      print('Subiendo ${localData.length} elementos locales al servidor...');
      
      for (final entry in localData.entries) {
        try {
          await remote.upload(endpoint, {
            'id': entry.key.toString(),
            'value': entry.value,
            'table': tableName,
            'sync_timestamp': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          print('Error subiendo elemento ${entry.key}: $e');
          // Continuar con el siguiente elemento
        }
      }
    }
  }

  /// Descarga todos los datos del servidor a local
  Future<void> _downloadRemoteData() async {
    try {
      print('Descargando datos del servidor...');
      final remoteData = await remote.fetchAll(endpoint);
      
      if (remoteData.isNotEmpty) {
        print('Descargando ${remoteData.length} elementos del servidor...');
        
        for (final item in remoteData) {
          try {
            final id = item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
            final value = item['value'] ?? item;
            
            await local.put(tableName, id, value);
          } catch (e) {
            print('Error descargando elemento: $e');
            // Continuar con el siguiente elemento
          }
        }
      }
    } catch (e) {
      print('Error descargando datos del servidor: $e');
      // No re-lanzar el error para permitir que la sincronización continúe
    }
  }

  /// Sincroniza solo datos específicos
  Future<void> syncItem(String id, Map<String, dynamic> data) async {
    try {
      // Subir al servidor
      await remote.upload(endpoint, {
        'id': id,
        'value': data,
        'table': tableName,
        'sync_timestamp': DateTime.now().toIso8601String(),
      });
      
      // Guardar localmente
      await local.put(tableName, id, data);
      
      print('Elemento $id sincronizado exitosamente');
    } catch (e) {
      print('Error sincronizando elemento $id: $e');
      rethrow;
    }
  }

  /// Obtiene el estado de sincronización
  Map<String, dynamic> getSyncStatus() {
    return {
      'table_name': tableName,
      'endpoint': endpoint,
      'local_items': local.getTableSize(tableName),
      'local_keys': local.getKeys(tableName).length,
    };
  }

  /// Limpia los datos locales de la tabla
  Future<void> clearLocalData() async {
    await local.clearTable(tableName);
    print('Datos locales de la tabla $tableName eliminados');
  }

  /// Fuerza una sincronización completa (limpia y vuelve a sincronizar)
  Future<void> forceSync() async {
    print('🔄 Iniciando sincronización forzada...');
    await clearLocalData();
    await sync();
    print('✅ Sincronización forzada completada');
  }

  /// Obtiene datos remotos como mapa para comparación
  Future<Map<String, dynamic>> _getRemoteDataAsMap() async {
    try {
      final remoteData = await remote.fetchAll(endpoint);
      final Map<String, dynamic> remoteMap = {};
      
      for (final item in remoteData) {
        final id = item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
        remoteMap[id] = item;
      }
      
      return remoteMap;
    } catch (e) {
      print('⚠️ Error obteniendo datos remotos: $e');
      return {};
    }
  }

  /// Maneja los conflictos detectados
  Future<void> _handleConflicts(List<ConflictInfo> conflicts) async {
    print('🔧 Resolviendo ${conflicts.length} conflictos...');
    
    for (final conflict in conflicts) {
      try {
        // Resolver conflicto
        final resolution = conflictManager.resolveConflict(conflict, null);
        
        if (resolution.wasResolved) {
          // Actualizar datos locales con la resolución
          await local.put(tableName, conflict.id, resolution.resolvedData);
          print('✅ Conflicto resuelto para ID: ${conflict.id}');
        } else {
          print('⚠️ Conflicto requiere resolución manual para ID: ${conflict.id}');
          // Mantener datos locales hasta resolución manual
        }
      } catch (e) {
        print('❌ Error resolviendo conflicto ${conflict.id}: $e');
        // Continuar con el siguiente conflicto
      }
    }
    
    // Mostrar estadísticas
    final stats = conflictManager.getConflictStats();
    print('📊 Estadísticas de conflictos:');
    print('   Total: ${stats['total_conflicts']}');
    print('   Resueltos: ${stats['resolved_conflicts']}');
    print('   Pendientes: ${stats['unresolved_conflicts']}');
  }

  /// Resuelve un conflicto específico manualmente
  Future<void> resolveConflictManually(
    String id,
    Map<String, dynamic> resolvedData,
  ) async {
    try {
      await local.put(tableName, id, resolvedData);
      print('✅ Conflicto resuelto manualmente para ID: $id');
    } catch (e) {
      print('❌ Error resolviendo conflicto manual: $e');
      rethrow;
    }
  }

  /// Obtiene información de conflictos pendientes
  List<ConflictInfo> getPendingConflicts() {
    return conflictManager.conflicts.where((conflict) {
      final resolutions = conflictManager.resolutions.where((r) => r.id == conflict.id);
      return resolutions.isEmpty || resolutions.any((r) => !r.wasResolved);
    }).toList();
  }

  /// Obtiene estadísticas de conflictos
  Map<String, dynamic> getConflictStats() {
    return conflictManager.getConflictStats();
  }

  /// Limpia el historial de conflictos
  void clearConflictHistory() {
    conflictManager.clearHistory();
  }
}
