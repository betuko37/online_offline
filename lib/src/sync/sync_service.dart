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

  SyncStatus _status = SyncStatus.idle;
  final _statusController = StreamController<SyncStatus>.broadcast();

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get status => _status;

  SyncService({
    required LocalStorage storage,
    required this.endpoint,
    ApiClient? apiClient,
    this.onSyncComplete,
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
      // 1. Subir datos pendientes
      await _uploadPending();
      
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
      return;
    }
    
    print('📤 Subiendo ${pending.length} registros pendientes...');
    
    for (final record in pending) {
      try {
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
              break;
            }
          }
        }
      } catch (e) {
        // Continuar con el siguiente
      }
    }
    
    print('✅ Registros pendientes subidos');
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

  /// Lanza error descriptivo
  void _throwError(ApiResponse response) {
    if (response.isNetworkError) {
      throw Exception('Sin conexión a internet');
    } else if (response.isTimeout) {
      throw Exception('Timeout - servidor no responde');
    } else {
      throw Exception('Error HTTP ${response.statusCode}: ${response.error}');
    }
  }

  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
    _statusController.add(_status);
  }

  void dispose() {
    _statusController.close();
  }
}
