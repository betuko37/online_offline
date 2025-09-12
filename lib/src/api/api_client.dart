import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/global_config.dart';

/// Cliente HTTP simplificado para comunicación con el servidor
class ApiClient {
  /// Timeout por defecto para las peticiones
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Construye headers con autenticación automática
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (GlobalConfig.token != null) {
      headers['Authorization'] = 'Bearer ${GlobalConfig.token}';
    }
    
    return headers;
  }

  /// Construye URL completa desde configuración global
  String _buildFullUrl(String endpoint) {
    if (GlobalConfig.baseUrl == null) {
      throw Exception('Base URL no configurada. Usar GlobalConfig.init()');
    }
    
    final baseUrl = GlobalConfig.baseUrl!;
    final cleanBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    
    return '$cleanBase$cleanEndpoint';
  }

  /// Envía datos al servidor (POST)
  Future<ApiResponse> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final url = _buildFullUrl(endpoint);
      
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(_defaultTimeout);
      
      return ApiResponse._fromHttpResponse(response);
    } catch (e) {
      return ApiResponse._error('Error en POST: $e');
    }
  }

  /// Obtiene datos del servidor (GET)
  Future<ApiResponse> get(String endpoint) async {
    try {
      final url = _buildFullUrl(endpoint);
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(_defaultTimeout);
      
      return ApiResponse._fromHttpResponse(response);
    } catch (e) {
      return ApiResponse._error('Error en GET: $e');
    }
  }
}

/// Respuesta del servidor
class ApiResponse {
  final bool isSuccess;
  final int statusCode;
  final dynamic data;
  final String? error;

  ApiResponse._({
    required this.isSuccess,
    required this.statusCode,
    this.data,
    this.error,
  });

  /// Constructor desde respuesta HTTP
  factory ApiResponse._fromHttpResponse(http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    
    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        data = response.body;
      }
    }

    return ApiResponse._(
      isSuccess: isSuccess,
      statusCode: response.statusCode,
      data: data,
    );
  }

  /// Constructor para errores
  factory ApiResponse._error(String errorMessage) {
    return ApiResponse._(
      isSuccess: false,
      statusCode: 0,
      error: errorMessage,
    );
  }
}
