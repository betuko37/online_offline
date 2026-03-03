import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show HandshakeException, TlsException;
import 'package:http/http.dart' as http;
import '../config/global_config.dart';

/// Log que funciona tanto en foreground como en background
void _log(String message) {
  developer.log(message, name: 'ApiClient');
  print(message);
}

/// Tipo de error para diagnóstico (timeout, red, TLS, otro)
enum ApiErrorType {
  timeout,
  network,
  tlsHandshake,
  other,
}

/// Cliente HTTP simplificado para comunicación con el servidor
class ApiClient {
  /// Timeout por defecto para las peticiones
  /// Aumentado a 60 segundos para manejar mejor conexiones lentas en Android
  static const Duration _defaultTimeout = Duration(seconds: 60);
  
  /// Timeout personalizado para este cliente (opcional)
  final Duration? customTimeout;
  
  /// Cliente HTTP reutilizable con timeouts configurados
  late final http.Client _client;
  
  /// Constructor con timeout opcional
  ApiClient({this.customTimeout}) {
    // Crear cliente HTTP reutilizable
    // Nota: El paquete http de Dart no permite configurar timeouts
    // separados para conexión y lectura, por lo que usamos .timeout()
    // en cada petición individual
    _client = http.Client();
  }
  
  /// Timeout efectivo (personalizado o por defecto)
  Duration get _timeout => customTimeout ?? _defaultTimeout;
  
  /// Cerrar el cliente HTTP (llamar cuando ya no se necesite)
  void close() {
    _client.close();
  }

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

  /// Envía datos al servidor (POST) con reintentos automáticos
  Future<ApiResponse> post(String endpoint, Map<String, dynamic> data) async {
    return _executeWithRetry(() async {
      final url = _buildFullUrl(endpoint);
      final startTime = DateTime.now();
      
      // Log inicial para background
      _log('🚀 POST $endpoint iniciando...');
      
      try {
        // Usar el cliente HTTP con timeout más granular
        // El timeout se aplica a la operación completa, pero el cliente
        // maneja mejor las conexiones lentas
        final response = await _client
            .post(
              Uri.parse(url),
              headers: _headers,
              body: jsonEncode(data),
            )
            .timeout(
              _timeout,
              onTimeout: () {
                final elapsed = DateTime.now().difference(startTime);
                throw TimeoutException(
                  'Timeout: La petición tardó demasiado (${elapsed.inSeconds}s de ${_timeout.inSeconds}s)',
                  _timeout,
                );
              },
            );
        
        final elapsed = DateTime.now().difference(startTime);
        _log('✅ POST $endpoint completado en ${elapsed.inMilliseconds}ms (status: ${response.statusCode})');
        
        return ApiResponse._fromHttpResponse(response, autoExtractData: false);
      } catch (e) {
        final elapsed = DateTime.now().difference(startTime);
        if (e is TimeoutException) {
          _log('⏱️ POST $endpoint timeout después de ${elapsed.inSeconds}s (límite: ${_timeout.inSeconds}s)');
        } else {
          _log('❌ POST $endpoint error después de ${elapsed.inMilliseconds}ms: $e');
        }
        rethrow;
      }
    }, method: 'POST');
  }

  /// Obtiene datos del servidor (GET) con reintentos automáticos
  /// Detecta automáticamente respuestas anidadas {data: [...]}
  Future<ApiResponse> get(String endpoint) async {
    return _executeWithRetry(() async {
      final url = _buildFullUrl(endpoint);
      
      // Usar el cliente HTTP con timeout más granular
      final response = await _client
          .get(
            Uri.parse(url),
            headers: _headers,
          )
          .timeout(
            _timeout,
            onTimeout: () {
              throw TimeoutException(
                'Timeout: La petición tardó demasiado',
                _timeout,
              );
            },
          );
      
      return ApiResponse._fromHttpResponse(response, autoExtractData: true);
    }, method: 'GET');
  }

  /// Ejecuta una petición con política de reintentos (Exponential Backoff)
  Future<ApiResponse> _executeWithRetry(
    Future<ApiResponse> Function() requestFn, {
    required String method,
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    
    while (true) {
      attempts++;
      try {
        return await requestFn();
      } on TimeoutException catch (e) {
        if (attempts >= maxRetries) {
          print('❌ Timeout definitivo en $method después de $maxRetries intentos');
          return ApiResponse._error(
            'Timeout: La petición tardó demasiado',
            isTimeout: true,
            errorType: ApiErrorType.timeout,
          );
        }
        print('⚠️ Timeout en $method (intento $attempts/$maxRetries). Reintentando...');
        print('⏱️ Timeout después de ${_timeout.inSeconds} segundos');
        print('📝 Detalle: ${e.message}');
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        final isTlsHandshake = e is HandshakeException ||
            e is TlsException ||
            errorStr.contains('handshake') ||
            errorStr.contains('connection terminated during handshake');
        final isNetworkError = isTlsHandshake ||
            errorStr.contains('failed host lookup') ||
            errorStr.contains('socketexception') ||
            errorStr.contains('network is unreachable') ||
            errorStr.contains('connection refused') ||
            errorStr.contains('connection timed out') ||
            errorStr.contains('connection reset') ||
            errorStr.contains('software caused connection abort');

        if (!isNetworkError || attempts >= maxRetries) {
          if (isNetworkError) {
            return ApiResponse._error(
              isTlsHandshake
                  ? 'Error de conexión segura (TLS). Reintente cuando la red esté estable.'
                  : 'Sin conexión: No se puede conectar al servidor ($e)',
              isNetworkError: true,
              errorType: isTlsHandshake ? ApiErrorType.tlsHandshake : ApiErrorType.network,
            );
          }
          return ApiResponse._error('Error en $method: $e', errorType: ApiErrorType.other);
        }

        print('⚠️ Error de red en $method (intento $attempts/$maxRetries): $e');
        print('🔄 Reintentando en ${attempts * 2} segundos...');
      }
      
      // Exponential backoff: esperar 2s, 4s, 6s...
      await Future.delayed(Duration(seconds: attempts * 2));
    }
  }
}

/// Respuesta del servidor
/// Ahora con soporte para extracción automática de datos anidados y tipo de error
class ApiResponse {
  final bool isSuccess;
  final int statusCode;
  final dynamic data;
  final String? error;
  final bool isTimeout;
  final bool isNetworkError;
  final ApiErrorType? errorType;

  ApiResponse._({
    required this.isSuccess,
    required this.statusCode,
    this.data,
    this.error,
    this.isTimeout = false,
    this.isNetworkError = false,
    this.errorType,
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
  factory ApiResponse._error(
    String errorMessage, {
    bool isTimeout = false,
    bool isNetworkError = false,
    ApiErrorType? errorType,
  }) {
    return ApiResponse._(
      isSuccess: false,
      statusCode: 0,
      error: errorMessage,
      isTimeout: isTimeout,
      isNetworkError: isNetworkError,
      errorType: errorType ?? (isTimeout ? ApiErrorType.timeout : (isNetworkError ? ApiErrorType.network : ApiErrorType.other)),
    );
  }
}
