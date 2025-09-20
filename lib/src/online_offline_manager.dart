import 'dart:async';
import 'storage/local_storage.dart';
import 'sync/sync_service.dart';
import 'connectivity/connectivity_service.dart';
import 'models/sync_status.dart';
import 'config/sync_config.dart';
import 'config/global_config.dart';
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
  /// - Retorna todos los datos (locales + sincronizados)
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
    
    // Retornar todos los datos (locales + sincronizados)
    return await _storage.getAll();
  }
  
  /// Obtener solo datos sincronizados (del servidor)
  Future<List<Map<String, dynamic>>> getSync() async {
    await _ensureInitialized();
    return await _storage.where((item) => 
      item['sync'] == 'true' || item.containsKey('syncDate'));
  }
  
  /// Obtener solo datos locales (pendientes de sincronización)
  Future<List<Map<String, dynamic>>> getLocal() async {
    await _ensureInitialized();
    return await _storage.where((item) => 
      item['sync'] != 'true' && !item.containsKey('syncDate'));
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