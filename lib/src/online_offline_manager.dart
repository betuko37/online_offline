import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'config/global_config.dart';

/// Estados simples para sincronización
enum SyncStatus { idle, syncing, success, error }

/// Manager super simple para offline-first
/// Uso básico: crea, guarda, sincroniza automáticamente
class OnlineOfflineManager {
  final String boxName;
  final String? endpoint;
  
  Box? _box;
  bool _isOnline = false;
  SyncStatus _status = SyncStatus.idle;
  
  // Streams básicos
  final _dataStream = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _statusStream = StreamController<SyncStatus>.broadcast();
  
  // Getters simples
  Stream<List<Map<String, dynamic>>> get dataStream => _dataStream.stream;
  Stream<SyncStatus> get statusStream => _statusStream.stream;
  SyncStatus get status => _status;
  bool get isOnline => _isOnline;
  
  OnlineOfflineManager({
    required this.boxName,
    this.endpoint,
  }) {
    _init();
  }
  
  /// Construir URL completa desde configuración global
  String? get _fullUrl {
    if (endpoint == null || GlobalConfig.baseUrl == null) return null;
    
    final baseUrl = GlobalConfig.baseUrl!;
    final cleanBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final cleanEndpoint = endpoint!.startsWith('/') ? endpoint!.substring(1) : endpoint!;
    
    return '$cleanBase$cleanEndpoint';
  }
  
  /// Headers con token automático
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
  
  /// Inicialización simple
  Future<void> _init() async {
    try {
      // Setup Hive
      await Hive.initFlutter();
      _box = await Hive.openBox(boxName);
      
      // Setup conectividad
      Connectivity().onConnectivityChanged.listen((result) {
        _isOnline = result != ConnectivityResult.none;
        if (_isOnline && _fullUrl != null) sync();
      });
      
      // Estado inicial
      final result = await Connectivity().checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
      
      // Cargar datos
      _notifyData();
      
    } catch (e) {
      print('❌ Error: $e');
    }
  }
  
  /// ===========================================
  /// OPERACIONES BÁSICAS
  /// ===========================================
  
  /// Crear/guardar datos
  Future<void> save(Map<String, dynamic> data) async {
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    data['created_at'] = DateTime.now().toIso8601String();
    
    await _box!.put(id, data);
    _notifyData();
    
    print('✅ Guardado localmente: $id');
    
    // Auto-sync si hay internet
    if (_isOnline && _fullUrl != null) sync();
  }
  
  /// Obtener por ID
  Future<Map<String, dynamic>?> getById(String id) async {
    final data = _box!.get(id);
    return data != null ? Map<String, dynamic>.from(data) : null;
  }
  
  /// Obtener todos
  Future<List<Map<String, dynamic>>> getAll() async {
    return _box!.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  
  /// Eliminar
  Future<void> delete(String id) async {
    await _box!.delete(id);
    _notifyData();
  }
  
  /// ===========================================
  /// SINCRONIZACIÓN SIMPLE
  /// ===========================================
  
  /// Sincronizar con servidor
  Future<void> sync() async {
    if (_fullUrl == null || !_isOnline) return;
    
    _status = SyncStatus.syncing;
    _statusStream.add(_status);
    
    try {
      // 1. Subir pendientes
      await _uploadPending();
      
      // 2. Descargar del servidor
      await _downloadFromServer();
      
      _status = SyncStatus.success;
      print('✨ Sync exitoso');
      
    } catch (e) {
      _status = SyncStatus.error;
      print('❌ Error sync: $e');
    }
    
    _statusStream.add(_status);
    _notifyData();
  }
  
  /// Subir registros pendientes
  Future<void> _uploadPending() async {
    final all = await getAll();
    // Los registros que no tienen 'sync' son locales pendientes
    final pending = all.where((item) => !item.containsKey('sync')).toList();
    
    for (final record in pending) {
      try {
        final response = await http.post(
          Uri.parse(_fullUrl!),
          headers: _headers,
          body: jsonEncode(record),
        ).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Encontrar y eliminar el registro local
          final keys = _box!.keys.where((key) {
            final item = _box!.get(key);
            return item != null && 
                   item['created_at'] == record['created_at'] &&
                   !item.containsKey('sync');
          }).toList();
          
          // Eliminar el registro local
          for (final key in keys) {
            await _box!.delete(key);
          }
          
          // Agregar como registro sincronizado
          record['sync'] = DateTime.now().toIso8601String();
          final syncId = 'synced_${DateTime.now().millisecondsSinceEpoch}';
          await _box!.put(syncId, record);
          
          print('✅ Subido y sincronizado: ${record['created_at']}');
        }
      } catch (e) {
        print('❌ Error subiendo ${record['created_at']}: $e');
      }
    }
  }
  
  /// Descargar del servidor
  Future<void> _downloadFromServer() async {
    try {
      final response = await http.get(
        Uri.parse(_fullUrl!),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final records = data is List ? data : [data];
        
        // Obtener registros locales pendientes antes de limpiar
        final all = await getAll();
        final pendingRecords = all.where((item) => !item.containsKey('sync')).toList();
        
        // Limpiar solo registros sincronizados
        await _box!.clear();
        
        // Restaurar registros locales pendientes
        for (int i = 0; i < pendingRecords.length; i++) {
          final id = 'local_${DateTime.now().millisecondsSinceEpoch}_$i';
          await _box!.put(id, pendingRecords[i]);
        }
        
        // Agregar nuevos registros del servidor
        for (int i = 0; i < records.length; i++) {
          final serverRecord = records[i];
          if (serverRecord is Map<String, dynamic>) {
            final record = Map<String, dynamic>.from(serverRecord);
            record['sync'] = DateTime.now().toIso8601String();
            
            final id = 'server_${DateTime.now().millisecondsSinceEpoch}_$i';
            await _box!.put(id, record);
          }
        }
        
        print('✅ Descargados ${records.length} registros del servidor');
        print('✅ Mantenidos ${pendingRecords.length} registros locales');
      }
    } catch (e) {
      print('❌ Error descargando: $e');
      rethrow;
    }
  }
  
  /// ===========================================
  /// UTILIDADES
  /// ===========================================
  
  /// Notificar cambios en datos
  void _notifyData() async {
    final data = await getAll();
    _dataStream.add(data);
  }
  
  /// Limpiar todo
  Future<void> clear() async {
    await _box!.clear();
    _notifyData();
  }
  
  /// Obtener solo pendientes (registros locales sin sincronizar)
  Future<List<Map<String, dynamic>>> getPending() async {
    final all = await getAll();
    return all.where((item) => !item.containsKey('sync')).toList();
  }
  
  /// Obtener solo sincronizados
  Future<List<Map<String, dynamic>>> getSynced() async {
    final all = await getAll();
    return all.where((item) => item.containsKey('sync')).toList();
  }
  
  /// Cerrar recursos
  void dispose() {
    _dataStream.close();
    _statusStream.close();
    _box?.close();
  }
}