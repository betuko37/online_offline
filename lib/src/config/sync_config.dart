/// Configuración de sincronización para optimizar rendimiento
class SyncConfig {
  /// Tiempo máximo que pueden estar los datos en caché antes de sincronizar
  final Duration maxCacheAge;
  
  /// Si debe sincronizar automáticamente al obtener datos
  final bool autoSyncOnGet;
  
  /// Si debe sincronizar automáticamente al guardar datos
  final bool autoSyncOnSave;
  
  /// Si debe sincronizar automáticamente al eliminar datos
  final bool autoSyncOnDelete;
  
  /// Si debe sincronizar automáticamente cuando cambia la conectividad
  final bool autoSyncOnConnectivityChange;
  
  /// Intervalo mínimo entre sincronizaciones automáticas
  final Duration minSyncInterval;
  
  /// Si debe usar sincronización inteligente (basada en timestamps)
  final bool useSmartSync;
  
  const SyncConfig({
    this.maxCacheAge = const Duration(minutes: 5),
    this.autoSyncOnGet = true,
    this.autoSyncOnSave = true,
    this.autoSyncOnDelete = true,
    this.autoSyncOnConnectivityChange = true,
    this.minSyncInterval = const Duration(seconds: 30),
    this.useSmartSync = true,
  });
  
  /// Configuración para datos que cambian frecuentemente
  static const SyncConfig frequent = SyncConfig(
    maxCacheAge: Duration(minutes: 1),
    autoSyncOnGet: true,
    autoSyncOnSave: true,
    autoSyncOnDelete: true,
    autoSyncOnConnectivityChange: true,
    minSyncInterval: Duration(seconds: 10),
    useSmartSync: true,
  );
  
  /// Configuración para datos que cambian ocasionalmente
  static const SyncConfig occasional = SyncConfig(
    maxCacheAge: Duration(minutes: 15),
    autoSyncOnGet: false, // No sincronizar automáticamente al obtener
    autoSyncOnSave: true,
    autoSyncOnDelete: true,
    autoSyncOnConnectivityChange: true,
    minSyncInterval: Duration(minutes: 2),
    useSmartSync: true,
  );
  
  /// Configuración para datos que cambian raramente
  static const SyncConfig rare = SyncConfig(
    maxCacheAge: Duration(hours: 1),
    autoSyncOnGet: false, // No sincronizar automáticamente al obtener
    autoSyncOnSave: false, // No sincronizar automáticamente al guardar
    autoSyncOnDelete: false, // No sincronizar automáticamente al eliminar
    autoSyncOnConnectivityChange: false, // No sincronizar automáticamente
    minSyncInterval: Duration(minutes: 10),
    useSmartSync: true,
  );
  
  /// Configuración sin sincronización automática
  static const SyncConfig manual = SyncConfig(
    maxCacheAge: Duration(days: 1),
    autoSyncOnGet: false,
    autoSyncOnSave: false,
    autoSyncOnDelete: false,
    autoSyncOnConnectivityChange: false,
    minSyncInterval: Duration(hours: 1),
    useSmartSync: true,
  );
}
