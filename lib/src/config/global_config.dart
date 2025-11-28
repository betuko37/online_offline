import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuración global de la librería - SIMPLIFICADA
/// Solo necesitas baseUrl y token, todo lo demás es automático
class GlobalConfig {
  static String? _baseUrl;
  static String? _token;
  static bool _isInitialized = false;
  static bool _enableBackgroundSync = false;
  
  // Configuración interna con valores sensatos (no expuesta al usuario)
  static int _syncMinutes = 10;
  static int _pageSize = 50;
  static String _lastModifiedField = 'updatedAt';
  static bool _syncOnReconnect = true;
  static int _maxLocalRecords = 1000;
  static int _maxDaysToKeep = 30;
  static int _maxPagesPerSync = 20;
  
  // Claves para SharedPreferences
  static const String _prefsPrefix = 'betuko_offline_sync_';
  static const String _prefsBaseUrl = '${_prefsPrefix}base_url';
  static const String _prefsToken = '${_prefsPrefix}token';

  /// Inicializar configuración global - SÚPER SIMPLE
  /// 
  /// Solo necesitas 2 parámetros obligatorios:
  /// ```dart
  /// GlobalConfig.init(
  ///   baseUrl: 'https://tu-api.com',
  ///   token: 'tu-token',
  /// );
  /// ```
  /// 
  /// Para habilitar sincronización en background (solo Android):
  /// ```dart
  /// GlobalConfig.init(
  ///   baseUrl: 'https://tu-api.com',
  ///   token: 'tu-token',
  ///   enableBackgroundSync: true,
  /// );
  /// ```
  static Future<void> init({
    required String baseUrl,
    required String token,
    bool enableBackgroundSync = false,
  }) async {
    _baseUrl = baseUrl;
    _token = token;
    _enableBackgroundSync = enableBackgroundSync;
    _isInitialized = true;
    
    // Guardar en SharedPreferences para background sync
    if (enableBackgroundSync && Platform.isAndroid) {
      await _saveToPrefs();
    }
  }
  
  /// Inicialización síncrona (sin soporte background sync)
  /// 
  /// Usar esta versión si no necesitas background sync
  /// o prefieres manejarlo manualmente.
  static void initSync({
    required String baseUrl,
    required String token,
  }) {
    _baseUrl = baseUrl;
    _token = token;
    _enableBackgroundSync = false;
    _isInitialized = true;
  }

  /// Obtener URL base
  static String? get baseUrl => _baseUrl;

  /// Obtener token
  static String? get token => _token;
  
  /// ¿Está habilitado el background sync?
  static bool get isBackgroundSyncEnabled => _enableBackgroundSync;

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
  /// Útil cuando el token cambia después del login o refresh.
  /// Automáticamente actualiza SharedPreferences si background sync está habilitado.
  static Future<void> updateToken(String newToken) async {
    if (!_isInitialized) {
      throw Exception('GlobalConfig no está inicializado. Llama a GlobalConfig.init() primero.');
    }
    _token = newToken;
    
    // Actualizar en SharedPreferences si background sync está habilitado
    if (_enableBackgroundSync && Platform.isAndroid) {
      await _saveToPrefs();
    }
  }
  
  /// Actualizar token de forma síncrona (sin actualizar SharedPreferences)
  static void updateTokenSync(String newToken) {
    if (!_isInitialized) {
      throw Exception('GlobalConfig no está inicializado. Llama a GlobalConfig.init() primero.');
    }
    _token = newToken;
  }

  /// Verificar si está inicializado
  static bool get isInitialized => _isInitialized;
  
  /// Guarda la configuración actual en SharedPreferences
  /// 
  /// Llamar manualmente si usaste `initSync()` y quieres
  /// habilitar background sync después.
  static Future<void> saveForBackgroundSync() async {
    if (!_isInitialized) {
      throw Exception('GlobalConfig no está inicializado.');
    }
    await _saveToPrefs();
    _enableBackgroundSync = true;
  }
  
  /// Guarda configuración en SharedPreferences
  static Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_baseUrl != null) {
      await prefs.setString(_prefsBaseUrl, _baseUrl!);
    }
    if (_token != null) {
      await prefs.setString(_prefsToken, _token!);
    }
  }
  
  /// Carga configuración desde SharedPreferences
  /// 
  /// Útil para inicializar desde un background isolate
  static Future<bool> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl = prefs.getString(_prefsBaseUrl);
    final savedToken = prefs.getString(_prefsToken);
    
    if (savedBaseUrl != null && savedToken != null) {
      _baseUrl = savedBaseUrl;
      _token = savedToken;
      _isInitialized = true;
      return true;
    }
    return false;
  }

  /// Limpiar configuración (útil para tests y logout)
  /// 
  /// Si `clearPrefs` es true, también limpia SharedPreferences
  static Future<void> clear({bool clearPrefs = true}) async {
    _baseUrl = null;
    _token = null;
    _syncMinutes = 5;
    _pageSize = 50;
    _lastModifiedField = 'updatedAt';
    _syncOnReconnect = true;
    _maxLocalRecords = 1000;
    _maxDaysToKeep = 30;
    _maxPagesPerSync = 20;
    _enableBackgroundSync = false;
    _isInitialized = false;
    
    if (clearPrefs) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsBaseUrl);
      await prefs.remove(_prefsToken);
    }
  }
  
  /// Limpieza síncrona (no limpia SharedPreferences)
  static void clearSync() {
    _baseUrl = null;
    _token = null;
    _syncMinutes = 5;
    _pageSize = 50;
    _lastModifiedField = 'updatedAt';
    _syncOnReconnect = true;
    _maxLocalRecords = 1000;
    _maxDaysToKeep = 30;
    _maxPagesPerSync = 20;
    _enableBackgroundSync = false;
    _isInitialized = false;
  }
}
