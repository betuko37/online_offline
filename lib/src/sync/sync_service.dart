import 'dart:async';
import '../api/api_client.dart';
import '../storage/local_storage.dart';
import '../models/sync_status.dart';
import '../config/global_config.dart';
import '../cache/cache_manager.dart';

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
      
      // 2. Descargar datos del servidor (manual - siempre sincroniza)
      await _downloadFromServerManual();
      
      _updateStatus(SyncStatus.success);
      
    } catch (e) {
      _updateStatus(SyncStatus.error);
      print('❌ Error en sincronización: $e');
      // No re-lanzar el error para que la app continúe funcionando
    }
  }

  /// Sincronización forzada que ignora el caché de tiempo
  Future<void> forceSync() async {
    if (endpoint == null) {
      print('⚠️ No hay endpoint configurado - sincronización forzada omitida');
      return;
    }

    if (_status == SyncStatus.syncing) {
      print('⚠️ Sincronización ya en proceso - omitiendo');
      return;
    }

    _updateStatus(SyncStatus.syncing);

    try {
      print('🔄 Iniciando sincronización forzada...');
      
      // 1. Subir datos pendientes
      await _uploadPending();
      
      // 2. Descargar datos del servidor (manual - siempre sincroniza)
      await _downloadFromServerManual();
      
      _updateStatus(SyncStatus.success);
      print('✅ Sincronización forzada completada');
      
    } catch (e) {
      _updateStatus(SyncStatus.error);
      print('❌ Error en sincronización forzada: $e');
      // No re-lanzar el error para que la app continúe funcionando
    }
  }

  /// Sincronización inmediata que omite todas las verificaciones
  Future<void> syncNow() async {
    if (endpoint == null) {
      print('⚠️ No hay endpoint configurado - sincronización inmediata omitida');
      return;
    }

    if (_status == SyncStatus.syncing) {
      print('⚠️ Sincronización ya en proceso - omitiendo');
      return;
    }

    _updateStatus(SyncStatus.syncing);

    try {
      print('🔄 Iniciando sincronización inmediata...');
      
      // 1. Subir datos pendientes
      await _uploadPending();
      
      // 2. Descargar datos del servidor (manual - siempre sincroniza)
      await _downloadFromServerManual();
      
      _updateStatus(SyncStatus.success);
      print('✅ Sincronización inmediata completada');
      
    } catch (e) {
      _updateStatus(SyncStatus.error);
      print('❌ Error en sincronización inmediata: $e');
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

  /// Descarga datos del servidor para sincronización manual (siempre sincroniza)
  Future<void> _downloadFromServerManual() async {
    try {
      if (GlobalConfig.useIncrementalSync) {
        print('🔄 Usando sincronización incremental optimizada (manual)');
        await _downloadIncremental();
      } else {
        print('🔄 Usando descarga completa (manual)');
        await _downloadFull();
      }
    } catch (e) {
      rethrow;
    }
  }
  
  /// Descarga completa de datos (comportamiento original)
  /// Ahora maneja los últimos 50 registros por temporada del backend
  Future<void> _downloadFull() async {
    final response = await _apiClient.get(endpoint!);
    
    if (response.isSuccess) {
      final data = response.data;
      final records = data is List ? data : [data];
      
      print('📥 Descargados ${records.length} registros del servidor');
      
      // Mantener registros pendientes (que no están sincronizados)
      final pendingRecords = await _storage.where((item) => 
        item['sync'] != 'true' && !item.containsKey('syncDate'));
      
      print('💾 Manteniendo ${pendingRecords.length} registros pendientes');
      
      // Limpiar solo registros sincronizados (del servidor)
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
      
      print('🗑️ Eliminados ${keysToDelete.length} registros sincronizados antiguos');
      
      // Agregar datos del servidor como sincronizados
      // El backend ahora envía los últimos 50 por temporada, así que los guardamos directamente
      for (int i = 0; i < records.length; i++) {
        final serverRecord = records[i];
        if (serverRecord is Map<String, dynamic>) {
          final record = Map<String, dynamic>.from(serverRecord);
          record['sync'] = 'true';  // String en lugar de bool
          record['syncDate'] = DateTime.now().toIso8601String();
          
          // Usar el ID del servidor si existe, sino generar uno
          final recordId = record['id']?.toString() ?? 'server_${DateTime.now().millisecondsSinceEpoch}_$i';
          await _storage.save(recordId, record);
        }
      }
      
      print('✅ Guardados ${records.length} registros del servidor');
      
    } else {
      // Proporcionar mensajes de error más descriptivos
      if (response.isNetworkError) {
        throw Exception('Sin conexión a internet o servidor no disponible');
      } else if (response.isTimeout) {
        throw Exception('La petición tardó demasiado tiempo (timeout)');
      } else if (response.statusCode == 0) {
        throw Exception('Error de red: ${response.error ?? "No se pudo conectar al servidor"}');
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.error ?? "Error desconocido"}');
      }
    }
  }

  /// Descarga incremental de datos (solo nuevos/modificados)
  Future<void> _downloadIncremental() async {
    print('🔄 Iniciando sincronización incremental...');
    
    // Obtener timestamp de última sincronización
    final lastSyncTime = await CacheManager.getLastSyncTime(_storage.boxName);
    final since = lastSyncTime ?? DateTime.now().subtract(const Duration(days: 30));
    
    print('📅 Sincronizando desde: $since');
    
    // Obtener registros existentes para comparación
    final existingRecords = await _storage.getAll();
    final existingIds = <String>{};
    final existingTimestamps = <String, DateTime>{};
    final existingKeys = <String, String>{}; // Mapeo de ID a clave de almacenamiento
    
    // Crear mapas de registros existentes para comparación rápida
    for (final record in existingRecords) {
      final id = record['id']?.toString();
      if (id != null) {
        existingIds.add(id);
        
        // Buscar la clave de almacenamiento para este ID
        final keys = await _storage.getKeys();
        for (final key in keys) {
          final storedRecord = await _storage.get(key);
          if (storedRecord != null && storedRecord['id']?.toString() == id) {
            existingKeys[id] = key;
            break;
          }
        }
      }
      
      final timestamp = _extractTimestamp(record);
      if (timestamp != null && id != null) {
        existingTimestamps[id] = timestamp;
      }
    }
    
    print('📊 Registros existentes: ${existingIds.length}');
    
    int offset = 0;
    int totalDownloaded = 0;
    int newRecords = 0;
    int updatedRecords = 0;
    int skippedRecords = 0;
    bool hasMoreData = true;
    DateTime? latestTimestamp;
    int consecutiveEmptyPages = 0;
    
    while (hasMoreData) {
      print('📥 Descargando página ${(offset / GlobalConfig.pageSize).floor() + 1}...');
      
      final response = await _apiClient.get(
        '${endpoint!}?since=${since.toIso8601String()}&limit=${GlobalConfig.pageSize}&offset=$offset&last_modified_field=${GlobalConfig.lastModifiedField}',
      );
      
      if (!response.isSuccess) {
        // Proporcionar mensajes de error más descriptivos
        if (response.isNetworkError) {
          throw Exception('Sin conexión a internet o servidor no disponible');
        } else if (response.isTimeout) {
          throw Exception('La petición tardó demasiado tiempo (timeout)');
        } else if (response.statusCode == 0) {
          throw Exception('Error de red: ${response.error ?? "No se pudo conectar al servidor"}');
        } else {
          throw Exception('Error HTTP ${response.statusCode}: ${response.error ?? "Error desconocido"}');
        }
      }
      
      final data = response.data;
      final records = data is List ? data : [data];
      
      if (records.isEmpty) {
        consecutiveEmptyPages++;
        if (consecutiveEmptyPages >= 2) {
          print('⏹️ Detenido - 2 páginas consecutivas vacías');
          hasMoreData = false;
          break;
        }
        offset += GlobalConfig.pageSize;
        continue;
      }
      
      consecutiveEmptyPages = 0; // Reset contador
      
      // Procesar registros de esta página
      for (final serverRecord in records) {
        if (serverRecord is Map<String, dynamic>) {
          final record = Map<String, dynamic>.from(serverRecord);
          final recordId = record['id']?.toString();
          
          if (recordId == null) {
            continue; // Saltar registros sin ID
          }
          
          // Actualizar timestamp más reciente
          final recordTimestamp = _extractTimestamp(record);
          if (recordTimestamp != null && 
              (latestTimestamp == null || recordTimestamp.isAfter(latestTimestamp))) {
            latestTimestamp = recordTimestamp;
          }
          
          // Verificar si es un registro nuevo o modificado
          final isNewRecord = !existingIds.contains(recordId);
          final isModifiedRecord = !isNewRecord && 
              existingTimestamps.containsKey(recordId) &&
              recordTimestamp != null &&
              recordTimestamp.isAfter(existingTimestamps[recordId]!);
          
          if (isNewRecord) {
            // Agregar nuevo registro
            record['sync'] = 'true';
            record['syncDate'] = DateTime.now().toIso8601String();
            await _storage.save(recordId, record);
            newRecords++;
            print('➕ Nuevo registro: $recordId');
          } else if (isModifiedRecord) {
            // Actualizar registro existente usando la clave correcta
            record['sync'] = 'true';
            record['syncDate'] = DateTime.now().toIso8601String();
            final existingKey = existingKeys[recordId];
            if (existingKey != null) {
              await _storage.save(existingKey, record);
              updatedRecords++;
              print('🔄 Registro actualizado: $recordId');
            } else {
              // Si no encontramos la clave, crear nuevo
              await _storage.save(recordId, record);
              newRecords++;
              print('➕ Nuevo registro (clave no encontrada): $recordId');
            }
          } else {
            // Registro sin cambios, saltar
            skippedRecords++;
            continue;
          }
          
          totalDownloaded++;
        }
      }
      
      // Si recibimos menos registros que el límite, no hay más datos
      if (records.length < GlobalConfig.pageSize) {
        hasMoreData = false;
      } else {
        offset += GlobalConfig.pageSize;
      }
      
      // Límite de páginas por sincronización
      final currentPage = (offset / GlobalConfig.pageSize).floor() + 1;
      if (currentPage > GlobalConfig.maxPagesPerSync) {
        print('⚠️ Límite de páginas alcanzado (${GlobalConfig.maxPagesPerSync} páginas)');
        hasMoreData = false;
      }
      
      // Límite de seguridad para evitar bucles infinitos
      if (offset > 10000) {
        print('⚠️ Límite de seguridad alcanzado en sincronización incremental');
        hasMoreData = false;
      }
      
      // Si no hay cambios en esta página, considerar detener
      if (totalDownloaded == 0 && offset > GlobalConfig.pageSize * 2) {
        print('⏹️ Detenido - no hay cambios en las primeras páginas');
        hasMoreData = false;
      }
    }
    
    // Limpiar duplicados después de la sincronización
    await _cleanDuplicates();
    
    // Actualizar timestamp de última sincronización
    await CacheManager.updateLastSyncTime(_storage.boxName);
    
    print('✅ Sincronización incremental completada:');
    print('   📊 Total procesados: $totalDownloaded');
    print('   ➕ Nuevos registros: $newRecords');
    print('   🔄 Registros actualizados: $updatedRecords');
    print('   ⏭️ Registros omitidos: $skippedRecords');
  }
  
  /// Limpia registros duplicados basándose en el ID
  Future<void> _cleanDuplicates() async {
    print('🧹 Limpiando duplicados...');
    
    final allKeys = await _storage.getKeys();
    final idToKeyMap = <String, String>{};
    final duplicatesToDelete = <String>[];
    
    // Mapear IDs a claves de almacenamiento
    for (final key in allKeys) {
      final record = await _storage.get(key);
      if (record != null && record['id'] != null) {
        final id = record['id'].toString();
        if (idToKeyMap.containsKey(id)) {
          // Ya existe un registro con este ID, marcar para eliminar
          duplicatesToDelete.add(key);
          print('🗑️ Duplicado encontrado: $id (clave: $key)');
        } else {
          idToKeyMap[id] = key;
        }
      }
    }
    
    // Eliminar duplicados
    for (final key in duplicatesToDelete) {
      await _storage.delete(key);
    }
    
    if (duplicatesToDelete.isNotEmpty) {
      print('✅ Eliminados ${duplicatesToDelete.length} registros duplicados');
    } else {
      print('✅ No se encontraron duplicados');
    }
  }

  /// Extrae timestamp de un registro
  DateTime? _extractTimestamp(Map<String, dynamic> record) {
    final timestampField = GlobalConfig.lastModifiedField;
    final timestampValue = record[timestampField];
    
    if (timestampValue is String) {
      try {
        return DateTime.parse(timestampValue);
      } catch (e) {
        return null;
      }
    }
    
    return null;
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
      // Proporcionar mensajes de error más descriptivos
      if (response.isNetworkError) {
        throw Exception('Sin conexión a internet o servidor no disponible');
      } else if (response.isTimeout) {
        throw Exception('La petición tardó demasiado tiempo (timeout)');
      } else if (response.statusCode == 0) {
        throw Exception('Error de red: ${response.error ?? "No se pudo conectar al servidor"}');
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.error ?? "Error desconocido"}');
      }
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

  /// Limpia registros duplicados manualmente
  Future<void> cleanDuplicates() async {
    await _cleanDuplicates();
  }

  /// Libera recursos automáticamente
  void dispose() {
    _statusController.close();
  }
}
