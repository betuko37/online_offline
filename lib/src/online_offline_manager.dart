import 'dart:async';
import 'storage/local_storage.dart';
import 'sync/sync_service.dart';
import 'connectivity/connectivity_service.dart';
import 'models/sync_status.dart';
import 'config/global_config.dart';
import 'cache/cache_manager.dart';

/// Manager super simple para offline-first
/// TODO SE INICIALIZA AUTOMÁTICAMENTE - Solo crear y usar
class OnlineOfflineManager {
  final String boxName;
  final String? endpoint;
  final bool enableAutoCleanup; // ← Nueva opción para habilitar limpieza automática
  
  // Servicios modulares
  late final LocalStorage _storage;
  late final SyncService _syncService;
  late final ConnectivityService _connectivity;
  
  // Stream de datos
  final _dataController = StreamController<List<Map<String, dynamic>>>.broadcast();
  
  // Control de inicialización
  bool _isInitialized = false;
  bool _isInitializing = false;
  final Completer<void> _initCompleter = Completer<void>();
  
  // Timer para sincronización automática
  Timer? _autoSyncTimer;
  
  // Getters simples
  Stream<List<Map<String, dynamic>>> get dataStream => _dataController.stream;
  Stream<SyncStatus> get statusStream => _syncService.statusStream;
  Stream<bool> get connectivityStream => _connectivity.connectivityStream;
  
  SyncStatus get status => _syncService.status;
  bool get isOnline => _connectivity.isOnline;
  
  OnlineOfflineManager({
    required this.boxName,
    this.endpoint,
    this.enableAutoCleanup = false, // ← Por defecto NO limpiar automáticamente
  }) {
    // Inicialización automática en background
    _autoInit();
  }
  
  /// Inicialización automática en background
  void _autoInit() {
    if (_isInitializing) return;
    _isInitializing = true;
    
    _init().then((_) {
      _isInitialized = true;
      _initCompleter.complete();
      // Manager inicializado automáticamente
    }).catchError((e) {
      print('❌ Error en inicialización automática: $e');
      _initCompleter.completeError(e);
    });
  }
  
