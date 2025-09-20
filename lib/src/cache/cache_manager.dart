import 'package:hive_flutter/hive_flutter.dart';

/// Gestor de caché inteligente para optimizar sincronizaciones
class CacheManager {
  static const String _cacheBoxName = '_cache_metadata';
  static Box? _cacheBox;
  static bool _isInitialized = false;
  
  /// Inicializa el box de caché
  static Future<void> _ensureInitialized() async {
    if (_isInitialized && _cacheBox != null && _cacheBox!.isOpen) return;
    
    try {
      if (!Hive.isBoxOpen(_cacheBoxName)) {
        _cacheBox = await Hive.openBox(_cacheBoxName);
      } else {
        _cacheBox = Hive.box(_cacheBoxName);
      }
      _isInitialized = true;
    } catch (e) {
      rethrow;
    }
  }
  
  /// Obtiene la fecha de última sincronización
  static Future<DateTime?> getLastSyncTime(String boxName) async {
    try {
      await _ensureInitialized();
      final cacheKey = '${boxName}_lastSync';
      final lastSyncString = _cacheBox!.get(cacheKey);
      
      if (lastSyncString != null) {
        return DateTime.parse(lastSyncString);
      }
    } catch (e) {
      // Error silencioso
    }
    return null;
  }
  
  /// Actualiza la fecha de última sincronización
  static Future<void> updateLastSyncTime(String boxName) async {
    try {
      await _ensureInitialized();
      final cacheKey = '${boxName}_lastSync';
      await _cacheBox!.put(cacheKey, DateTime.now().toIso8601String());
    } catch (e) {
      // Error silencioso
    }
  }
  
  /// Verifica si necesita sincronizar basado en el tiempo transcurrido
  static Future<bool> shouldSync(String boxName, {Duration? maxAge}) async {
    final maxCacheAge = maxAge ?? const Duration(minutes: 5); // Por defecto 5 minutos
    final lastSync = await getLastSyncTime(boxName);
    
    if (lastSync == null) {
      return true;
    }
    
    final timeSinceLastSync = DateTime.now().difference(lastSync);
    return timeSinceLastSync > maxCacheAge;
  }
  
  /// Limpia el caché
  static Future<void> clearCache(String boxName) async {
    try {
      await _ensureInitialized();
      final cacheKey = '${boxName}_lastSync';
      await _cacheBox!.delete(cacheKey);
    } catch (e) {
      // Error silencioso
    }
  }
  
  /// Cierra el box de caché
  static Future<void> dispose() async {
    if (_cacheBox != null && _cacheBox!.isOpen) {
      await _cacheBox!.close();
    }
    _isInitialized = false;
  }
}
