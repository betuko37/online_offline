import 'dart:async';
import 'api/api_client.dart';
import 'storage/local_storage_service.dart';
import 'network/connectivity_service.dart';
import 'sync/sync_service.dart';
import 'config/sync_config.dart';

/// Estados de sincronización
enum SyncStatus { idle, syncing, success, error }

/// Gestor principal simplificado para sistema offline-first
/// 
/// Combina todos los servicios necesarios en una interfaz simple:
/// - Almacenamiento local automático
/// - Sincronización con servidor
/// - Detección de conectividad
/// - Autosync siempre activado
class OnlineOfflineManager {
  /// Nombre del box de Hive
  final String boxName;
  
  /// Endpoint del servidor
  final String? endpoint;
  
  /// Servicios internos
  late final ApiClient _apiClient;
  late final LocalStorageService _storage;
  late final ConnectivityService _connectivity;
  late final SyncService _syncService;
  
  /// Configuración simplificada
  late final SyncConfig _config;
  
  /// Estado de inicialización
  bool _isInitialized = false;
  
  /// Streams reactivos
  final _statusController = StreamController<SyncStatus>.broadcast();
  final _connectivityController = StreamController<bool>.broadcast();
  final _dataController = StreamController<Map<String, dynamic>>.broadcast();
  
  /// Streams públicos
  Stream<SyncStatus> get status => _statusController.stream;
  Stream<bool> get connectivity => _connectivityController.stream;
  Stream<Map<String, dynamic>> get data => _dataController.stream;
  
  /// Estado actual
  SyncStatus get currentStatus => _currentStatus;
  bool get isConnected => _connectivity.isConnected;
  bool get isInitialized => _isInitialized;
  
  SyncStatus _currentStatus = SyncStatus.idle;
  
  /// Constructor simplificado
  /// 
  /// [boxName] - Nombre del box de Hive
  /// [endpoint] - Endpoint del servidor (opcional)
  OnlineOfflineManager({
    required this.boxName,
    this.endpoint,
  }) {
    _initializeServices();
    // ✅ Inicializar automáticamente
    initialize();
  }
  
  /// Inicializa servicios internos
  void _initializeServices() {
    _apiClient = ApiClient();
    _storage = LocalStorageService(boxName: boxName);
    _connectivity = ConnectivityService();
    
    // Configuración simplificada
    _config = SyncConfig.simple(
      boxName: boxName,
      endpoint: endpoint ?? 'default',
      enableAutoSync: true,
    );
    
    _syncService = SyncService(
      config: _config,
      apiClient: _apiClient,
    );
  }
  
  /// Inicializa el manager
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _storage.initialize();
      await _connectivity.initialize();
      
      // ✅ Cargar datos existentes al inicializar
      await _loadExistingData();
      
      _setupStreams();
      _isInitialized = true;
    } catch (e) {
      throw Exception('Error inicializando OnlineOfflineManager: $e');
    }
  }
  
  /// Carga datos existentes del almacenamiento local
  Future<void> _loadExistingData() async {
    try {
      final allData = await _storage.getAll();
      _dataController.add(allData);
      print('✅ Datos cargados al inicializar: ${allData.length} registros');
    } catch (e) {
      print('❌ Error cargando datos existentes: $e');
    }
  }
  
  /// Configura streams reactivos
  void _setupStreams() {
    _connectivity.connectivityStream.listen((connected) {
      _connectivityController.add(connected);
      
      // Autosync cuando se conecte
      if (connected && endpoint != null) {
        _performAutoSync();
      }
    });
  }
  
  /// Guarda datos localmente y sincroniza si hay conexión
  /// 
  /// [key] - Clave única
  /// [data] - Datos a guardar
  Future<void> save(String key, Map<String, dynamic> data) async {
    await _ensureInitialized();
    
    try {
      // Guardar localmente
      await _storage.save(key, data);
      
      // Emitir cambio de datos
      final allData = await _storage.getAll();
      _dataController.add(allData);
      
      // Sincronizar si hay conexión
      if (isConnected && endpoint != null) {
        await _syncRecord(key, data);
      }
    } catch (e) {
      throw Exception('Error guardando datos: $e');
    }
  }
  
  /// Obtiene datos por clave
  Future<Map<String, dynamic>?> get(String key) async {
    await _ensureInitialized();
    return await _storage.get(key);
  }
  
  /// Obtiene todos los datos
  Future<Map<String, dynamic>> getAll() async {
    await _ensureInitialized();
    
    // Sincronizar si hay conexión
    if (isConnected && endpoint != null) {
      await _performAutoSync();
    }
    
    return await _storage.getAll();
  }
  
  /// Elimina datos por clave
  Future<void> delete(String key) async {
    await _ensureInitialized();
    
    try {
      await _storage.delete(key);
      
      // Emitir cambio de datos
      final allData = await _storage.getAll();
      _dataController.add(allData);
    } catch (e) {
      throw Exception('Error eliminando datos: $e');
    }
  }
  
  /// Sincroniza un registro específico
  Future<void> _syncRecord(String key, Map<String, dynamic> data) async {
    try {
      _currentStatus = SyncStatus.syncing;
      _statusController.add(SyncStatus.syncing);
      
      final record = Map<String, dynamic>.from(data);
      record['_local_id'] = key;
      record['_synced_at'] = DateTime.now().toIso8601String();
      
      await _syncService.sendRecord(
        _config.endpoints.first.name,
        record: record,
      );
      
      _currentStatus = SyncStatus.success;
      _statusController.add(SyncStatus.success);
    } catch (e) {
      _currentStatus = SyncStatus.error;
      _statusController.add(SyncStatus.error);
      print('Error sincronizando registro: $e');
    }
  }
  
  /// Realiza sincronización automática
  Future<void> _performAutoSync() async {
    try {
      _currentStatus = SyncStatus.syncing;
      _statusController.add(SyncStatus.syncing);
      
      final result = await _syncService.getAllRecords(_config.endpoints.first.name);
      
      if (result.isSuccess) {
        final serverData = result.data as Map<String, dynamic>;
        
        // Guardar datos del servidor localmente
        for (final entry in serverData.entries) {
          await _storage.save(entry.key, entry.value);
        }
        
        // Emitir datos actualizados
        final allData = await _storage.getAll();
        _dataController.add(allData);
        
        _currentStatus = SyncStatus.success;
        _statusController.add(SyncStatus.success);
      } else {
        throw Exception(result.error);
      }
    } catch (e) {
      _currentStatus = SyncStatus.error;
      _statusController.add(SyncStatus.error);
      print('Error en sincronización automática: $e');
    }
  }
  
  /// Sincroniza manualmente
  Future<void> sync() async {
    await _ensureInitialized();
    await _performAutoSync();
  }
  
  /// Verifica conectividad
  Future<bool> checkConnectivity() async {
    return await _connectivity.checkConnectivity();
  }
  
  /// Asegura que el manager esté inicializado
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
  
  /// Libera recursos
  void dispose() {
    _storage.dispose();
    _connectivity.dispose();
    _apiClient.dispose();
    
    _statusController.close();
    _connectivityController.close();
    _dataController.close();
  }
}