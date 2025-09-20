import 'dart:async';
import 'storage/local_storage.dart';
import 'sync/sync_service.dart';
import 'connectivity/connectivity_service.dart';
import 'models/sync_status.dart';
import 'config/sync_config.dart';
import 'cache/cache_manager.dart';

/// Manager super simple para offline-first
/// TODO SE INICIALIZA AUTOMÁTICAMENTE - Solo crear y usar
class OnlineOfflineManager {
  final String boxName;
  final String? endpoint;
  final SyncConfig syncConfig;
  
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
    this.syncConfig = SyncConfig.occasional, // Por defecto datos ocasionales
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
      
      // Auto-sync inteligente cuando hay conexión (solo si está configurado)
      if (syncConfig.autoSyncOnConnectivityChange) {
        _connectivity.connectivityStream.listen((isOnline) async {
          if (isOnline && endpoint != null) {
            try {
              await _smartSync();
              await _notifyData();
            } catch (e) {
              print('❌ Error en auto-sync: $e');
            }
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
  /// OPERACIONES BÁSICAS (AUTO-INICIALIZADAS)
  /// ===========================================
  
  /// Crear/guardar datos (inicialización automática)
  Future<void> save(Map<String, dynamic> data) async {
    await _ensureInitialized();
    
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    data['created_at'] = DateTime.now().toIso8601String();
    // Marcar como pendiente de sincronización
    data['sync'] = 'false';  // String en lugar de bool
    
    await _storage.save(id, data);
    await _notifyData();
    
    // Datos guardados localmente
    
    // Auto-sync inteligente si hay internet (solo si está configurado)
    if (syncConfig.autoSyncOnSave && _connectivity.isOnline && endpoint != null) {
      _smartSync().then((_) {
        _notifyData();
      }).catchError((e) {
        print('❌ Error en auto-sync: $e');
      });
    }
  }
  
  /// Obtener por ID (inicialización automática)
  Future<Map<String, dynamic>?> getById(String id) async {
    await _ensureInitialized();
    return await _storage.get(id);
  }
  
  /// Obtener todos (inicialización automática)
  Future<List<Map<String, dynamic>>> getAll() async {
    await _ensureInitialized();
    return await _storage.getAll();
  }

  /// Obtener datos directamente del servidor (sin cache)
  Future<List<Map<String, dynamic>>> getFromServer() async {
    await _ensureInitialized();
    
    if (!_connectivity.isOnline) {
      throw Exception('Sin conexión a internet');
    }
    
    if (endpoint == null) {
      throw Exception('No hay endpoint configurado');
    }
    
    try {
      return await _syncService.getDirectFromServer();
    } catch (e) {
      print('❌ Error obteniendo datos del servidor: $e');
      rethrow;
    }
  }

  /// Obtener todos con sincronización inteligente
  Future<List<Map<String, dynamic>>> getAllWithSync() async {
    await _ensureInitialized();
    
    try {
      // Sincronización inteligente solo si está configurado y es necesario
      if (syncConfig.autoSyncOnGet && _connectivity.isOnline && endpoint != null) {
        await _smartSync();
      }
    } catch (e) {
      print('⚠️ Error en sincronización, usando datos locales: $e');
    }
    
    // Retornar datos locales (que incluirán los sincronizados)
    return await _storage.getAll();
  }
  
  /// Obtener todos sin sincronización automática (más rápido)
  Future<List<Map<String, dynamic>>> getAllFast() async {
    await _ensureInitialized();
    return await _storage.getAll();
  }

  /// Eliminar (inicialización automática)
  Future<void> delete(String id) async {
    await _ensureInitialized();
    await _storage.delete(id);
    await _notifyData();
    
    // Auto-sync después de eliminar (solo si está configurado)
    if (syncConfig.autoSyncOnDelete && _connectivity.isOnline && endpoint != null) {
      _smartSync().then((_) {
        _notifyData();
      }).catchError((e) {
        print('❌ Error en auto-sync: $e');
      });
    }
  }
  
  /// ===========================================
  /// SINCRONIZACIÓN AUTOMÁTICA
  /// ===========================================
  
  /// Configura el timer de sincronización automática
  void _setupAutoSyncTimer() {
    // Cancelar timer anterior si existe
    _autoSyncTimer?.cancel();
    
    // Solo configurar timer si hay endpoint y está configurado para sincronización automática
    if (endpoint != null && syncConfig.autoSyncOnGet) {
      _autoSyncTimer = Timer.periodic(syncConfig.maxCacheAge, (timer) async {
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
    if (!syncConfig.useSmartSync) {
      await _syncService.sync();
      await CacheManager.updateLastSyncTime(boxName);
      return;
    }
    
    // Verificar si necesita sincronizar basado en el tiempo transcurrido
    final shouldSync = await CacheManager.shouldSync(boxName, maxAge: syncConfig.maxCacheAge);
    
    if (shouldSync) {
      await _syncService.sync();
      await CacheManager.updateLastSyncTime(boxName);
    }
  }
  
  /// Sincronizar con servidor (fuerza sincronización)
  Future<void> sync() async {
    await _ensureInitialized();
    await _syncService.sync();
    await CacheManager.updateLastSyncTime(boxName);
    await _notifyData();
  }
  
  /// Sincronización forzada (ignora caché)
  Future<void> forceSync() async {
    await _ensureInitialized();
    await _syncService.sync();
    await CacheManager.updateLastSyncTime(boxName);
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
  
  /// Cerrar recursos automáticamente
  void dispose() {
    _autoSyncTimer?.cancel();
    _dataController.close();
    _syncService.dispose();
    _connectivity.dispose();
    _storage.dispose();
  }
}