
/// Estrategias de resolución de conflictos
enum ConflictResolutionStrategy {
  lastWriteWins,    // El último en escribir gana
  firstWriteWins,   // El primero en escribir gana
  serverWins,       // El servidor siempre gana
  clientWins,       // El cliente siempre gana
  manual,           // Requiere intervención manual
  merge,            // Intenta fusionar los cambios
}

/// Información de un conflicto detectado
class ConflictInfo {
  final String id;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;
  final DateTime localTimestamp;
  final DateTime serverTimestamp;
  final String conflictReason;

  ConflictInfo({
    required this.id,
    required this.localData,
    required this.serverData,
    required this.localTimestamp,
    required this.serverTimestamp,
    required this.conflictReason,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'localData': localData,
    'serverData': serverData,
    'localTimestamp': localTimestamp.toIso8601String(),
    'serverTimestamp': serverTimestamp.toIso8601String(),
    'conflictReason': conflictReason,
  };
}

/// Resultado de la resolución de un conflicto
class ConflictResolution {
  final String id;
  final Map<String, dynamic> resolvedData;
  final ConflictResolutionStrategy strategy;
  final String reason;
  final bool wasResolved;

  ConflictResolution({
    required this.id,
    required this.resolvedData,
    required this.strategy,
    required this.reason,
    required this.wasResolved,
  });
}

/// Gestor de conflictos de sincronización
class ConflictManager {
  final ConflictResolutionStrategy defaultStrategy;
  final Map<String, ConflictResolutionStrategy> customStrategies;
  final List<ConflictInfo> conflicts = [];
  final List<ConflictResolution> resolutions = [];

  ConflictManager({
    this.defaultStrategy = ConflictResolutionStrategy.lastWriteWins,
    this.customStrategies = const {},
  });

  /// Detecta conflictos entre datos locales y del servidor
  List<ConflictInfo> detectConflicts(
    Map<String, dynamic> localData,
    Map<String, dynamic> serverData,
  ) {
    final conflicts = <ConflictInfo>[];
    
    // Buscar IDs que existen en ambos lados
    final commonIds = localData.keys.where((id) => serverData.containsKey(id));
    
    for (final id in commonIds) {
      final localItem = localData[id];
      final serverItem = serverData[id];
      
      // Verificar si hay conflicto
      if (_hasConflict(localItem, serverItem)) {
        final conflict = ConflictInfo(
          id: id,
          localData: localItem is Map ? Map<String, dynamic>.from(localItem) : {'value': localItem},
          serverData: serverItem is Map ? Map<String, dynamic>.from(serverItem) : {'value': serverItem},
          localTimestamp: _extractTimestamp(localItem, 'local'),
          serverTimestamp: _extractTimestamp(serverItem, 'server'),
          conflictReason: _getConflictReason(localItem, serverItem),
        );
        
        conflicts.add(conflict);
        
        print('🚨 Conflicto detectado para ID: $id');
        print('   Razón: ${conflict.conflictReason}');
        print('   Local: ${conflict.localTimestamp}');
        print('   Servidor: ${conflict.serverTimestamp}');
      }
    }
    
    return conflicts;
  }

  /// Resuelve un conflicto usando la estrategia especificada
  ConflictResolution resolveConflict(
    ConflictInfo conflict,
    ConflictResolutionStrategy? strategy,
  ) {
    final resolutionStrategy = strategy ?? 
                              customStrategies[conflict.id] ?? 
                              defaultStrategy;
    
    Map<String, dynamic> resolvedData;
    String reason;
    bool wasResolved = true;
    
    switch (resolutionStrategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        if (conflict.localTimestamp.isAfter(conflict.serverTimestamp)) {
          resolvedData = conflict.localData;
          reason = 'Local gana (último timestamp)';
        } else {
          resolvedData = conflict.serverData;
          reason = 'Servidor gana (último timestamp)';
        }
        break;
        
      case ConflictResolutionStrategy.firstWriteWins:
        if (conflict.localTimestamp.isBefore(conflict.serverTimestamp)) {
          resolvedData = conflict.localData;
          reason = 'Local gana (primer timestamp)';
        } else {
          resolvedData = conflict.serverData;
          reason = 'Servidor gana (primer timestamp)';
        }
        break;
        
      case ConflictResolutionStrategy.serverWins:
        resolvedData = conflict.serverData;
        reason = 'Servidor siempre gana';
        break;
        
      case ConflictResolutionStrategy.clientWins:
        resolvedData = conflict.localData;
        reason = 'Cliente siempre gana';
        break;
        
      case ConflictResolutionStrategy.merge:
        resolvedData = _mergeData(conflict.localData, conflict.serverData);
        reason = 'Datos fusionados automáticamente';
        break;
        
      case ConflictResolutionStrategy.manual:
        resolvedData = conflict.localData; // Mantener local hasta resolución manual
        reason = 'Requiere resolución manual';
        wasResolved = false;
        break;
    }
    
    final resolution = ConflictResolution(
      id: conflict.id,
      resolvedData: resolvedData,
      strategy: resolutionStrategy,
      reason: reason,
      wasResolved: wasResolved,
    );
    
    resolutions.add(resolution);
    
    print('✅ Conflicto resuelto para ID: ${conflict.id}');
    print('   Estrategia: $resolutionStrategy');
    print('   Razón: $reason');
    
    return resolution;
  }

