/// Configuración global de la librería
class GlobalConfig {
  static String? _baseUrl;
  static String? _token;
  static bool _isInitialized = false;
  
  // Configuración de sincronización
  static int _syncMinutes = 5; // Por defecto 5 minutos
  static bool _useIncrementalSync = true; // Por defecto sincronización incremental
  static int _pageSize = 25; // Por defecto 25 registros por página
  static String _lastModifiedField = 'lastModifiedAt'; // Campo de timestamp por defecto
  static bool _syncOnReconnect = true; // Por defecto sincronizar al reconectar
  static int _maxLocalRecords = 1000; // Por defecto sin límite (solo para managers con limpieza)
  static int _maxDaysToKeep = 7; // Por defecto 7 días (solo para managers con limpieza)

  /// Inicializar configuración global
  static void init({
    required String baseUrl,
    required String token,
    int syncMinutes = 5,
    bool useIncrementalSync = true, // Por defecto true
    int pageSize = 25,
    String lastModifiedField = 'lastModifiedAt', // Por defecto lastModifiedAt
    bool syncOnReconnect = true, // Por defecto true
    int maxLocalRecords = 1000, // Por defecto sin límite
    int maxDaysToKeep = 7, // Por defecto 7 días
  }) {
    _baseUrl = baseUrl;
    _token = token;
    _syncMinutes = syncMinutes;
    _useIncrementalSync = useIncrementalSync;
    _pageSize = pageSize;
    _lastModifiedField = lastModifiedField;
    _syncOnReconnect = syncOnReconnect;
    _maxLocalRecords = maxLocalRecords;
    _maxDaysToKeep = maxDaysToKeep;
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

  /// Obtener máximo de registros locales
  static int get maxLocalRecords => _maxLocalRecords;

  /// Obtener máximo de días para mantener registros sincronizados
  static int get maxDaysToKeep => _maxDaysToKeep;

  /// Verificar si está inicializado
  static bool get isInitialized => _isInitialized;

  /// Limpiar configuración (útil para tests)
  static void clear() {
    _baseUrl = null;
    _token = null;
    _syncMinutes = 5;
    _useIncrementalSync = true;
    _pageSize = 25;
    _lastModifiedField = 'lastModifiedAt';
    _syncOnReconnect = true;
    _maxLocalRecords = 1000;
    _maxDaysToKeep = 7;
    _isInitialized = false;
  }
}
