/// Configuración global de la librería - SIMPLIFICADA
/// Solo necesitas baseUrl y token, todo lo demás es automático
class GlobalConfig {
  static String? _baseUrl;
  static String? _token;
  static bool _isInitialized = false;
  
  // Configuración interna con valores sensatos (no expuesta al usuario)
  static int _syncMinutes = 10;
  static int _pageSize = 50;
  static String _lastModifiedField = 'updatedAt';
  static bool _syncOnReconnect = true;
  static int _maxLocalRecords = 1000;
  static int _maxDaysToKeep = 30;
  static int _maxPagesPerSync = 20;

  /// Inicializar configuración global - SÚPER SIMPLE
  /// 
  /// Solo necesitas 2 parámetros:
  /// ```dart
  /// GlobalConfig.init(
  ///   baseUrl: 'https://tu-api.com',
  ///   token: 'tu-token',
  /// );
  /// ```
  static void init({
    required String baseUrl,
    required String token,
  }) {
    _baseUrl = baseUrl;
    _token = token;
    _isInitialized = true;
  }

  /// Obtener URL base
  static String? get baseUrl => _baseUrl;

  /// Obtener token
  static String? get token => _token;

  // Getters internos (valores automáticos)
  static int get syncMinutes => _syncMinutes;
  static int get pageSize => _pageSize;
  static String get lastModifiedField => _lastModifiedField;
  static bool get syncOnReconnect => _syncOnReconnect;
  static int get maxLocalRecords => _maxLocalRecords;
  static int get maxDaysToKeep => _maxDaysToKeep;
  static int get maxPagesPerSync => _maxPagesPerSync;

  /// Actualizar solo el token sin resetear toda la configuración
  /// 
  /// Útil cuando el token cambia después del login o refresh
  static void updateToken(String newToken) {
    if (!_isInitialized) {
      throw Exception('GlobalConfig no está inicializado. Llama a GlobalConfig.init() primero.');
    }
    _token = newToken;
  }

  /// Verificar si está inicializado
  static bool get isInitialized => _isInitialized;

  /// Limpiar configuración (útil para tests)
  static void clear() {
    _baseUrl = null;
    _token = null;
    _syncMinutes = 5;
    _pageSize = 50;
    _lastModifiedField = 'updatedAt';
    _syncOnReconnect = true;
    _maxLocalRecords = 1000;
    _maxDaysToKeep = 30;
    _maxPagesPerSync = 20;
    _isInitialized = false;
  }
}