  /// Resuelve todos los conflictos detectados
  List<ConflictResolution> resolveAllConflicts() {
    final resolvedList = <ConflictResolution>[];
    
    for (final conflict in conflicts) {
      final resolution = resolveConflict(conflict, null);
      resolvedList.add(resolution);
    }
    
    return resolvedList;
  }

  /// Fusiona datos de manera inteligente
  Map<String, dynamic> _mergeData(
    Map<String, dynamic> localData,
    Map<String, dynamic> serverData,
  ) {
    final merged = Map<String, dynamic>.from(serverData);
    
    // Fusionar campos que no existen en el servidor
    for (final entry in localData.entries) {
      if (!merged.containsKey(entry.key)) {
        merged[entry.key] = entry.value;
      } else if (entry.value is Map && merged[entry.key] is Map) {
        // Fusionar objetos anidados
        merged[entry.key] = _mergeData(
          entry.value as Map<String, dynamic>,
          merged[entry.key] as Map<String, dynamic>,
        );
      }
    }
    
    // Agregar metadatos de fusión
    merged['_merged_at'] = DateTime.now().toIso8601String();
    merged['_merged_from'] = 'local_and_server';
    
    return merged;
  }

  /// Verifica si hay conflicto entre dos elementos
  bool _hasConflict(dynamic localItem, dynamic serverItem) {
    // Si son diferentes tipos, hay conflicto
    if (localItem.runtimeType != serverItem.runtimeType) {
      return true;
    }
    
    // Si son mapas, comparar contenido
    if (localItem is Map && serverItem is Map) {
      return !_mapsEqual(Map<String, dynamic>.from(localItem), Map<String, dynamic>.from(serverItem));
    }
    
    // Si son valores primitivos, comparar directamente
    return localItem != serverItem;
  }

  /// Compara dos mapas de manera profunda
  bool _mapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    
    for (final entry in map1.entries) {
      if (!map2.containsKey(entry.key)) return false;
      
      final value1 = entry.value;
      final value2 = map2[entry.key];
      
      if (value1 is Map && value2 is Map) {
        if (!_mapsEqual(Map<String, dynamic>.from(value1), Map<String, dynamic>.from(value2))) return false;
      } else if (value1 != value2) {
        return false;
      }
    }
    
    return true;
  }

  /// Extrae timestamp de un elemento
  DateTime _extractTimestamp(dynamic item, String source) {
    if (item is Map) {
      // Buscar campos de timestamp comunes
      final timestampFields = [
        'timestamp', 'updated_at', 'modified_at', 'sync_timestamp',
        'created_at', 'last_modified', 'updatedAt', 'modifiedAt'
      ];
      
      for (final field in timestampFields) {
        if (item.containsKey(field)) {
          try {
            return DateTime.parse(item[field].toString());
          } catch (e) {
            continue;
          }
        }
      }
    }
    
    // Si no encuentra timestamp, usar timestamp actual
    return DateTime.now();
  }

  /// Obtiene la razón del conflicto
  String _getConflictReason(dynamic localItem, dynamic serverItem) {
    if (localItem.runtimeType != serverItem.runtimeType) {
      return 'Tipos de datos diferentes';
    }
    
    if (localItem is Map && serverItem is Map) {
      final localKeys = localItem.keys.toSet();
      final serverKeys = serverItem.keys.toSet();
      
      if (localKeys != serverKeys) {
        return 'Campos diferentes';
      }
      
      for (final key in localKeys) {
        if (localItem[key] != serverItem[key]) {
          return 'Valor diferente en campo: $key';
        }
      }
    }
    
    return 'Datos diferentes';
  }

  /// Obtiene estadísticas de conflictos
  Map<String, dynamic> getConflictStats() {
    return {
      'total_conflicts': conflicts.length,
      'resolved_conflicts': resolutions.where((r) => r.wasResolved).length,
      'unresolved_conflicts': resolutions.where((r) => !r.wasResolved).length,
      'strategies_used': resolutions.map((r) => r.strategy).toSet().toList(),
    };
  }

  /// Limpia el historial de conflictos
  void clearHistory() {
    conflicts.clear();
    resolutions.clear();
  }
}
