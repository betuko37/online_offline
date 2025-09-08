import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/global_config.dart';

/// Cliente HTTP simplificado
/// 
/// Maneja operaciones HTTP básicas:
/// - POST para enviar datos
/// - GET para obtener datos
/// - Headers y autenticación automática
/// - Timeouts y manejo de errores
class ApiClient {
  /// Cliente HTTP interno
  final http.Client _client;
  
  /// Timeout por defecto
  final Duration defaultTimeout;
  
  /// Constructor
  /// 
  /// [defaultTimeout] - Timeout por defecto (30 segundos)
  ApiClient({
    Duration? defaultTimeout,
  }) : _client = http.Client(),
       defaultTimeout = defaultTimeout ?? const Duration(seconds: 30);
  
  /// Construye headers con autenticación
  Map<String, String> _buildHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // Agregar token de autenticación
    final token = GlobalConfig.token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  /// Construye URL completa
  String _buildUrl(String endpoint) {
    final baseUrl = GlobalConfig.baseUrl;
    if (baseUrl == null) {
      throw Exception('Base URL no configurada');
    }
    
    // Asegurar que la base URL termine con /
    final cleanBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    // Asegurar que el endpoint no empiece con /
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    
    return '$cleanBase$cleanEndpoint';
  }
  
  /// Realiza POST request
  /// 
  /// [endpoint] - Endpoint del servidor
  /// [data] - Datos a enviar
  /// [timeout] - Timeout personalizado
  Future<ApiResponse> post(
    String endpoint, {
    dynamic data,
    Duration? timeout,
  }) async {
    try {
      final url = _buildUrl(endpoint);
      final headers = _buildHeaders();
      
      final response = await _client
          .post(
            Uri.parse(url),
            headers: headers,
            body: data != null ? jsonEncode(data) : null,
          )
          .timeout(timeout ?? defaultTimeout);
      
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
  
  /// Realiza GET request
  /// 
  /// [endpoint] - Endpoint del servidor
  /// [timeout] - Timeout personalizado
  Future<ApiResponse> get(
    String endpoint, {
    Duration? timeout,
  }) async {
    try {
      final url = _buildUrl(endpoint);
      final headers = _buildHeaders();
      
      final response = await _client
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(timeout ?? defaultTimeout);
      
      return ApiResponse.fromHttpResponse(response);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
  
  /// Libera recursos
  void dispose() {
    _client.close();
  }
}

/// Respuesta de la API
class ApiResponse {
  /// Código de estado HTTP
  final int statusCode;
  
  /// Datos de la respuesta
  final dynamic data;
  
  /// Headers de la respuesta
  final Map<String, String> headers;
  
  /// Mensaje de error si existe
  final String? error;
  
  /// Indica si la respuesta fue exitosa
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  
  /// Indica si hubo error
  bool get hasError => error != null;
  
  /// Constructor para respuesta exitosa
  ApiResponse.success({
    required this.statusCode,
    required this.data,
    required this.headers,
  }) : error = null;
  
  /// Constructor para respuesta con error
  ApiResponse.error(String errorMessage)
      : statusCode = 0,
        data = null,
        headers = {},
        error = errorMessage;
  
  /// Constructor desde respuesta HTTP
  factory ApiResponse.fromHttpResponse(http.Response response) {
    try {
      final data = response.body.isNotEmpty 
          ? jsonDecode(response.body) 
          : null;
      
      return ApiResponse.success(
        statusCode: response.statusCode,
        data: data,
        headers: response.headers,
      );
    } catch (e) {
      return ApiResponse.error('Error parsing response: $e');
    }
  }
  
  @override
  String toString() {
    return 'ApiResponse(statusCode: $statusCode, data: $data, error: $error)';
  }
}