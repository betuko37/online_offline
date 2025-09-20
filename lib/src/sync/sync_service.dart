import 'dart:async';
import '../api/api_client.dart';
import '../storage/local_storage.dart';
import '../models/sync_status.dart';

/// Servicio de sincronización offline-first con manejo automático
class SyncService {
  final LocalStorage _storage;
  final ApiClient _apiClient;
  final String? endpoint;

  SyncStatus _status = SyncStatus.idle;
  final _statusController = StreamController<SyncStatus>.broadcast();

  /// Stream del estado de sincronización
  Stream<SyncStatus> get statusStream => _statusController.stream;
  
  /// Estado actual
  SyncStatus get status => _status;

  SyncService({
    required LocalStorage storage,
    required this.endpoint,
    ApiClient? apiClient,
  }) : _storage = storage,
       _apiClient = apiClient ?? ApiClient();

  /// Sincroniza datos con el servidor con manejo de errores robusto
  Future<void> sync() async {
    if (endpoint == null) {
      print('⚠️ No hay endpoint configurado - sincronización omitida');
      return;
    }

    if (_status == SyncStatus.syncing) {
      print('⚠️ Sincronización ya en proceso - omitiendo');
      return;
    }

    _updateStatus(SyncStatus.syncing);

    try {
      // 1. Subir datos pendientes
      await _uploadPending();
      
      // 2. Descargar datos del servidor
      await _downloadFromServer();
      
      _updateStatus(SyncStatus.success);
      
    } catch (e) {
      _updateStatus(SyncStatus.error);
      print('❌ Error en sincronización: $e');
      // No re-lanzar el error para que la app continúe funcionando
    }
  }

  /// Sube registros pendientes al servidor con manejo robusto
  Future<void> _uploadPending() async {
    try {
      // Obtener registros que NO tienen sync: 'true' (pendientes)
      final pending = await _storage.where((item) => 
        item['sync'] != 'true' && !item.containsKey('syncDate'));
      
      if (pending.isEmpty) {
        return;
      }
      
      for (final record in pending) {
        try {
          final response = await _apiClient.post(endpoint!, record);
          
          if (response.isSuccess) {
            // Encontrar la clave del registro por created_at
            final keys = await _storage.getKeys();
            for (final key in keys) {
              final item = await _storage.get(key);
              if (item != null && 
                  item['created_at'] == record['created_at'] &&
                  item['sync'] != 'true') {
                
                // Actualizar el registro como sincronizado
                record['sync'] = 'true';  // String en lugar de bool
                record['syncDate'] = DateTime.now().toIso8601String();
                await _storage.save(key, record);
                break;
              }
            }
          }
        } catch (e) {
          // Continuar con el siguiente registro
        }
      }
    } catch (e) {
      print('❌ Error en _uploadPending: $e');
      rethrow;
    }
  }

  /// Descarga datos del servidor con manejo robusto
  Future<void> _downloadFromServer() async {
    try {
      final response = await _apiClient.get(endpoint!);
      
      if (response.isSuccess) {
        final data = response.data;
        final records = data is List ? data : [data];
        
        // Mantener registros pendientes (que no están sincronizados)
        await _storage.where((item) => 
          item['sync'] != 'true' && !item.containsKey('syncDate'));
        
        // Limpiar solo registros sincronizados
        final allData = await _storage.getAll();
        final keysToDelete = <String>[];
        final allKeys = await _storage.getKeys();
        
        for (int i = 0; i < allData.length; i++) {
          if (allData[i]['sync'] == 'true' || allData[i].containsKey('syncDate')) {
            keysToDelete.add(allKeys[i]);
          }
        }
        
        // Eliminar solo los sincronizados
        for (final key in keysToDelete) {
          await _storage.delete(key);
        }
        
        // Agregar datos del servidor como sincronizados
        for (int i = 0; i < records.length; i++) {
          final serverRecord = records[i];
          if (serverRecord is Map<String, dynamic>) {
            final record = Map<String, dynamic>.from(serverRecord);
            record['sync'] = 'true';  // String en lugar de bool
            record['syncDate'] = DateTime.now().toIso8601String();
            
            final id = 'server_${DateTime.now().millisecondsSinceEpoch}_$i';
            await _storage.save(id, record);
          }
        }
        
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Actualiza el estado de sincronización
  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
    _statusController.add(_status);
  }

  /// Obtiene datos directamente del servidor sin almacenarlos localmente
  Future<List<Map<String, dynamic>>> getDirectFromServer() async {
    if (endpoint == null) {
      throw Exception('No hay endpoint configurado');
    }

    final response = await _apiClient.get(endpoint!);

    if (!response.isSuccess) {
      throw Exception('Error HTTP ${response.statusCode}: ${response.error ?? "Error desconocido"}');
    }

    final data = response.data;
    if (data == null) {
      return [];
    }

    // Convertir la respuesta a una lista de maps
    if (data is List) {
      return data.map((item) {
        if (item is Map<String, dynamic>) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      }).toList();
    }

    // Si es un objeto único, devolverlo en una lista
    if (data is Map<String, dynamic>) {
      return [Map<String, dynamic>.from(data)];
    }

    return [];
  }

  /// Libera recursos automáticamente
  void dispose() {
    _statusController.close();
  }
}
