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
      
      // ✅ Emitir estado inicial
      _connectivityController.add(_isConnected);
      print('🔍 DEBUG - Estado inicial de conectividad: $_isConnected');
      
      // Escuchar cambios con manejo de errores
      _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          print('❌ Error en conectividad: $error');
          // En caso de error, mantener estado desconectado
          _isConnected = false;
          _connectivityController.add(false);
        },
      );
    } catch (e) {
      print('❌ Error inicializando conectividad: $e');
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
      
      // Manejar tipos inconsistentes de connectivity_plus
      List<ConnectivityResult> results;
      if (connectivityResults is List) {
        results = connectivityResults.cast<ConnectivityResult>();
      } else if (connectivityResults is String) {
        // Convertir string a ConnectivityResult
        results = [ConnectivityResult.values.firstWhere(
          (e) => e.toString().split('.').last == connectivityResults,
          orElse: () => ConnectivityResult.none,
        )];
      } else {
        results = [ConnectivityResult.none];
      }
      
      // Determinar si hay conexión
      _isConnected = results.any((result) => 
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn
      );
      
      print('🔍 DEBUG - Resultados de conectividad: $results');
      print('🔍 DEBUG - Estado de conexión: $_isConnected');
      
      // ✅ Siempre emitir el estado actual
      _connectivityController.add(_isConnected);
      
      return _isConnected;
    } catch (e) {
      print('❌ Error verificando conectividad: $e');
      _isConnected = false;
      _connectivityController.add(false);
      return false;
    }
  }
  
  /// Maneja cambios de conectividad
  void _onConnectivityChanged(dynamic results) {
    try {
      // Manejar tipos inconsistentes de connectivity_plus
      if (results is List) {
        // Es una lista, verificar conectividad
        _checkConnectivity();
      } else if (results is String) {
        // Es un string, verificar conectividad
        _checkConnectivity();
      } else {
        // Tipo desconocido, verificar conectividad
        _checkConnectivity();
      }
    } catch (e) {
      print('❌ Error en _onConnectivityChanged: $e');
      _isConnected = false;
      _connectivityController.add(false);
    }
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