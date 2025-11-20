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

  /// Extrae datos de respuesta anidada si existe
  /// Por ejemplo: {data: [...], total: N} -> extrae el array 'data'
  static dynamic _extractNestedData(dynamic jsonData) {
    // Si es una respuesta anidada con {data: [...]}
    if (jsonData is Map<String, dynamic> && jsonData.containsKey('data')) {
      print('🔍 Detectada respuesta anidada, extrayendo array "data"');
      
      // Log de metadatos útiles si existen
      if (jsonData.containsKey('total')) {
        print('📊 Total de registros: ${jsonData['total']}');
      }
      if (jsonData.containsKey('page')) {
        print('📄 Página actual: ${jsonData['page']}');
      }
      
      return jsonData['data'];
    }
    
    // Si no es anidada, devolver tal cual
    return jsonData;
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
      
      return ApiResponse._fromHttpResponse(response, autoExtractData: false);
    } on TimeoutException {
      return ApiResponse._error('Timeout: La petición tardó demasiado', isTimeout: true);
    } catch (e) {
      // Verificar si es un error de conexión
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('failed host lookup') || 
          errorStr.contains('socketexception') ||
          errorStr.contains('network is unreachable')) {
        return ApiResponse._error('Sin conexión: No se puede conectar al servidor', isNetworkError: true);
      }
      return ApiResponse._error('Error en POST: $e');
    }
  }

  /// Obtiene datos del servidor (GET)
  /// Detecta automáticamente respuestas anidadas {data: [...]}
  Future<ApiResponse> get(String endpoint) async {
    try {
      final url = _buildFullUrl(endpoint);
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(_defaultTimeout);
      
      return ApiResponse._fromHttpResponse(response, autoExtractData: true);
    } on TimeoutException {
      return ApiResponse._error('Timeout: La petición tardó demasiado', isTimeout: true);
    } catch (e) {
      // Verificar si es un error de conexión
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('failed host lookup') || 
          errorStr.contains('socketexception') ||
          errorStr.contains('network is unreachable')) {
        return ApiResponse._error('Sin conexión: No se puede conectar al servidor', isNetworkError: true);
      }
      return ApiResponse._error('Error en GET: $e');
    }
  }
}

/// Respuesta del servidor
/// Ahora con soporte para extracción automática de datos anidados
class ApiResponse {
  final bool isSuccess;
  final int statusCode;
  final dynamic data;
  final String? error;
  final bool isTimeout;
  final bool isNetworkError;

  ApiResponse._({
    required this.isSuccess,
    required this.statusCode,
    this.data,
    this.error,
    this.isTimeout = false,
    this.isNetworkError = false,
  });

  /// Constructor desde respuesta HTTP
  /// autoExtractData: si es true, intenta extraer automáticamente datos anidados
  factory ApiResponse._fromHttpResponse(http.Response response, {bool autoExtractData = false}) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    
    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        // Decodificar JSON
        final jsonData = jsonDecode(response.body);
        
        // Extraer datos anidados si se solicita (principalmente para GET)
        if (autoExtractData) {
          data = ApiClient._extractNestedData(jsonData);
        } else {
          data = jsonData;
        }
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
  factory ApiResponse._error(String errorMessage, {bool isTimeout = false, bool isNetworkError = false}) {
    return ApiResponse._(
      isSuccess: false,
      statusCode: 0,
      error: errorMessage,
      isTimeout: isTimeout,
      isNetworkError: isNetworkError,
    );
  }
}
