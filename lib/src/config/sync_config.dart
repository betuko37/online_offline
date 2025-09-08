import 'dart:async';

/// Configuración flexible para sincronización offline-first
class SyncConfig {
  /// Nombre del box principal de Hive
  final String boxName;
  
  /// Configuración de endpoints múltiples
  final List<EndpointConfig> endpoints;
  
  /// Token de autenticación
  final String? token;
  
  /// URL base del servidor
  final String? baseUrl;
  
  /// Configuración de sincronización automática
  final AutoSyncConfig autoSync;
  
  /// Configuración de sincronización programada
  final ScheduledSyncConfig scheduledSync;
  
  /// Configuración de red
  final NetworkConfig network;
  
  /// Configuración de logging
  final LoggingConfig logging;

  const SyncConfig({
    required this.boxName,
    required this.endpoints,
    this.token,
    this.baseUrl,
    this.autoSync = const AutoSyncConfig(),
    this.scheduledSync = const ScheduledSyncConfig(),
    this.network = const NetworkConfig(),
    this.logging = const LoggingConfig(),
  });

  /// Configuración simple para un solo endpoint
  factory SyncConfig.simple({
    required String boxName,
    required String endpoint,
    String? token,
    String? baseUrl,
    bool enableAutoSync = true,
    bool enableScheduledSync = false,
  }) {
    return SyncConfig(
      boxName: boxName,
      endpoints: [
        EndpointConfig(
          name: endpoint,
          path: endpoint,
          method: HttpMethod.get,
          syncDirection: SyncDirection.bidirectional,
        ),
      ],
      token: token,
      baseUrl: baseUrl,
      autoSync: AutoSyncConfig(enabled: enableAutoSync),
      scheduledSync: ScheduledSyncConfig(enabled: enableScheduledSync),
    );
  }

  /// Configuración avanzada para múltiples endpoints
  factory SyncConfig.advanced({
    required String boxName,
    required List<EndpointConfig> endpoints,
    String? token,
    String? baseUrl,
    AutoSyncConfig? autoSync,
    ScheduledSyncConfig? scheduledSync,
    NetworkConfig? network,
    LoggingConfig? logging,
  }) {
    return SyncConfig(
      boxName: boxName,
      endpoints: endpoints,
      token: token,
      baseUrl: baseUrl,
      autoSync: autoSync ?? const AutoSyncConfig(),
      scheduledSync: scheduledSync ?? const ScheduledSyncConfig(),
      network: network ?? const NetworkConfig(),
      logging: logging ?? const LoggingConfig(),
    );
  }
}

/// Configuración de un endpoint específico
class EndpointConfig {
  /// Nombre identificador del endpoint
  final String name;
  
  /// Ruta del endpoint (ej: 'usuarios', 'productos')
  final String path;
  
  /// Método HTTP por defecto
  final HttpMethod method;
  
  /// Dirección de sincronización
  final SyncDirection syncDirection;
  
  /// Headers personalizados para este endpoint
  final Map<String, String>? customHeaders;
  
  /// Timeout específico para este endpoint
  final Duration? timeout;
  
  /// Transformador de datos personalizado
  final DataTransformer? transformer;
  
  /// Validador de datos personalizado
  final DataValidator? validator;

  const EndpointConfig({
    required this.name,
    required this.path,
    this.method = HttpMethod.get,
    this.syncDirection = SyncDirection.bidirectional,
    this.customHeaders,
    this.timeout,
    this.transformer,
    this.validator,
  });
}

/// Configuración de sincronización automática
class AutoSyncConfig {
  /// Habilitar sincronización automática
  final bool enabled;
  
  /// Sincronizar solo cuando hay cambios locales
  final bool syncOnlyOnChanges;
  
  /// Retraso antes de sincronizar (para evitar múltiples syncs)
  final Duration delay;
  
  /// Máximo número de reintentos
  final int maxRetries;
  
  /// Intervalo entre reintentos
  final Duration retryInterval;

  const AutoSyncConfig({
    this.enabled = true,
    this.syncOnlyOnChanges = true,
    this.delay = const Duration(seconds: 2),
    this.maxRetries = 3,
    this.retryInterval = const Duration(seconds: 5),
  });
}

/// Configuración de sincronización programada
class ScheduledSyncConfig {
  /// Habilitar sincronización programada
  final bool enabled;
  
  /// Intervalo de sincronización
  final Duration interval;
  