  /// Asegura que esté inicializado antes de cualquier operación
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    if (!_initCompleter.isCompleted) {
      await _initCompleter.future;
    }
  }
  
  /// Inicialización interna
  Future<void> _init() async {
    try {
      // Inicializar servicios automáticamente
      _storage = LocalStorage(boxName: boxName);
      // No llamamos initialize() - se auto-inicializa en primer uso
      
      _connectivity = ConnectivityService();
      await _connectivity.initialize();
      
      _syncService = SyncService(
        storage: _storage,
        endpoint: endpoint,
      );
      
      // Auto-sync inteligente cuando hay conexión (siempre habilitado)
      if (GlobalConfig.syncOnReconnect) {
        bool _wasOffline = false;
        
        _connectivity.connectivityStream.listen((isOnline) async {
          if (isOnline && endpoint != null) {
            try {
              // Si estaba offline y ahora está online, forzar sincronización
              if (_wasOffline && GlobalConfig.syncOnReconnect) {
                await _forceSyncOnReconnect();
                _wasOffline = false;
              } else {
                // Sincronización normal basada en tiempo
                await _smartSync();
              }
              await _notifyData();
            } catch (e) {
              print('❌ Error en auto-sync: $e');
            }
          } else {
            // Marcar como offline
            _wasOffline = true;
          }
        });
      }
      
      // Configurar timer de sincronización automática
      _setupAutoSyncTimer();
      
      // Cargar datos iniciales
      await _notifyData();
      
    } catch (e) {
      print('❌ Error inicializando manager: $e');
      rethrow;
    }
  }
  
  /// ===========================================
  /// API SÚPER SIMPLE - SOLO 3 MÉTODOS
  /// ===========================================
  
  /// Obtener todos los datos con sincronización automática inteligente
  /// 
  /// Este es el método principal. Automáticamente:
  /// - Sincroniza datos pendientes hacia el servidor
  /// - Descarga datos nuevos/modificados del servidor
  /// - Limita automáticamente los registros locales
  /// - Retorna todos los datos (locales + sincronizados) ordenados por fecha
  /// - Funciona offline y online
  Future<List<Map<String, dynamic>>> getAll() async {
    await _ensureInitialized();
    
    try {
      // Sincronización automática si hay conexión y endpoint
      if (_connectivity.isOnline && endpoint != null) {
        await _smartSync();
      }
    } catch (e) {
      print('⚠️ Error en sincronización automática, usando datos locales: $e');
    }
    
    // Aplicar limitación automática de registros locales (solo si está habilitada)
    if (enableAutoCleanup) {
      await _applyLocalRecordLimit();
    }
    
    // Obtener todos los datos y ordenarlos por fecha
    final allData = await _storage.getAll();
    return _sortDataByDate(allData);
  }
  
  /// Obtener solo datos sincronizados (del servidor) ordenados por fecha
  Future<List<Map<String, dynamic>>> getSync() async {
    await _ensureInitialized();
    final syncedData = await _storage.where((item) => 
      item['sync'] == 'true' || item.containsKey('syncDate'));
    return _sortDataByDate(syncedData);
  }
  
  /// Obtener solo datos locales (pendientes de sincronización) ordenados por fecha
  Future<List<Map<String, dynamic>>> getLocal() async {
    await _ensureInitialized();
    final localData = await _storage.where((item) => 
      item['sync'] != 'true' && !item.containsKey('syncDate'));
    return _sortDataByDate(localData);
  }
  
  /// Obtener los últimos 50 registros por temporada ordenados por fecha
  Future<List<Map<String, dynamic>>> getLatestBySeason(String seasonId, {int limit = 50}) async {
    await _ensureInitialized();
    
    // Obtener todos los datos y filtrar por temporada
    final allData = await _storage.getAll();
    final seasonData = allData.where((item) => 
      item['seasonId'] == seasonId).toList();
    
    // Ordenar por fecha y tomar los últimos N registros
    final sortedData = _sortDataByDate(seasonData);
    return sortedData.take(limit).toList();
  }
  
  /// Obtener datos agrupados por temporada con los últimos 50 de cada una
  Future<Map<String, List<Map<String, dynamic>>>> getLatestByAllSeasons({int limit = 50}) async {
    await _ensureInitialized();
    
    final allData = await _storage.getAll();
    final Map<String, List<Map<String, dynamic>>> seasonGroups = {};
    
    // Agrupar por temporada
    for (final item in allData) {
      final seasonId = item['seasonId']?.toString();
      if (seasonId != null) {
        seasonGroups[seasonId] ??= [];
        seasonGroups[seasonId]!.add(item);
      }
    }
    
    // Ordenar cada grupo y tomar los últimos N registros
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in seasonGroups.entries) {
      final sortedData = _sortDataByDate(entry.value);
      result[entry.key] = sortedData.take(limit).toList();
    }
    
    return result;
  }
  
  /// Crear/guardar datos (se sincroniza automáticamente con getAll())
  Future<void> save(Map<String, dynamic> data) async {
    await _ensureInitialized();
    
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    data['created_at'] = DateTime.now().toIso8601String();
    data['sync'] = 'false';  // Marcar como pendiente de sincronización
    
    await _storage.save(id, data);
    await _notifyData();
    
    print('💾 Datos guardados localmente (se sincronizarán automáticamente)');
  }
  
  /// Eliminar datos (se sincroniza automáticamente con getAll())
  Future<void> delete(String id) async {
    await _ensureInitialized();
    await _storage.delete(id);
    await _notifyData();
    
    print('🗑️ Datos eliminados localmente (se sincronizarán automáticamente)');
  }
  
  /// ===========================================
  /// SINCRONIZACIÓN AUTOMÁTICA
  /// ===========================================
  
  /// Configura el timer de sincronización automática
  void _setupAutoSyncTimer() {
    // Cancelar timer anterior si existe
    _autoSyncTimer?.cancel();
    
    // Solo configurar timer si hay endpoint (sincronización automática siempre habilitada)
    if (endpoint != null) {
      _autoSyncTimer = Timer.periodic(Duration(minutes: GlobalConfig.syncMinutes), (timer) async {
        if (_connectivity.isOnline) {
          try {
            await _smartSync();
            await _notifyData();
          } catch (e) {
            print('❌ Error en sincronización por timer: $e');
          }
        }
      });
    }
  }
  
  /// Sincronización inteligente (solo si es necesario)
  Future<void> _smartSync() async {
    // Verificar si necesita sincronizar basado en el tiempo transcurrido
    final maxAge = Duration(minutes: GlobalConfig.syncMinutes);
    final shouldSync = await CacheManager.shouldSync(boxName, maxAge: maxAge);
    
    if (shouldSync) {
      print('🔄 Sincronización automática iniciada...');
      await _syncService.sync();
      await CacheManager.updateLastSyncTime(boxName);
      print('✅ Sincronización automática completada');
    } else {
      print('⏭️ Sincronización omitida (datos recientes)');
    }
  }
  
  /// Sincronización forzada cuando se recupera la conexión
  Future<void> _forceSyncOnReconnect() async {
    print('🔄 Recuperación de conexión detectada - sincronizando...');
    await _syncService.sync();
    await CacheManager.updateLastSyncTime(boxName);
    print('✅ Sincronización por reconexión completada');
  }
  
  /// Aplica limitación automática de registros (máximo 50 total)
  Future<void> _applyLocalRecordLimit() async {
    final maxRecords = GlobalConfig.maxLocalRecords; // 50 registros máximo
    final maxDays = GlobalConfig.maxDaysToKeep; // 3 días para registros sincronizados
    final allData = await _storage.getAll();
    
    print('📊 Aplicando limpieza automática de localStorage...');
    print('📊 Registros actuales: ${allData.length}');
    
    // 1. Eliminar registros sincronizados antiguos (más de 3 días)
    await _cleanOldSyncedRecords(maxDays);
    
    // 2. Si aún hay más de 50 registros, eliminar los más antiguos
    final remainingData = await _storage.getAll();
    if (remainingData.length > maxRecords) {
      await _limitToMaxRecords(maxRecords);
    }
    
    final finalData = await _storage.getAll();
    print('✅ Limpieza completada: ${allData.length} → ${finalData.length} registros');
  }
  
  /// Elimina registros sincronizados antiguos (más de X días)
  Future<void> _cleanOldSyncedRecords(int maxDays) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: maxDays));
    final allKeys = await _storage.getKeys();
    int deletedCount = 0;
    
    for (final key in allKeys) {
      final record = await _storage.get(key);
      if (record != null && 
          (record['sync'] == 'true' || record.containsKey('syncDate'))) {
        
        // Verificar fecha de sincronización
        final syncDate = DateTime.tryParse(record['syncDate'] ?? '') ?? 
                        DateTime.tryParse(record['created_at'] ?? '') ?? 
                        DateTime(1970);
        
        if (syncDate.isBefore(cutoffDate)) {
          await _storage.delete(key);
          deletedCount++;
        }
      }
    }
    
    if (deletedCount > 0) {
      print('🗑️ Eliminados $deletedCount registros sincronizados antiguos (más de $maxDays días)');
    }
  }
  
  /// Limita el total de registros al máximo especificado
  Future<void> _limitToMaxRecords(int maxRecords) async {
    final allData = await _storage.getAll();
    
    // Ordenar por fecha de creación (más recientes primero)
    allData.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });
    
    // Mantener solo los más recientes
    final recordsToDelete = allData.skip(maxRecords).toList();
    
    // Eliminar registros antiguos
    for (final record in recordsToDelete) {
      final keys = await _storage.getKeys();
      for (final key in keys) {
        final storedRecord = await _storage.get(key);
        if (storedRecord != null && 
            storedRecord['created_at'] == record['created_at']) {
          await _storage.delete(key);
          break;
        }
      }
    }
    
    if (recordsToDelete.length > 0) {
      print('🗑️ Eliminados ${recordsToDelete.length} registros antiguos (límite: $maxRecords)');
    }
  }
  
  /// Sincronizar con servidor (sincronización inteligente)
  Future<void> sync() async {
    await _ensureInitialized();
    
    if (_connectivity.isOnline && endpoint != null) {
      print('🔄 Sincronización manual iniciada...');
      await _syncService.sync();
      print('✅ Sincronización manual completada');
    } else {
      print('⚠️ Sin conexión - sincronización omitida');
    }
    
    await _notifyData();
  }
  
  /// Sincronización forzada (ignora caché y siempre sincroniza)
  Future<void> forceSync() async {
    await _ensureInitialized();
    
    if (_connectivity.isOnline && endpoint != null) {
      print('🔄 Sincronización forzada iniciada...');
      await _syncService.forceSync();
      print('✅ Sincronización forzada completada');
    } else {
      print('⚠️ Sin conexión - sincronización forzada omitida');
    }
    
    await _notifyData();
  }

  /// Sincronización inmediata (bypasa todas las verificaciones de tiempo)
  Future<void> syncNow() async {
    await _ensureInitialized();
    
    if (_connectivity.isOnline && endpoint != null) {
      print('🔄 Sincronización inmediata iniciada...');
      await _syncService.syncNow();
      print('✅ Sincronización inmediata completada');
    } else {
      print('⚠️ Sin conexión - sincronización inmediata omitida');
    }
    
    await _notifyData();
  }
  
  /// ===========================================
  /// UTILIDADES AUTO-INICIALIZADAS
  /// ===========================================
  
  /// Notificar cambios en datos
  Future<void> _notifyData() async {
    if (!_isInitialized) return; // No notificar si no está listo
    
    try {
      final data = await _storage.getAll();
      _dataController.add(data);
    } catch (e) {
      print('❌ Error notificando datos: $e');
    }
  }
  
  /// Limpiar todo (inicialización automática)
  Future<void> clear() async {
    await _ensureInitialized();
    await _storage.clear();
    await _notifyData();
  }
  
  /// Obtener solo pendientes (inicialización automática)
  Future<List<Map<String, dynamic>>> getPending() async {
    await _ensureInitialized();
    return await _storage.where((item) => 
      item['sync'] != 'true' && !item.containsKey('syncDate'));
  }
  
  /// Obtener solo sincronizados (inicialización automática)
  Future<List<Map<String, dynamic>>> getSynced() async {
    await _ensureInitialized();
    return await _storage.where((item) => 
      item['sync'] == 'true' || item.containsKey('syncDate'));
  }

  /// Limpiar registros duplicados
  Future<void> cleanDuplicates() async {
    await _ensureInitialized();
    await _syncService.cleanDuplicates();
    await _notifyData();
    print('✅ Limpieza de duplicados completada');
  }
  
  /// Ordena los datos por fecha (más recientes primero)
  /// Soporta múltiples formatos de fecha: date, timestamp, created_at, lastModifiedAt
  List<Map<String, dynamic>> _sortDataByDate(List<Map<String, dynamic>> data) {
    return List<Map<String, dynamic>>.from(data)..sort((a, b) {
      final dateA = _extractDateFromRecord(a);
      final dateB = _extractDateFromRecord(b);
      
      // Ordenar por fecha descendente (más recientes primero)
      return dateB.compareTo(dateA);
    });
  }
  
  /// Extrae la fecha de un registro usando múltiples campos posibles
  DateTime _extractDateFromRecord(Map<String, dynamic> record) {
    // Prioridad de campos de fecha
    final dateFields = ['date', 'lastModifiedAt', 'createdAt', 'created_at', 'timestamp'];
    
    for (final field in dateFields) {
      final value = record[field];
      if (value != null) {
        // Manejar timestamp numérico
        if (value is int || value is double) {
          try {
            return DateTime.fromMillisecondsSinceEpoch(value.toInt());
          } catch (e) {
            continue;
          }
        }
        
        // Manejar string de fecha
        if (value is String) {
          try {
            return DateTime.parse(value);
          } catch (e) {
            continue;
          }
        }
      }
    }
    
    // Si no se encuentra fecha válida, usar fecha muy antigua
    return DateTime(1970);
  }

  /// Cerrar recursos automáticamente
  void dispose() {
    _autoSyncTimer?.cancel();
    _dataController.close();
    _syncService.dispose();
    _connectivity.dispose();
    _storage.dispose();
  }
}