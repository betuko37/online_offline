import 'dart:async';
import 'storage/local_storage.dart';
import 'sync/sync_service.dart';
import 'connectivity/connectivity_service.dart';
import 'models/sync_status.dart';
import 'config/global_config.dart';
import 'cache/cache_manager.dart';
import 'utils/hive_utils.dart';

/// Manager súper simple para offline-first
/// 
/// USO SIMPLIFICADO:
/// ```dart
/// // 1. Configurar una vez al inicio de la app
/// GlobalConfig.init(baseUrl: 'https://api.com', token: 'tu-token');
/// 
/// // 2. Crear managers para cada tipo de dato
/// final reportes = OnlineOfflineManager(boxName: 'reportes', endpoint: '/api/reportes');
/// final usuarios = OnlineOfflineManager(boxName: 'usuarios', endpoint: '/api/usuarios');
/// 
/// // 3. Obtener datos (SIEMPRE devuelve datos locales)
/// final datos = await reportes.get();
/// 
/// // 4. Cuando el usuario quiera actualizar, llamar syncAll
/// await OnlineOfflineManager.syncAll();
/// ```
/// 
/// SINCRONIZACIÓN AUTOMÁTICA:
/// - Se ejecuta automáticamente cada 10 minutos cuando hay internet
/// - Se ejecuta automáticamente cuando se recupera la conexión a internet
class OnlineOfflineManager {
  // Registro estático de managers activos
  static final Set<OnlineOfflineManager> _activeManagers = {};
  
  // Auto-sync variables
  static Timer? _autoSyncTimer;
  static StreamSubscription<bool>? _connectivitySubscription;
  static bool _autoSyncInitialized = false;
  static bool _lastKnownOnlineState = false;
  static bool _isHandlingReconnection = false; // 🔒 Flag para prevenir múltiples reconexiones simultáneas
  static bool _isSyncingAll = false; // 🔒 Flag para prevenir múltiples ejecuciones simultáneas de syncAll()
  
  final String boxName;
  final String? endpoint;
  final bool uploadEnabled; // Si es false, solo hace GET (download), no POST (upload)
  
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
  
  // Getters simples
  Stream<List<Map<String, dynamic>>> get dataStream => _dataController.stream;
  Stream<SyncStatus> get statusStream => _syncService.statusStream;
  Stream<bool> get connectivityStream => _connectivity.connectivityStream;
  
  SyncStatus get status => _syncService.status;
  bool get isOnline => _connectivity.isOnline;
  
  /// Constructor súper simple
  /// 
  /// Solo necesitas:
  /// - `boxName`: Nombre único para almacenar datos localmente
  /// - `endpoint`: URL del API (opcional si solo usas almacenamiento local)
  /// - `uploadEnabled`: Si es false, solo hace GET (descarga), no POST (subida). Default: false
  OnlineOfflineManager({
    required this.boxName,
    this.endpoint,
    this.uploadEnabled = false,
  }) {
    // Registrar este manager en el conjunto de activos
    _activeManagers.add(this);
    
    // Inicialización automática en background
    _autoInit();
    
    // Inicializar auto-sync cuando se crea el primer manager
    _initAutoSync();
  }
  
  /// Inicializa sincronización automática (solo una vez)
  static void _initAutoSync() {
    if (_autoSyncInitialized) return;
    _autoSyncInitialized = true;
    
    print('🔄 [AutoSync] Inicializando sincronización automática...');
    
    // Timer periódico cada 10 minutos
    final syncInterval = Duration(minutes: GlobalConfig.syncMinutes);
    _autoSyncTimer = Timer.periodic(syncInterval, (_) async {
      // Solo sincronizar si hay managers activos y hay internet
      if (_activeManagers.isEmpty) return;
      
      // Usar el estado global de conectividad
      if (ConnectivityService.globalIsOnline) {
        print('🔄 Auto-sync: ejecutando sincronización periódica (cada ${GlobalConfig.syncMinutes} min)...');
        await syncAll();
      }
    });
    
    // Escuchar cambios de conectividad para sync al reconectar
    // No esperamos aquí para no bloquear la inicialización
    _setupConnectivityListener();
    
    print('✅ [AutoSync] Sincronización automática inicializada');
  }
  
