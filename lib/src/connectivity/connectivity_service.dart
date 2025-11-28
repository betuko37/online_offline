import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Servicio de conectividad de red con inicialización automática
class ConnectivityService {
  bool _isOnline = false;
  bool _isInitialized = false;
  final _connectivityController = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Stream del estado de conectividad
  Stream<bool> get connectivityStream => _connectivityController.stream;
  
  /// Estado actual de conectividad (con auto-inicialización)
  bool get isOnline {
    if (!_isInitialized) {
      // Inicialización automática silenciosa
      _autoInitialize();
    }
    return _isOnline;
  }

  /// Verifica si hay conexión real a internet haciendo un ping HTTP
  /// 
  /// Esto es más confiable que `connectivity_plus` que solo verifica
  /// si hay una interfaz de red activa, no si realmente hay internet.
  /// 
  /// Intenta múltiples endpoints en orden:
  /// 1. La API configurada del usuario (si está disponible)
  /// 2. Google generate_204
  /// 3. Cloudflare
  /// 4. Apple captive portal
  /// 
  /// Retorna true si hay conexión real, false si no.
  static Future<bool> hasRealConnection({Duration? timeout, String? customUrl}) async {
    final effectiveTimeout = timeout ?? const Duration(seconds: 8);
    
    // Lista de endpoints a probar (en orden de preferencia)
    final endpoints = <String>[
      if (customUrl != null && customUrl.isNotEmpty) customUrl,
      'https://connectivitycheck.gstatic.com/generate_204', // Google (más confiable)
      'https://www.google.com/generate_204',
      'https://captive.apple.com/hotspot-detect.html', // Apple
      'https://1.1.1.1/', // Cloudflare DNS
    ];
    
    for (final url in endpoints) {
      try {
        final response = await http.get(
          Uri.parse(url),
        ).timeout(effectiveTimeout);
        
        // Cualquier respuesta exitosa indica conexión
        if (response.statusCode >= 200 && response.statusCode < 400) {
          return true;
        }
      } catch (e) {
        // Continuar con el siguiente endpoint
        continue;
      }
    }
    
    // Si todos fallan, intentar un último método: DNS lookup simulado
    try {
      final response = await http.head(
        Uri.parse('https://dns.google/'),
      ).timeout(effectiveTimeout);
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  /// Inicialización automática en background
  void _autoInitialize() {
    if (_isInitialized) return;
    
    initialize().catchError((e) {
      // Asumir offline en caso de error
      _isOnline = false;
    });
  }

  /// Inicializa el servicio de conectividad
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Verificar estado inicial
      final result = await Connectivity().checkConnectivity();
      _updateConnectivity(result);
      
      // Escuchar cambios
      _subscription = Connectivity().onConnectivityChanged.listen(_updateConnectivity);
      
      _isInitialized = true;
      
    } catch (e) {
      // En caso de error, asumir offline
      _isOnline = false;
      _isInitialized = true;
    }
  }

  /// Actualiza el estado de conectividad
  void _updateConnectivity(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((result) => result != ConnectivityResult.none);
    
    // Solo notificar si cambió el estado
    if (wasOnline != _isOnline) {
      _connectivityController.add(_isOnline);
    }
  }

  /// Libera recursos automáticamente
  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
    _isInitialized = false;
  }
}
