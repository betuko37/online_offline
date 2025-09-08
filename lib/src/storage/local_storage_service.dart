import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Variable estática para rastrear si Hive ya está inicializado
bool _hiveInitialized = false;

/// Servicio de almacenamiento local simplificado usando Hive
/// 
/// Maneja operaciones CRUD básicas:
/// - Guardar datos
/// - Obtener datos
/// - Eliminar datos
/// - Obtener todos los datos
class LocalStorageService {
  /// Nombre del box de Hive
  final String boxName;
  
  /// Box de Hive
  Box? _box;
  
  /// Estado de inicialización
  bool _isInitialized = false;
  
  /// Constructor
  LocalStorageService({required this.boxName});
  
  /// Inicializa el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Inicializar Hive automáticamente si no está inicializado
      await _ensureHiveInitialized();
      
      _box = await Hive.openBox(boxName);
      _isInitialized = true;
    } catch (e) {
      throw Exception('Error inicializando almacenamiento: $e');
    }
  }
  
  /// Asegura que Hive esté inicializado automáticamente
  Future<void> _ensureHiveInitialized() async {
    if (!_hiveInitialized) {
      try {
        // Obtener el directorio de documentos de la aplicación
        final appDir = await getApplicationDocumentsDirectory();
        final hivePath = '${appDir.path}/betuko_offline_sync';
        
        // Inicializar Hive con la ruta correcta
        Hive.init(hivePath);
      } catch (e) {
        // Fallback para tests o cuando path_provider no está disponible
        // Usar un directorio temporal o el directorio actual
        Hive.init('betuko_offline_sync');
      }
      _hiveInitialized = true;
    }
  }
  
  /// Verifica si está inicializado
  bool get isInitialized => _isInitialized;
  
  /// Guarda datos
  /// 
  /// [key] - Clave única
  /// [data] - Datos a guardar
  Future<void> save(String key, Map<String, dynamic> data) async {
    await _ensureInitialized();
    
    try {
      await _box!.put(key, data);
    } catch (e) {
      throw Exception('Error guardando datos: $e');
    }
  }
  
  /// Obtiene datos por clave
  /// 
  /// [key] - Clave del dato
  Future<Map<String, dynamic>?> get(String key) async {
    await _ensureInitialized();
    
    try {
      final data = _box!.get(key);
      if (data == null) return null;
      return Map<String, dynamic>.from(data);
    } catch (e) {
      throw Exception('Error obteniendo datos: $e');
    }
  }
  
  /// Obtiene todos los datos
  Future<Map<String, dynamic>> getAll() async {
    await _ensureInitialized();
    
    try {
      final allData = _box!.toMap();
      final result = <String, dynamic>{};
      
      for (final entry in allData.entries) {
        final key = entry.key.toString();
        final data = entry.value;
        result[key] = Map<String, dynamic>.from(data);
      }
      
      return result;
    } catch (e) {
      throw Exception('Error obteniendo todos los datos: $e');
    }
  }
  
  /// Elimina datos por clave
  /// 
  /// [key] - Clave del dato a eliminar
  Future<void> delete(String key) async {
    await _ensureInitialized();
    
    try {
      await _box!.delete(key);
    } catch (e) {
      throw Exception('Error eliminando datos: $e');
    }
  }
  
  /// Verifica si existe una clave
  /// 
  /// [key] - Clave a verificar
  Future<bool> contains(String key) async {
    await _ensureInitialized();
    return _box!.containsKey(key);
  }
  
  /// Obtiene el tamaño del almacenamiento
  Future<int> getSize() async {
    await _ensureInitialized();
    return _box!.length;
  }
  
  /// Limpia todos los datos
  Future<void> clear() async {
    await _ensureInitialized();
    
    try {
      await _box!.clear();
    } catch (e) {
      throw Exception('Error limpiando almacenamiento: $e');
    }
  }
  
  /// Cierra el box
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
    _isInitialized = false;
  }
  
  /// Asegura que esté inicializado
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
  
  /// Libera recursos
  void dispose() {
    close();
  }
}