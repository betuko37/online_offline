import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

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