  /// Sincronizar solo si hay internet
  final bool syncOnlyOnline;
  
  /// Sincronizar solo si hay cambios pendientes
  final bool syncOnlyPending;

  const ScheduledSyncConfig({
    this.enabled = false,
    this.interval = const Duration(minutes: 30),
    this.syncOnlyOnline = true,
    this.syncOnlyPending = true,
  });
}

/// Configuración de red
class NetworkConfig {
  /// Timeout por defecto para requests
  final Duration defaultTimeout;
  
  /// Verificar conectividad antes de sincronizar
  final bool checkConnectivity;
  
  /// Esperar estabilidad de red antes de sincronizar
  final bool waitForStableConnection;
  
  /// Duración mínima de conexión estable
  final Duration stableConnectionDuration;

  const NetworkConfig({
    this.defaultTimeout = const Duration(seconds: 30),
    this.checkConnectivity = true,
    this.waitForStableConnection = false,
    this.stableConnectionDuration = const Duration(seconds: 5),
  });
}

/// Configuración de logging
class LoggingConfig {
  /// Habilitar logging
  final bool enabled;
  
  /// Nivel de logging
  final LogLevel level;
  
  /// Incluir datos en los logs
  final bool includeData;
  
  /// Incluir headers en los logs
  final bool includeHeaders;

  const LoggingConfig({
    this.enabled = true,
    this.level = LogLevel.info,
    this.includeData = false,
    this.includeHeaders = false,
  });
}

/// Métodos HTTP soportados
enum HttpMethod {
  get,
  post,
  put,
  patch,
  delete,
}

/// Dirección de sincronización
enum SyncDirection {
  /// Sincronización bidireccional (local ↔ servidor)
  bidirectional,
  /// Solo descargar del servidor
  downloadOnly,
  /// Solo subir al servidor
  uploadOnly,
}

/// Niveles de logging
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Transformador de datos personalizado
abstract class DataTransformer {
  /// Transformar datos antes de guardar localmente
  Map<String, dynamic>? transformForLocal(Map<String, dynamic> data);
  
  /// Transformar datos antes de enviar al servidor
  Map<String, dynamic>? transformForServer(Map<String, dynamic> data);
  
  /// Transformar respuesta del servidor
  List<Map<String, dynamic>>? transformServerResponse(dynamic response);
}

/// Validador de datos personalizado
abstract class DataValidator {
  /// Validar datos antes de guardar localmente
  bool validateLocal(Map<String, dynamic> data);
  
  /// Validar datos antes de enviar al servidor
  bool validateServer(Map<String, dynamic> data);
  
  /// Validar respuesta del servidor
  bool validateServerResponse(dynamic response);
}

/// Configuración de sincronización para casos específicos
class SyncRule {
  /// Condición para aplicar esta regla
  final SyncCondition condition;
  
  /// Acción a realizar
  final SyncAction action;
  
  /// Prioridad de la regla (mayor número = mayor prioridad)
  final int priority;

  const SyncRule({
    required this.condition,
    required this.action,
    this.priority = 0,
  });
}

/// Condiciones para reglas de sincronización
abstract class SyncCondition {
  bool evaluate(Map<String, dynamic> context);
}

/// Acciones para reglas de sincronización
abstract class SyncAction {
  Future<void> execute(Map<String, dynamic> context);
}

/// Ejemplos de condiciones predefinidas
class NetworkCondition extends SyncCondition {
  final bool requireOnline;
  
  NetworkCondition({this.requireOnline = true});
  
  @override
  bool evaluate(Map<String, dynamic> context) {
    final isOnline = context['isOnline'] as bool? ?? false;
    return requireOnline ? isOnline : !isOnline;
  }
}

class DataSizeCondition extends SyncCondition {
  final int maxSize;
  
  DataSizeCondition(this.maxSize);
  
  @override
  bool evaluate(Map<String, dynamic> context) {
    final dataSize = context['dataSize'] as int? ?? 0;
    return dataSize <= maxSize;
  }
}

/// Ejemplos de acciones predefinidas
class DefaultSyncAction extends SyncAction {
  final String endpoint;
  final SyncDirection direction;
  
  DefaultSyncAction({
    required this.endpoint,
    required this.direction,
  });
  
  @override
  Future<void> execute(Map<String, dynamic> context) async {
    // Implementación será manejada por el SyncManager
    context['pendingSync'] = {
      'endpoint': endpoint,
      'direction': direction,
    };
  }
}
