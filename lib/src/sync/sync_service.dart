import 'dart:async';
import '../api/api_client.dart';
import '../config/sync_config.dart';

/// Servicio de sincronización simplificado
/// 
/// Maneja operaciones básicas de sincronización:
/// - Enviar registros individuales
/// - Obtener todos los registros
class SyncService {
  /// Cliente API
  final ApiClient _apiClient;
  
  /// Configuración
  final SyncConfig config;
  
  /// Constructor
  SyncService({
    required this.config,
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();
  
  /// Envía un registro individual al servidor
  /// 
  /// [endpointName] - Nombre del endpoint
  /// [record] - Registro a enviar
  Future<SyncResult> sendRecord(
    String endpointName, {
    required Map<String, dynamic> record,
  }) async {
    try {
      final endpoint = _getEndpoint(endpointName);
      
      final response = await _apiClient.post(
        endpoint.path,
        data: record,
        timeout: endpoint.timeout ?? config.network.defaultTimeout,
      );
      
      if (response.isSuccess) {
        return SyncResult.success(
          data: response.data,
          endpoint: endpointName,
        );
      } else {
        return SyncResult.error(
          'Server error: ${response.statusCode}',
          endpoint: endpointName,
        );
      }
    } catch (e) {
      return SyncResult.error(
        'Sync error: $e',
        endpoint: endpointName,
      );
    }
  }
  
  /// Obtiene todos los registros de un endpoint
  /// 
  /// [endpointName] - Nombre del endpoint
  Future<SyncResult> getAllRecords(String endpointName) async {
    try {
      final endpoint = _getEndpoint(endpointName);
      
      final response = await _apiClient.get(
        endpoint.path,
        timeout: endpoint.timeout ?? config.network.defaultTimeout,
      );
      
      if (response.isSuccess) {
        final data = response.data;
        
        // PostgreSQL retorna un array de objetos
        if (data is List) {
          final Map<String, dynamic> result = {};
          for (int i = 0; i < data.length; i++) {
            final item = data[i];
            final key = item['id']?.toString() ?? i.toString();
            result[key] = item;
          }
          
          return SyncResult.success(
            data: result,
            endpoint: endpointName,
          );
        } else {
          return SyncResult.error(
            'Invalid data format: expected List, got ${data.runtimeType}',
            endpoint: endpointName,
          );
        }
      } else {
        return SyncResult.error(
          'Server error: ${response.statusCode}',
          endpoint: endpointName,
        );
      }
    } catch (e) {
      return SyncResult.error(
        'Sync error: $e',
        endpoint: endpointName,
      );
    }
  }
  
  /// Obtiene endpoint por nombre
  EndpointConfig _getEndpoint(String endpointName) {
    final endpoint = config.endpoints
        .where((e) => e.name == endpointName)
        .firstOrNull;
    
    if (endpoint == null) {
      throw Exception('Endpoint "$endpointName" no encontrado');
    }
    
    return endpoint;
  }
  
  /// Libera recursos
  void dispose() {
    _apiClient.dispose();
  }
}

/// Resultado de operación de sincronización
class SyncResult {
  /// Indica si fue exitoso
  final bool isSuccess;
  
  /// Datos obtenidos
  final dynamic data;
  
  /// Endpoint utilizado
  final String endpoint;
  
  /// Mensaje de error
  final String? error;
  
  /// Timestamp
  final DateTime timestamp;
  
  /// Constructor exitoso
  SyncResult.success({
    required this.data,
    required this.endpoint,
  }) : isSuccess = true,
       error = null,
       timestamp = DateTime.now();
  
  /// Constructor con error
  SyncResult.error(
    String errorMessage, {
    required this.endpoint,
  }) : isSuccess = false,
       data = null,
       error = errorMessage,
       timestamp = DateTime.now();
  
  @override
  String toString() {
    return 'SyncResult(isSuccess: $isSuccess, endpoint: $endpoint, error: $error)';
  }
}