import 'dart:async';
import '../api/api_client.dart';
import '../storage/local_storage.dart';
import '../models/sync_status.dart';
import '../cache/cache_manager.dart';

/// Servicio de sincronización offline-first simplificado
/// 
/// La sincronización es simple:
/// 1. Sube datos pendientes al servidor
/// 2. Descarga todos los datos del servidor
class SyncService {
  final LocalStorage _storage;
  final ApiClient _apiClient;
  final String? endpoint;
  final Future<void> Function()? onSyncComplete;
  final bool uploadEnabled; // Si es false, solo hace GET (download), no POST (upload)

  SyncStatus _status = SyncStatus.idle;
  final _statusController = StreamController<SyncStatus>.broadcast();

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get status => _status;

  SyncService({
    required LocalStorage storage,
    required this.endpoint,
    ApiClient? apiClient,
    this.onSyncComplete,
    this.uploadEnabled = false,
  }) : _storage = storage,
       _apiClient = apiClient ?? ApiClient();

  /// Sincroniza datos con el servidor
  Future<void> sync() async {
    if (endpoint == null) {
      print('⚠️ No hay endpoint configurado');
      return;
    }

    if (_status == SyncStatus.syncing) {
      print('⚠️ Sincronización ya en proceso');
      return;
    }

    _updateStatus(SyncStatus.syncing);

    try {
      // 1. Subir datos pendientes (solo si uploadEnabled es true)
      if (uploadEnabled) {
        await _uploadPending();
      } else {
        print('ℹ️ Upload deshabilitado para este manager, solo descargando...');
      }
      
      // 2. Descargar datos del servidor
      await _downloadFromServer();
      
      // 3. Actualizar timestamp de última sincronización
      await CacheManager.updateLastSyncTime(_storage.boxName);
      
      _updateStatus(SyncStatus.success);
      print('✅ Sincronización completada');
      
      // Notificar callback
      if (onSyncComplete != null) {
        try {
          await onSyncComplete!();
        } catch (e) {
          // Error silencioso
        }
      }
      
    } catch (e) {
      _updateStatus(SyncStatus.error);
      print('❌ Error en sincronización: $e');
    }
  }

  /// Sube registros pendientes al servidor
  Future<void> _uploadPending() async {
    final pending = await _storage.where((item) => 
      item['sync'] != 'true' && !item.containsKey('syncDate'));
    
    if (pending.isEmpty) {
      print('📤 No hay registros pendientes para subir');
      return;
    }
    
    print('📤 Subiendo ${pending.length} registros pendientes...');
    
    int successCount = 0;
    int failCount = 0;
    String? lastError;
    
    for (final record in pending) {
      try {
        print('📤 Enviando POST para registro: ${record['id'] ?? record['created_at'] ?? 'sin-id'}');
        final response = await _apiClient.post(endpoint!, record);
        
        if (response.isSuccess) {
          // Marcar como sincronizado
          final keys = await _storage.getKeys();
          for (final key in keys) {
            final item = await _storage.get(key);
            if (item != null && 
                item['created_at'] == record['created_at'] &&
                item['sync'] != 'true') {
              record['sync'] = 'true';
              record['syncDate'] = DateTime.now().toIso8601String();
              await _storage.save(key, record);
              successCount++;
              print('✅ Registro sincronizado: ${record['id'] ?? record['created_at']}');
              break;
            }
          }
        } else {
          failCount++;
          lastError = response.error ?? 'Error HTTP ${response.statusCode}';
          print('❌ POST falló para registro: $lastError');
          
          // Error del cliente (4xx) - no reintentar, continuar con siguiente
          if (response.statusCode >= 400 && response.statusCode < 500) {
            print('⚠️ Error del cliente (${response.statusCode}), saltando registro');
            continue;
          }
          // Error del servidor (5xx) o timeout - propagar error
          throw Exception('Error en POST: $lastError');
        }
      } catch (e) {
        failCount++;
        lastError = e.toString();
        print('❌ Error en POST para registro: $e');
        // Propagar el error para que se detecte el fallo
        if (failCount >= pending.length) {
          // Si es el último y todos fallaron, propagar
          rethrow;
        }
        // Si hay más registros, continuar intentando
      }
    }
    
    print('📊 Registros pendientes procesados: $successCount exitosos, $failCount fallidos');
    
    // Si todos fallaron, lanzar error
    if (successCount == 0 && failCount > 0) {
      throw Exception('Todos los POSTs fallaron ($failCount intentos). Último error: $lastError');
    }
  }

  /// Descarga todos los datos del servidor
  Future<void> _downloadFromServer() async {
    print('📥 Descargando datos del servidor...');
    
    final response = await _apiClient.get(endpoint!);
    
    if (!response.isSuccess) {
      _throwError(response);
    }
    
    final data = response.data;
    final records = data is List ? data : [data];
    
    print('📥 ${records.length} registros recibidos');
    
    // Nota: Los registros pendientes se mantienen porque solo eliminamos
    // los que tienen sync='true' o syncDate
    
    // Eliminar registros sincronizados antiguos
    final allData = await _storage.getAll();
    final allKeys = await _storage.getKeys();
    
    for (int i = 0; i < allData.length; i++) {
      if (allData[i]['sync'] == 'true' || allData[i].containsKey('syncDate')) {
        await _storage.delete(allKeys[i]);
      }
    }
    
    // Guardar nuevos registros del servidor
    for (int i = 0; i < records.length; i++) {
      final serverRecord = records[i];
      if (serverRecord is Map<String, dynamic>) {
        final record = Map<String, dynamic>.from(serverRecord);
        record['sync'] = 'true';
        record['syncDate'] = DateTime.now().toIso8601String();
        
        final recordId = record['id']?.toString() ?? 
          'server_${DateTime.now().millisecondsSinceEpoch}_$i';
        await _storage.save(recordId, record);
      }
    }
    
    print('✅ ${records.length} registros guardados');
  }

  /// Lanza error descriptivo (usa errorType cuando está disponible para mensajes más claros)
  void _throwError(ApiResponse response) {
    if (response.errorType == ApiErrorType.tlsHandshake) {
      throw Exception('Conexión segura fallida (TLS). Compruebe la red e intente de nuevo.');
    }
    if (response.isNetworkError) {
      throw Exception('Sin conexión a internet');
    }
    if (response.isTimeout) {
      throw Exception('Timeout - servidor no responde');
    }
    throw Exception('Error HTTP ${response.statusCode}: ${response.error}');
  }

  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
    _statusController.add(_status);
  }

  void dispose() {
    _statusController.close();
  }
}
