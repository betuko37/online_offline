import 'package:http/http.dart' as http;
import 'dart:convert';

/// Gestor de base de datos remota con endpoints configurables
/// Permite al usuario especificar la URL base y construir rutas específicas
class RemoteDB {
  final String baseUrl;
  final Map<String, String> defaultHeaders;
  final Duration timeout;

  RemoteDB({
    required this.baseUrl,
    this.defaultHeaders = const {'Content-Type': 'application/json'},
    this.timeout = const Duration(seconds: 30),
  });

  /// Construye una URL completa con el endpoint especificado
  String _buildUrl(String endpoint) {
    // Asegurar que la URL base termine con /
    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    // Asegurar que el endpoint no empiece con /
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return '$cleanBaseUrl$cleanEndpoint';
  }

  /// Realiza una petición GET a un endpoint específico
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    try {
      final url = _buildUrl(endpoint);
      final response = await http.get(
        Uri.parse(url),
        headers: {...defaultHeaders, ...?headers},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw RemoteDBException(
          'Error GET $endpoint: ${response.statusCode} - ${response.body}',
          response.statusCode,
        );
      }
    } catch (e) {
      throw RemoteDBException('Error en GET $endpoint: $e', 0);
    }
  }

  /// Realiza una petición POST a un endpoint específico
  Future<dynamic> post(String endpoint, Map<String, dynamic> data, {Map<String, String>? headers}) async {
    try {
      final url = _buildUrl(endpoint);
      final response = await http.post(
        Uri.parse(url),
        body: jsonEncode(data),
        headers: {...defaultHeaders, ...?headers},
      ).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        throw RemoteDBException(
          'Error POST $endpoint: ${response.statusCode} - ${response.body}',
          response.statusCode,
        );
      }
    } catch (e) {
      throw RemoteDBException('Error en POST $endpoint: $e', 0);
    }
  }

  /// Realiza una petición PUT a un endpoint específico
  Future<dynamic> put(String endpoint, Map<String, dynamic> data, {Map<String, String>? headers}) async {
    try {
      final url = _buildUrl(endpoint);
      final response = await http.put(
        Uri.parse(url),
        body: jsonEncode(data),
        headers: {...defaultHeaders, ...?headers},
      ).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        throw RemoteDBException(
          'Error PUT $endpoint: ${response.statusCode} - ${response.body}',
          response.statusCode,
        );
      }
    } catch (e) {
      throw RemoteDBException('Error en PUT $endpoint: $e', 0);
    }
  }

  /// Realiza una petición DELETE a un endpoint específico
  Future<dynamic> delete(String endpoint, {Map<String, String>? headers}) async {
    try {
      final url = _buildUrl(endpoint);
      final response = await http.delete(
        Uri.parse(url),
        headers: {...defaultHeaders, ...?headers},
      ).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        throw RemoteDBException(
          'Error DELETE $endpoint: ${response.statusCode} - ${response.body}',
          response.statusCode,
        );
      }
    } catch (e) {
      throw RemoteDBException('Error en DELETE $endpoint: $e', 0);
    }
  }

  /// Obtiene una lista de elementos de un endpoint específico
  Future<List<Map<String, dynamic>>> fetchAll(String endpoint, {Map<String, String>? headers}) async {
    try {
      final response = await get(endpoint, headers: headers);
      
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else if (response is Map<String, dynamic>) {
        // Si la respuesta es un objeto con una propiedad que contiene la lista
        if (response.containsKey('data') && response['data'] is List) {
          return List<Map<String, dynamic>>.from(response['data']);
        } else if (response.containsKey('items') && response['items'] is List) {
          return List<Map<String, dynamic>>.from(response['items']);
        } else if (response.containsKey('results') && response['results'] is List) {
          return List<Map<String, dynamic>>.from(response['results']);
        }
      }
      
      throw RemoteDBException('Formato de respuesta no válido para fetchAll', 0);
    } catch (e) {
      throw RemoteDBException('Error en fetchAll $endpoint: $e', 0);
    }
  }

  /// Sube datos a un endpoint específico
  Future<dynamic> upload(String endpoint, Map<String, dynamic> data, {Map<String, String>? headers}) async {
    return await post(endpoint, data, headers: headers);
  }

  /// Realiza una petición con autenticación Bearer
  Future<dynamic> authenticatedRequest(
    String method,
    String endpoint,
    String token, {
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    final authHeaders = {
      ...defaultHeaders,
      'Authorization': 'Bearer $token',
      ...?headers,
    };

    switch (method.toUpperCase()) {
      case 'GET':
        return await get(endpoint, headers: authHeaders);
      case 'POST':
        return await post(endpoint, data ?? {}, headers: authHeaders);
      case 'PUT':
        return await put(endpoint, data ?? {}, headers: authHeaders);
      case 'DELETE':
        return await delete(endpoint, headers: authHeaders);
      default:
        throw RemoteDBException('Método HTTP no soportado: $method', 0);
    }
  }

  /// Verifica la conectividad con el servidor
  Future<bool> checkConnectivity() async {
    try {
      await get('health'); // Endpoint común para verificar salud del servidor
      return true;
    } catch (e) {
      try {
        await get(''); // Intentar con la raíz si no existe /health
        return true;
      } catch (e) {
        return false;
      }
    }
  }
}

/// Excepción personalizada para errores de RemoteDB
class RemoteDBException implements Exception {
  final String message;
  final int statusCode;

  RemoteDBException(this.message, this.statusCode);

  @override
  String toString() => 'RemoteDBException: $message (Status: $statusCode)';
}
