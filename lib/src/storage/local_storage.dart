import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

/// Servicio de almacenamiento local usando Hive
/// Se inicializa automáticamente en el primer uso
class LocalStorage {
  final String boxName;
  Box? _box;
  bool _isInitialized = false;
  static bool _hiveInitialized = false;
  
  // Registro de todas las boxes abiertas
  static final Set<String> _registeredBoxes = {};

  LocalStorage({required this.boxName});
  
  /// Obtener todas las boxes registradas
  static Set<String> get registeredBoxes => Set.unmodifiable(_registeredBoxes);
  
  /// Registrar una box como abierta
  static void _registerBox(String boxName) {
    _registeredBoxes.add(boxName);
  }
  
  /// Limpiar registro de boxes
  static void clearRegisteredBoxes() {
    _registeredBoxes.clear();
  }

  /// Inicializa Hive globalmente (solo una vez por app)
  static Future<void> _initHiveOnce() async {
    if (_hiveInitialized) return;
    
    try {
      await Hive.initFlutter();
      _hiveInitialized = true;
    } catch (e) {
      rethrow;
    }
  }

  /// Inicializa Hive y abre el box (llamada manual opcional)
  Future<void> initialize() async {
    await _ensureInitialized();
  }

  /// Asegura que el box esté abierto (inicialización automática)
  Future<void> _ensureInitialized() async {
    if (_isInitialized && _box != null && _box!.isOpen) return;

    try {
      // Asegurar que Hive esté inicializado globalmente
      await _initHiveOnce();
      
      // Abrir el box específico
      if (_box == null || !_box!.isOpen) {
        _box = await Hive.openBox(boxName);
        _isInitialized = true;
        // Registrar la box como abierta
        _registerBox(boxName);
      }
    } catch (e) {
      try {
        // Si falla, intentar recrear el box
        await Hive.deleteBoxFromDisk(boxName);
        _box = await Hive.openBox(boxName);
        _isInitialized = true;
      } catch (recreateError) {
        throw Exception('Error crítico inicializando almacenamiento: $recreateError');
      }
    }
  }

  /// Guarda un registro
  Future<void> save(String key, Map<String, dynamic> data) async {
    await _ensureInitialized();
    await _box!.put(key, data);
  }

  /// Obtiene un registro por clave
  Future<Map<String, dynamic>?> get(String key) async {
    await _ensureInitialized();
    final data = _box!.get(key);
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  /// Obtiene todos los registros
  Future<List<Map<String, dynamic>>> getAll() async {
    await _ensureInitialized();
    return _box!.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Obtiene todas las claves
  Future<List<String>> getKeys() async {
    await _ensureInitialized();
    return _box!.keys.map((e) => e.toString()).toList();
  }

  /// Elimina un registro
  Future<void> delete(String key) async {
    await _ensureInitialized();
    await _box!.delete(key);
  }

  /// Limpia todos los datos
  Future<void> clear() async {
    await _ensureInitialized();
    await _box!.clear();
  }

  /// Verifica si existe una clave
  Future<bool> contains(String key) async {
    await _ensureInitialized();
    return _box!.containsKey(key);
  }

  /// Obtiene el número de registros
  Future<int> length() async {
    await _ensureInitialized();
    return _box!.length;
  }

  /// Filtra registros por condición
  Future<List<Map<String, dynamic>>> where(bool Function(Map<String, dynamic>) test) async {
    final all = await getAll();
    return all.where(test).toList();
  }

  /// Cierra el almacenamiento
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
    _isInitialized = false;
  }

  /// Libera recursos
  void dispose() {
    close();
  }
}
