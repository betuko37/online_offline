// src/local/local_db.dart
import 'package:hive_flutter/hive_flutter.dart';

/// Gestor de base de datos local con múltiples tablas (boxes)
/// Permite al usuario crear y manejar diferentes tablas según sus necesidades
class LocalDB {
  final String databaseName;
  final Map<String, Box> _boxes = {};

  LocalDB({required this.databaseName});

  /// Inicializa la base de datos local
  Future<void> init() async {
    // Inicializar Hive en Flutter
    await Hive.initFlutter();
  }

  /// Crea o abre una tabla (box) específica
  Future<void> createTable(String tableName) async {
    if (!_boxes.containsKey(tableName)) {
      final box = await Hive.openBox('${databaseName}_$tableName');
      _boxes[tableName] = box;
    }
  }

  /// Verifica si una tabla existe
  bool tableExists(String tableName) {
    return _boxes.containsKey(tableName);
  }

  /// Obtiene todas las tablas creadas
  List<String> getTables() {
    return _boxes.keys.toList();
  }

  /// Guarda un item en una tabla específica
  Future<void> put(String tableName, String key, dynamic value) async {
    await _ensureTableExists(tableName);
    final box = _boxes[tableName]!;
    await box.put(key, value);
  }

  /// Obtiene un item de una tabla específica
  dynamic get(String tableName, String key) {
    if (!_boxes.containsKey(tableName)) return null;
    final box = _boxes[tableName]!;
    return box.get(key);
  }

  /// Obtiene todos los items de una tabla específica
  Map<dynamic, dynamic> getAll(String tableName) {
    if (!_boxes.containsKey(tableName)) return {};
    final box = _boxes[tableName]!;
    return box.toMap();
  }

  /// Elimina un item de una tabla específica
  Future<void> delete(String tableName, String key) async {
    if (!_boxes.containsKey(tableName)) return;
    final box = _boxes[tableName]!;
    await box.delete(key);
  }

  /// Elimina una tabla completa
  Future<void> deleteTable(String tableName) async {
    if (_boxes.containsKey(tableName)) {
      final box = _boxes[tableName]!;
      await box.clear();
      await box.close();
      _boxes.remove(tableName);
    }
  }

  /// Limpia todos los datos de una tabla
  Future<void> clearTable(String tableName) async {
    if (!_boxes.containsKey(tableName)) return;
    final box = _boxes[tableName]!;
    await box.clear();
  }

  /// Limpia todas las tablas
  Future<void> clearAll() async {
    for (final box in _boxes.values) {
      await box.clear();
    }
  }

  /// Obtiene el número de items en una tabla
  int getTableSize(String tableName) {
    if (!_boxes.containsKey(tableName)) return 0;
    final box = _boxes[tableName]!;
    return box.length;
  }

  /// Verifica si existe una clave en una tabla
  bool containsKey(String tableName, String key) {
    if (!_boxes.containsKey(tableName)) return false;
    final box = _boxes[tableName]!;
    return box.containsKey(key);
  }

  /// Obtiene todas las claves de una tabla
  Iterable<dynamic> getKeys(String tableName) {
    if (!_boxes.containsKey(tableName)) return [];
    final box = _boxes[tableName]!;
    return box.keys;
  }

  /// Obtiene todos los valores de una tabla
  Iterable<dynamic> getValues(String tableName) {
    if (!_boxes.containsKey(tableName)) return [];
    final box = _boxes[tableName]!;
    return box.values;
  }

  /// Guarda múltiples items en una tabla
  Future<void> putAll(String tableName, Map<String, dynamic> items) async {
    await _ensureTableExists(tableName);
    final box = _boxes[tableName]!;
    for (final entry in items.entries) {
      await box.put(entry.key, entry.value);
    }
  }

  /// Asegura que la tabla existe, si no la crea
  Future<void> _ensureTableExists(String tableName) async {
    if (!_boxes.containsKey(tableName)) {
      await createTable(tableName);
    }
  }

  /// Cierra todas las tablas y libera recursos
  Future<void> close() async {
    for (final box in _boxes.values) {
      await box.close();
    }
    _boxes.clear();
  }
}
