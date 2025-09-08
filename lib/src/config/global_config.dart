/// Configuración global de la librería
class GlobalConfig {
  static String? _baseUrl;
  static String? _token;
  static bool _isInitialized = false;

  /// Inicializar configuración global
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

  /// Verificar si está inicializado
  static bool get isInitialized => _isInitialized;

  /// Limpiar configuración (útil para tests)
  static void clear() {
    _baseUrl = null;
    _token = null;
    _isInitialized = false;
  }
}