  /// Configura el listener de conectividad para sync al reconectar
  static Future<void> _setupConnectivityListener() async {
    print('🔌 [AutoSync] Configurando listener de conectividad...');
    
    // Inicializar el servicio de conectividad global
    await ConnectivityService.initializeGlobal();
    
    // Guardar estado inicial
    _lastKnownOnlineState = ConnectivityService.globalIsOnline;
    print('🔌 [AutoSync] Estado inicial: ${_lastKnownOnlineState ? "online" : "offline"}');
    
    // Escuchar cambios de conectividad usando el stream GLOBAL
    _connectivitySubscription = ConnectivityService.globalConnectivityStream.listen((isOnline) async {
      print('🔌 [AutoSync] Cambio detectado: ${isOnline ? "online" : "offline"} (anterior: ${_lastKnownOnlineState ? "online" : "offline"})');
      
      // Detectar reconexión (de offline a online)
      if (isOnline && !_lastKnownOnlineState) {
        await _handleReconnection();
      }
      _lastKnownOnlineState = isOnline;
    });
    
    print('✅ [AutoSync] Listener de conectividad configurado');
  }
  
  /// Maneja la reconexión con delay y verificación de conexión real
  /// 
  /// 🔒 PROTECCIÓN: Evita múltiples ejecuciones simultáneas con flag estático
  static Future<void> _handleReconnection() async {
    // 🔒 Prevenir múltiples reconexiones simultáneas
    if (_isHandlingReconnection) {
      print('⚠️ [AutoSync] Reconexión ya en proceso, ignorando...');
      return;
    }
    
    _isHandlingReconnection = true;
    
    try {
      final delaySeconds = GlobalConfig.reconnectDelaySeconds;
      final verifyReal = GlobalConfig.verifyRealConnection;
      
      print('🔄 Auto-sync: conexión detectada, esperando ${delaySeconds}s para estabilizar...');
      
      // Esperar a que la conexión se estabilice
      await Future.delayed(Duration(seconds: delaySeconds));
    
    // Verificar conexión real si está habilitado
    if (verifyReal) {
      print('🔍 Verificando conexión real...');
      
      // Usar la API del usuario como primer endpoint de verificación
      final customUrl = GlobalConfig.baseUrl;
      final hasReal = await ConnectivityService.hasRealConnection(
        customUrl: customUrl,
        timeout: const Duration(seconds: 10),
      );
      
      if (!hasReal) {
        print('⚠️ Auto-sync: conexión no estable, reintentando en ${delaySeconds}s...');
        // Reintentar una vez más con timeout más largo
        await Future.delayed(Duration(seconds: delaySeconds));
        final hasRealRetry = await ConnectivityService.hasRealConnection(
          customUrl: customUrl,
          timeout: const Duration(seconds: 15),
        );
        
        if (!hasRealRetry) {
          print('❌ Auto-sync: no hay conexión real a internet, cancelando sync');
          print('💡 Tip: Si crees que tienes internet, intenta sincronizar manualmente');
          return;
        }
      }
      print('✅ Conexión real verificada');
    }
    
    print('🔄 Auto-sync: conexión recuperada, sincronizando...');
    await syncAll();
    } finally {
      // 🔒 Liberar flag después de completar (o fallar)
      _isHandlingReconnection = false;
    }
  }
  
