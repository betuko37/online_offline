/// Configuración global de la librería
class GlobalConfig {
  static String? _baseUrl;
  static String? _token;
  static bool _isInitialized = false;
  
  // Configuración de sincronización
  static int _syncMinutes = 5; // Por defecto 5 minutos
  static bool _useIncrementalSync = true; // Por defecto sincronización incremental
  static int _pageSize = 25; // Por defecto 25 registros por página
  static String _lastModifiedField = 'updated_at'; // Campo de timestamp
  static bool _syncOnReconnect = true; // Por defecto sincronizar al reconectar

  /// Inicializar configuración global
  static void init({
    required String baseUrl,
    required String token,
    int syncMinutes = 5,
    bool useIncrementalSync = true,
    int pageSize = 25,
    String lastModifiedField = 'updated_at',
    bool syncOnReconnect = true,
  }) {
    _baseUrl = baseUrl;
    _token = token;
    _syncMinutes = syncMinutes;
    _useIncrementalSync = useIncrementalSync;
    _pageSize = pageSize;
    _lastModifiedField = lastModifiedField;
    _syncOnReconnect = syncOnReconnect;
    _isInitialized = true;
  }

  /// Obtener URL base
  static String? get baseUrl => _baseUrl;

  /// Obtener token
  static String? get token => _token;

  /// Obtener minutos de sincronización
  static int get syncMinutes => _syncMinutes;

  /// Obtener si usa sincronización incremental
  static bool get useIncrementalSync => _useIncrementalSync;

  /// Obtener tamaño de página
  static int get pageSize => _pageSize;

  /// Obtener campo de última modificación
  static String get lastModifiedField => _lastModifiedField;

  /// Obtener si debe sincronizar al reconectar
  static bool get syncOnReconnect => _syncOnReconnect;

  /// Verificar si está inicializado
  static bool get isInitialized => _isInitialized;

  /// Limpiar configuración (útil para tests)
  static void clear() {
    _baseUrl = null;
    _token = null;
    _syncMinutes = 5;
    _useIncrementalSync = true;
    _pageSize = 25;
    _lastModifiedField = 'updated_at';
    _syncOnReconnect = true;
    _isInitialized = false;
  }
}
