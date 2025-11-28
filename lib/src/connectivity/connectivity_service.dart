import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Servicio de conectividad de red GLOBAL (Singleton)
/// 
/// Usa el patrón singleton para asegurar que solo haya una instancia
/// monitoreando la conectividad, evitando problemas de múltiples listeners.
class ConnectivityService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON GLOBAL
  // ═══════════════════════════════════════════════════════════════════════════
  
  static ConnectivityService? _instance;
  static final _globalController = StreamController<bool>.broadcast();
  static bool _globalIsOnline = false;
  static bool _globalIsInitialized = false;
  static StreamSubscription<List<ConnectivityResult>>? _globalSubscription;
  
  /// Obtiene la instancia global del servicio de conectividad
  static ConnectivityService get instance {
    _instance ??= ConnectivityService._internal();
    return _instance!;
  }
  
  /// Stream GLOBAL del estado de conectividad
  /// Todos los managers escuchan este mismo stream
  static Stream<bool> get globalConnectivityStream => _globalController.stream;
  
  /// Estado GLOBAL actual de conectividad
  static bool get globalIsOnline {
    if (!_globalIsInitialized) {
      // Inicializar automáticamente si no está listo
      instance._ensureGlobalInitialized();
    }
    return _globalIsOnline;
  }
  
  /// Verifica si el servicio global está inicializado
  static bool get isGlobalInitialized => _globalIsInitialized;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INSTANCIA (para compatibilidad con código existente)
  // ═══════════════════════════════════════════════════════════════════════════
  
  bool _isOnline = false;
  bool _isInitialized = false;
  final _connectivityController = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  /// Constructor interno para singleton
  ConnectivityService._internal();
  
  /// Constructor público (crea instancia que usa el singleton global internamente)
  factory ConnectivityService() {
    return instance;
  }

  /// Stream del estado de conectividad (usa el global)
  Stream<bool> get connectivityStream => _globalController.stream;
  
  /// Estado actual de conectividad (usa el global)
  bool get isOnline {
    if (!_globalIsInitialized) {
      _ensureGlobalInitialized();
    }
    return _globalIsOnline;
  }

  /// Verifica si hay conexión real a internet haciendo un ping HTTP
  static Future<bool> hasRealConnection({Duration? timeout, String? customUrl}) async {
    final effectiveTimeout = timeout ?? const Duration(seconds: 8);
    
    print('🔍 [Connectivity] Verificando conexión real...');
    
    // Lista de endpoints a probar (en orden de preferencia)
    final endpoints = <String>[
      if (customUrl != null && customUrl.isNotEmpty) customUrl,
      'https://clients3.google.com/generate_204', // Android default check
      'https://connectivitycheck.gstatic.com/generate_204', // Google fallback
      'https://www.google.com',
      'https://www.cloudflare.com',
      'https://example.com', // Neutral fallback
    ];
    
    for (final url in endpoints) {
      try {
        print('   • Probando ping a: $url');
        final response = await http.get(
          Uri.parse(url),
        ).timeout(effectiveTimeout);
        
        print('   ✅ Respuesta recibida de $url (Status: ${response.statusCode})');
        
        // Cualquier respuesta exitosa indica conexión
        if (response.statusCode >= 200 && response.statusCode < 400) {
          return true;
        }
      } catch (e) {
        print('   ⚠️ Falló ping a $url: $e');
        continue;
      }
    }
    
    // Si todos fallan, pero Connectivity dice que hay internet, 
    // asumimos que hay internet pero los pings fallaron (firewall, DNS, etc.)
    // Esto es un fallback "optimista" para no bloquear al usuario.
    if (_globalIsOnline) {
      print('⚠️ [Connectivity] Todos los pings fallaron, pero hay interfaz de red activa. Asumiendo ONLINE.');
      return true;
    }
    
    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN GLOBAL
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Asegura que el servicio global esté inicializado
  void _ensureGlobalInitialized() {
    if (_globalIsInitialized) return;
    
    initializeGlobal().catchError((e) {
      print('❌ [Connectivity] Error inicializando: $e');
      _globalIsOnline = false;
    });
  }
  
  /// Inicializa el servicio de conectividad GLOBAL
  /// Solo necesita llamarse una vez en toda la app
  static Future<void> initializeGlobal() async {
    if (_globalIsInitialized) {
      print('ℹ️ [Connectivity] Ya inicializado');
      return;
    }
    
    try {
      print('🔌 [Connectivity] Inicializando servicio global...');
      
      // Verificar estado inicial
      final result = await Connectivity().checkConnectivity();
      _updateGlobalConnectivity(result, isInitial: true);
      
      // Escuchar cambios
      _globalSubscription = Connectivity().onConnectivityChanged.listen((results) {
        _updateGlobalConnectivity(results, isInitial: false);
      });
      
      _globalIsInitialized = true;
      print('✅ [Connectivity] Servicio global inicializado. Online: $_globalIsOnline');
      
    } catch (e) {
      print('❌ [Connectivity] Error: $e');
      _globalIsOnline = false;
      _globalIsInitialized = true;
    }
  }

  /// Actualiza el estado de conectividad GLOBAL
  static void _updateGlobalConnectivity(List<ConnectivityResult> results, {required bool isInitial}) {
    final wasOnline = _globalIsOnline;
    _globalIsOnline = results.any((result) => result != ConnectivityResult.none);
    
    final resultsStr = results.map((r) => r.name).join(', ');
    print('🔌 [Connectivity] Estado: $_globalIsOnline (was: $wasOnline, results: $resultsStr)');
    
    // Solo notificar si cambió el estado (o es la primera vez)
    if (wasOnline != _globalIsOnline || isInitial) {
      print('📡 [Connectivity] Emitiendo cambio: $_globalIsOnline');
      _globalController.add(_globalIsOnline);
    }
  }
  
  /// Fuerza una verificación de conectividad y emite el resultado
  static Future<void> forceCheck() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateGlobalConnectivity(result, isInitial: false);
    } catch (e) {
      print('❌ [Connectivity] Error en forceCheck: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTODOS DE INSTANCIA (compatibilidad)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Inicialización automática en background (usa global)
  void _autoInitialize() {
    _ensureGlobalInitialized();
  }

  /// Inicializa el servicio de conectividad (usa global)
  Future<void> initialize() async {
    await initializeGlobal();
  }

  /// Libera recursos (no cierra el global, solo la instancia)
  void dispose() {
    // No cerramos el stream global, solo marcamos la instancia como no usada
    _isInitialized = false;
  }
  
  /// Libera TODOS los recursos globales (llamar solo al cerrar la app)
  static void disposeGlobal() {
    _globalSubscription?.cancel();
    _globalSubscription = null;
    // No cerramos _globalController porque es broadcast y podría haber listeners activos
    _globalIsInitialized = false;
    _globalIsOnline = false;
    _instance = null;
    print('🔌 [Connectivity] Servicio global liberado');
  }
}