  /// Detiene la sincronización automática
  static void disposeAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _autoSyncInitialized = false;
    _lastKnownOnlineState = false;
  }
  
  /// Inicialización automática en background
  void _autoInit() {
    if (_isInitializing) return;
    _isInitializing = true;
    
    _init().then((_) {
      _isInitialized = true;
      _initCompleter.complete();
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
      _storage = LocalStorage(boxName: boxName);
      
      _connectivity = ConnectivityService();
      await _connectivity.initialize();
      
      _syncService = SyncService(
        storage: _storage,
        endpoint: endpoint,
        onSyncComplete: _notifyData,
        uploadEnabled: uploadEnabled,
      );
      
      // Cargar datos iniciales
      await _notifyData();
      
    } catch (e) {
      print('❌ Error inicializando manager: $e');
      rethrow;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // API SÚPER SIMPLE - SOLO 3 MÉTODOS PRINCIPALES
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Obtener todos los datos locales
  /// 
  /// SIEMPRE retorna datos locales inmediatamente.
  /// Si quieres datos actualizados del servidor, llama a `syncAll()` primero.
  /// 
  /// Ejemplo:
  /// ```dart
  /// final datos = await manager.get();
  /// ```
  Future<List<Map<String, dynamic>>> get() async {
    await _ensureInitialized();
    final allData = await _storage.getAll();
    return _sortDataByDate(allData);
  }
  
  /// Guardar datos localmente
  /// 
  /// Los datos se guardan localmente y se marcan como pendientes de sincronización.
  /// Cuando llames a `syncAll()`, se subirán al servidor.
  /// 
  /// Ejemplo:
  /// ```dart
  /// await manager.save({'nombre': 'Juan', 'edad': 25});
  /// ```
  Future<void> save(Map<String, dynamic> data) async {
    await _ensureInitialized();
    
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    data['created_at'] = DateTime.now().toIso8601String();
    data['sync'] = 'false';
    
    await _storage.save(id, data);
    await _notifyData();
  }
  
  /// Eliminar datos
  /// 
  /// Elimina datos del almacenamiento local.
  /// 
  /// Ejemplo:
  /// ```dart
  /// await manager.delete('local_1234567890');
  /// ```
  Future<void> delete(String id) async {
    await _ensureInitialized();
    await _storage.delete(id);
    await _notifyData();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTODOS PARA VER ESTADO DE SINCRONIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Obtener solo datos SINCRONIZADOS (que vienen del servidor)
  /// 
  /// Ejemplo:
  /// ```dart
  /// final sincronizados = await manager.getSynced();
  /// print('Tienes ${sincronizados.length} registros del servidor');
  /// ```
  Future<List<Map<String, dynamic>>> getSynced() async {
    await _ensureInitialized();
    final synced = await _storage.where((item) => 
      item['sync'] == 'true' || item.containsKey('syncDate'));
    return _sortDataByDate(synced);
  }
  
  /// Obtener solo datos PENDIENTES (no sincronizados con el servidor)
  /// 
  /// Ejemplo:
  /// ```dart
  /// final pendientes = await manager.getPending();
  /// print('Tienes ${pendientes.length} registros por sincronizar');
  /// ```
  Future<List<Map<String, dynamic>>> getPending() async {
    await _ensureInitialized();
    final pending = await _storage.where((item) => 
      item['sync'] != 'true' && !item.containsKey('syncDate'));
    return _sortDataByDate(pending);
  }
  
  /// Obtener resumen del estado de sincronización (solo contadores)
  /// 
  /// Retorna un objeto con contadores de sincronización.
  /// 
  /// Ejemplo:
  /// ```dart
  /// final info = await manager.getSyncInfo();
  /// print('Total: ${info.total}');
  /// print('Sincronizados: ${info.synced}');
  /// print('Pendientes: ${info.pending}');
  /// ```
  Future<SyncInfo> getSyncInfo() async {
    await _ensureInitialized();
    final allData = await _storage.getAll();
    final synced = allData.where((item) => 
      item['sync'] == 'true' || item.containsKey('syncDate')).length;
    final pending = allData.length - synced;
    
    return SyncInfo(
      total: allData.length,
      synced: synced,
      pending: pending,
    );
  }
  
  /// Obtener TODO: datos + contadores organizados
  /// 
  /// Retorna una estructura con:
  /// - Lista de todos los datos
  /// - Lista de sincronizados
  /// - Lista de pendientes
  /// - Contadores
  /// 
  /// Ejemplo:
  /// ```dart
  /// final data = await manager.getFullData();
  /// 
  /// print('Total: ${data.all.length}');
  /// print('Sincronizados: ${data.synced.length}');
  /// print('Pendientes: ${data.pending.length}');
  /// 
  /// // Ver datos sincronizados
  /// for (final item in data.synced) {
  ///   print('Sync: ${item['titulo']}');
  /// }
  /// 
  /// // Ver datos pendientes
  /// for (final item in data.pending) {
  ///   print('Pendiente: ${item['titulo']}');
  /// }
  /// ```
  Future<FullSyncData> getFullData() async {
    await _ensureInitialized();
    
    final allData = await _storage.getAll();
    final syncedData = <Map<String, dynamic>>[];
    final pendingData = <Map<String, dynamic>>[];
    
    for (final item in allData) {
      if (item['sync'] == 'true' || item.containsKey('syncDate')) {
        syncedData.add(item);
      } else {
        pendingData.add(item);
      }
    }
    
    return FullSyncData(
      all: _sortDataByDate(allData),
      synced: _sortDataByDate(syncedData),
      pending: _sortDataByDate(pendingData),
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTODOS DE UTILIDAD
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Limpiar todos los datos locales
  Future<void> clear() async {
    await _ensureInitialized();
    await _storage.clear();
    await _notifyData();
  }
  
  /// Resetear todo: datos locales y caché de sincronización
  Future<void> reset() async {
    await _ensureInitialized();
    await _storage.clear();
    await CacheManager.clearCache(boxName);
    await _notifyData();
  }
  
  /// Notificar cambios en datos
  Future<void> _notifyData() async {
    if (!_isInitialized) return;
    
    try {
      final data = await _storage.getAll();
      _dataController.add(data);
    } catch (e) {
      print('❌ Error notificando datos: $e');
    }
  }
  
  /// Ordena los datos por fecha (más recientes primero)
  List<Map<String, dynamic>> _sortDataByDate(List<Map<String, dynamic>> data) {
    return List<Map<String, dynamic>>.from(data)..sort((a, b) {
      final dateA = _extractDateFromRecord(a);
      final dateB = _extractDateFromRecord(b);
      return dateB.compareTo(dateA);
    });
  }
  
  /// Extrae la fecha de un registro
  DateTime _extractDateFromRecord(Map<String, dynamic> record) {
    final dateFields = ['date', 'lastModifiedAt', 'createdAt', 'created_at', 'timestamp'];
    
    for (final field in dateFields) {
      final value = record[field];
      if (value != null) {
        if (value is int || value is double) {
          try {
            return DateTime.fromMillisecondsSinceEpoch(value.toInt());
          } catch (e) {
            continue;
          }
        }
        
        if (value is String) {
          try {
            return DateTime.parse(value);
          } catch (e) {
            continue;
          }
        }
      }
    }
    
    return DateTime(1970);
  }

  /// Cerrar recursos
  void dispose() {
    _activeManagers.remove(this);
    _dataController.close();
    _syncService.dispose();
    _connectivity.dispose();
    _storage.dispose();
    
    // Si no quedan managers activos, limpiar auto-sync
    if (_activeManagers.isEmpty) {
      disposeAutoSync();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTODOS ESTÁTICOS - SINCRONIZACIÓN GLOBAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sincroniza TODOS los managers activos
  /// 
  /// Este es el método principal para actualizar datos.
  /// El usuario debe llamarlo cuando quiera obtener datos nuevos del servidor.
  /// 
  /// Ejemplo:
  /// ```dart
  /// // Cuando el usuario presione "Actualizar"
  /// await OnlineOfflineManager.syncAll();
  /// 
  /// // O agregar un botón de refresh
  /// FloatingActionButton(
  ///   onPressed: () => OnlineOfflineManager.syncAll(),
  ///   child: Icon(Icons.refresh),
  /// )
  /// ```
  /// 
  /// Retorna un Map con el resultado de cada manager:
  /// ```dart
  /// final results = await OnlineOfflineManager.syncAll();
  /// // { 'reportes': SyncResult(success: true), 'usuarios': SyncResult(success: false, error: '...') }
  /// ```
  static Future<Map<String, SyncResult>> syncAll() async {
    // 🔒 Prevenir múltiples ejecuciones simultáneas de syncAll()
    if (_isSyncingAll) {
      print('⚠️ [SyncAll] Sincronización ya en proceso, ignorando...');
      return {};
    }
    
    _isSyncingAll = true;
    
    try {
      final results = <String, SyncResult>{};
      
      final managers = List<OnlineOfflineManager>.from(_activeManagers);
      
      if (managers.isEmpty) {
        print('⚠️ No hay managers activos para sincronizar');
        return results;
      }
      
      print('🔄 Sincronizando ${managers.length} managers...');
      
      // Sincronizar todos en paralelo
      final syncFutures = managers.map((manager) async {
      if (manager.endpoint == null) {
        results[manager.boxName] = SyncResult(
          success: false,
          error: 'Sin endpoint configurado',
        );
        return;
      }
      
      try {
        await manager._ensureInitialized();
      } catch (e) {
        results[manager.boxName] = SyncResult(
          success: false,
          error: 'Error de inicialización: $e',
        );
        return;
      }
      
      // Verificar conectividad (pero no bloquear en background)
      // En background, el ConnectivityService puede no estar inicializado
      if (!ConnectivityService.isGlobalInitialized) {
        // Si no está inicializado (posiblemente en background), intentar inicializar
        print('⚠️ [${manager.boxName}] ConnectivityService no inicializado, intentando...');
        try {
          await ConnectivityService.initializeGlobal();
          await ConnectivityService.forceCheck();
        } catch (e) {
          // Si falla, continuar de todas formas - el ApiClient manejará el error
          print('⚠️ [${manager.boxName}] No se pudo verificar conectividad: $e');
        }
      }
      
      if (!ConnectivityService.globalIsOnline) {
        // En vez de bloquear, intentar de todas formas y dejar que falle naturalmente
        print('⚠️ [${manager.boxName}] Sin conexión detectada, pero intentando sync...');
        // Continuar - el ApiClient lanzará error si no hay conexión real
      }
      
      try {
        await manager._syncService.sync();
        await manager._notifyData();
        results[manager.boxName] = SyncResult(success: true);
        print('✅ ${manager.boxName}: sincronizado');
      } catch (e) {
        results[manager.boxName] = SyncResult(
          success: false,
          error: e.toString(),
        );
        print('❌ ${manager.boxName}: error - $e');
      }
      });
      
      await Future.wait(syncFutures);
      
      final successCount = results.values.where((r) => r.success).length;
      print('✅ Sincronización completada: $successCount/${managers.length} exitosos');
      
      return results;
    } finally {
      // 🔒 Liberar flag después de completar (o fallar)
      _isSyncingAll = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTODOS DE DEBUG Y RESET
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtiene información de todas las boxes Hive para debugging
  /// 
  /// Retorna información detallada de cada box:
  /// - Nombre
  /// - Número de registros
  /// - Si está abierta
  /// 
  /// Ejemplo:
  /// ```dart
  /// final info = await OnlineOfflineManager.getAllBoxesInfo();
  /// for (final box in info) {
  ///   print('Box: ${box.name}, Registros: ${box.recordCount}');
  /// }
  /// ```
  static Future<List<HiveBoxInfo>> getAllBoxesInfo() async {
    return await HiveUtils.getAllOpenBoxesInfo();
  }

  /// Imprime información de debug de todos los managers y boxes
  /// 
  /// Útil para debugging rápido en la consola
  /// 
  /// Ejemplo:
  /// ```dart
  /// await OnlineOfflineManager.debugInfo();
  /// ```
  static Future<void> debugInfo() async {
    print('═══════════════════════════════════════════════════════════');
    print('📊 DEBUG INFO - OnlineOfflineManager');
    print('═══════════════════════════════════════════════════════════');
    
    // Info de managers activos
    print('\n📦 Managers activos: ${_activeManagers.length}');
    for (final manager in _activeManagers) {
      final count = await manager._storage.length();
      final pending = await manager.getPending();
      print('   • ${manager.boxName}: $count registros (${pending.length} pendientes)');
    }
    
    // Info de boxes Hive
    print('\n💾 Boxes Hive:');
    final boxes = await getAllBoxesInfo();
    for (final box in boxes) {
      print('   • ${box.name}: ${box.recordCount} registros (${box.isOpen ? "abierta" : "cerrada"})');
    }
    
    // Info de GlobalConfig
    print('\n⚙️ GlobalConfig:');
    print('   • Inicializado: ${GlobalConfig.isInitialized}');
    print('   • BaseURL: ${GlobalConfig.baseUrl ?? "no configurado"}');
    
    print('\n═══════════════════════════════════════════════════════════');
  }

  /// Resetea TODO: managers, boxes y caché
  /// 
  /// Este método realiza un reset completo de la librería:
  /// 1. Limpia todos los datos de todos los managers activos
  /// 2. Resetea todas las boxes Hive
  /// 3. Limpia el caché de sincronización
  /// 
  /// ⚠️ CUIDADO: Esto elimina TODOS los datos locales
  /// 
  /// Ejemplo:
  /// ```dart
  /// // Resetear todo al cerrar sesión
  /// await OnlineOfflineManager.resetAll();
  /// ```
  static Future<void> resetAll() async {
    print('🔄 Iniciando reset global...');
    
    // 1. Limpiar datos de todos los managers activos
    for (final manager in _activeManagers) {
      try {
        await manager._ensureInitialized();
        await manager._storage.clear();
        await CacheManager.clearCache(manager.boxName);
        await manager._notifyData();
        print('   ✅ ${manager.boxName}: limpiado');
      } catch (e) {
        print('   ❌ ${manager.boxName}: error - $e');
      }
    }
    
    // 2. Resetear todas las boxes Hive (incluyendo las no registradas)
    await HiveUtils.resetAllBoxes(includeCacheBox: true);
    
    print('✅ Reset global completado');
  }

  /// Elimina todas las boxes Hive del disco
  /// 
  /// Útil para limpieza completa cuando hay problemas de corrupción
  /// 
  /// ⚠️ CUIDADO: Esto elimina permanentemente los archivos del disco
  static Future<void> deleteAllBoxes() async {
    await HiveUtils.deleteAllBoxes(includeCacheBox: true);
  }

  /// Obtiene el número total de registros en todos los managers
  static Future<int> getTotalRecordCount() async {
    int total = 0;
    for (final manager in _activeManagers) {
      try {
        await manager._ensureInitialized();
        total += await manager._storage.length();
      } catch (e) {
        // Ignorar errores
      }
    }
    return total;
  }

  /// Obtiene el número total de registros pendientes de sincronizar
  static Future<int> getTotalPendingCount() async {
    int total = 0;
    for (final manager in _activeManagers) {
      try {
        await manager._ensureInitialized();
        final pending = await manager.getPending();
        total += pending.length;
      } catch (e) {
        // Ignorar errores
      }
    }
    return total;
  }

  /// Obtiene el estado de sincronización de TODOS los managers
  /// 
  /// Retorna un Map donde la clave es el nombre del manager
  /// y el valor es su SyncInfo.
  /// 
  /// Ejemplo:
  /// ```dart
  /// final estados = await OnlineOfflineManager.getAllSyncInfo();
  /// for (final entry in estados.entries) {
  ///   print('${entry.key}: ${entry.value.synced}/${entry.value.total}');
  /// }
  /// ```
  static Future<Map<String, SyncInfo>> getAllSyncInfo() async {
    final results = <String, SyncInfo>{};
    
    for (final manager in _activeManagers) {
      try {
        await manager._ensureInitialized();
        results[manager.boxName] = await manager.getSyncInfo();
      } catch (e) {
        results[manager.boxName] = SyncInfo(total: 0, synced: 0, pending: 0);
      }
    }
    
    return results;
  }
}

/// Resultado de una operación de sincronización
class SyncResult {
  final bool success;
  final String? error;
  
  SyncResult({
    required this.success,
    this.error,
  });
}

/// Información del estado de sincronización de un manager (solo contadores)
class SyncInfo {
  /// Total de registros
  final int total;
  
  /// Registros sincronizados (del servidor)
  final int synced;
  
  /// Registros pendientes (locales, no sincronizados)
  final int pending;
  
  SyncInfo({
    required this.total,
    required this.synced,
    required this.pending,
  });
  
  /// Porcentaje de sincronización (0-100)
  double get syncPercentage => total > 0 ? (synced / total) * 100 : 100;
  
  /// ¿Está todo sincronizado?
  bool get isFullySynced => pending == 0;
  
  @override
  String toString() => 'SyncInfo(total: $total, synced: $synced, pending: $pending)';
}

/// Datos completos de sincronización (datos + contadores)
class FullSyncData {
  /// Todos los datos
  final List<Map<String, dynamic>> all;
  
  /// Solo datos sincronizados (del servidor)
  final List<Map<String, dynamic>> synced;
  
  /// Solo datos pendientes (locales, no sincronizados)
  final List<Map<String, dynamic>> pending;
  
  FullSyncData({
    required this.all,
    required this.synced,
    required this.pending,
  });
  
  /// Total de registros
  int get total => all.length;
  
  /// Cantidad de sincronizados
  int get syncedCount => synced.length;
  
  /// Cantidad de pendientes
  int get pendingCount => pending.length;
  
  /// Porcentaje de sincronización (0-100)
  double get syncPercentage => total > 0 ? (syncedCount / total) * 100 : 100;
  
  /// ¿Está todo sincronizado?
  bool get isFullySynced => pending.isEmpty;
  
  @override
  String toString() => 'FullSyncData(total: $total, synced: $syncedCount, pending: $pendingCount)';
}
