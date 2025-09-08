import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Servicio de conectividad simplificado
/// 
/// Maneja monitoreo básico de conectividad:
/// - Detectar estado de conexión
/// - Stream reactivo de cambios
/// - Verificación manual
class ConnectivityService {
  /// Instancia de conectividad
  final Connectivity _connectivity = Connectivity();
  
  /// Stream controller para conectividad
  final _connectivityController = StreamController<bool>.broadcast();
  
  /// Estado actual
  bool _isConnected = false;
  
  /// Stream de conectividad
  Stream<bool> get connectivityStream => _connectivityController.stream;
  
  /// Estado actual de conectividad
  bool get isConnected => _isConnected;
  
  /// Constructor
  ConnectivityService();
  
  /// Inicializa el servicio
  Future<void> initialize() async {
    try {
      // Verificar conectividad inicial
      await _checkConnectivity();
      
      // Escuchar cambios con manejo de errores
      _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          // En caso de error, mantener estado desconectado
          _isConnected = false;
          _connectivityController.add(false);
        },
      );
    } catch (e) {
      // En caso de error, mantener estado desconectado
      _isConnected = false;
      _connectivityController.add(false);
    }
  }
  
  /// Verifica conectividad actual
  Future<bool> checkConnectivity() async {
    try {
      return await _checkConnectivity();
    } catch (e) {
      // En caso de error, retornar false
      return false;
    }
  }
  
  /// Verifica conectividad y actualiza estado
  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final wasConnected = _isConnected;
      
      // Determinar si hay conexión
      _isConnected = connectivityResults.any((result) => 
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn
      );
      
      // Emitir cambio si hubo cambio de estado
      if (wasConnected != _isConnected) {
        _connectivityController.add(_isConnected);
      }
      
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      _connectivityController.add(false);
      return false;
    }
  }
  
  /// Maneja cambios de conectividad
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _checkConnectivity();
  }
  
  /// Espera a que se establezca conexión
  /// 
  /// [timeout] - Timeout máximo
  Future<bool> waitForConnection({Duration? timeout}) async {
    if (_isConnected) return true;
    
    final completer = Completer<bool>();
    StreamSubscription? subscription;
    
    subscription = connectivityStream.listen((connected) {
      if (connected) {
        completer.complete(true);
        subscription?.cancel();
      }
    });
    
    // Timeout
    if (timeout != null) {
      Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(false);
          subscription?.cancel();
        }
      });
    }
    
    return completer.future;
  }
  
  /// Libera recursos
  void dispose() {
    _connectivityController.close();
  }
}