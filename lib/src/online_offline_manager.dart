import 'dart:async';
import 'storage/local_storage.dart';
import 'sync/sync_service.dart';
import 'connectivity/connectivity_service.dart';
import 'models/sync_status.dart';

/// Manager super simple para offline-first
/// TODO SE INICIALIZA AUTOMÁTICAMENTE - Solo crear y usar
class OnlineOfflineManager {
  final String boxName;
  final String? endpoint;
  
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
  
  OnlineOfflineManager({
    required this.boxName,
    this.endpoint,
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
      print('✅ OnlineOfflineManager "$boxName" listo automáticamente');
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
      
      // Auto-sync inteligente cuando hay conexión
      _connectivity.connectivityStream.listen((isOnline) async {
        if (isOnline && endpoint != null) {
          try {
            await _syncService.sync();
            await _notifyData();
          } catch (e) {
            print('❌ Error en auto-sync: $e');
          }
        }
      });
      
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
    
    print('✅ Guardado localmente: $id');
    
    // Auto-sync inteligente si hay internet
    if (_connectivity.isOnline && endpoint != null) {
      _syncService.sync().then((_) {
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
  
  /// Eliminar (inicialización automática)
  Future<void> delete(String id) async {
    await _ensureInitialized();
    await _storage.delete(id);
    await _notifyData();
    
    // Auto-sync después de eliminar
    if (_connectivity.isOnline && endpoint != null) {
      _syncService.sync().then((_) {
        _notifyData();
      }).catchError((e) {
        print('❌ Error en auto-sync: $e');
      });
    }
  }
  
  /// ===========================================
  /// SINCRONIZACIÓN AUTOMÁTICA
  /// ===========================================
  
  /// Sincronizar con servidor (fuerza sincronización)
  Future<void> sync() async {
    await _ensureInitialized();
    await _syncService.sync();
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
    print('🧹 Limpiando recursos automáticamente...');
    _dataController.close();
    _syncService.dispose();
    _connectivity.dispose();
    _storage.dispose();
    print('✅ Recursos liberados automáticamente');
  }
}