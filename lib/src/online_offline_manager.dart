import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Estados de sincronización
enum SyncStatus { idle, syncing, success, error }

/// Configuración simple para sincronización
class SyncConfig {
  final String uploadEndpoint;
  final String downloadEndpoint;
  final Map<String, String> headers;
  final Duration timeout;
  final Duration syncInterval;

  const SyncConfig({
    this.uploadEndpoint = '/items',
    this.downloadEndpoint = '/items',
    this.headers = const {'Content-Type': 'application/json'},
    this.timeout = const Duration(seconds: 10),
    this.syncInterval = const Duration(minutes: 30),
  });
}

/// Gestor principal para sistema online/offline con state management
class OnlineOfflineManager {
  final String boxName;
  final String serverUrl;
  final SyncConfig syncConfig;
  
  late Box _box;
  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();
  
  bool _isConnected = false;
  bool _isInitialized = false;
  
  // Streams para state management
  final _statusController = StreamController<SyncStatus>.broadcast();
  final _connectivityController = StreamController<bool>.broadcast();
  
  // Singleton pattern
  static OnlineOfflineManager? _instance;
  static OnlineOfflineManager get instance {
    if (_instance == null) {
      throw Exception('OnlineOfflineManager no ha sido inicializado. Usa initSimple() primero.');
    }
    return _instance!;
  }

  OnlineOfflineManager._({
    required this.boxName,
    required this.serverUrl,
    this.syncConfig = const SyncConfig(),
  });

  // Getters para streams
  Stream<SyncStatus> get status => _statusController.stream;
  Stream<bool> get connectivity => _connectivityController.stream;

  /// Inicialización simple - solo necesita el nombre de la base de datos
  /// La URL del servidor se toma de las variables de entorno
  static Future<OnlineOfflineManager> initSimple({
    required String boxName,
    String? serverUrl,
    SyncConfig? syncConfig,
  }) async {
    // Si ya existe una instancia, retornarla
    if (_instance != null) {
      print('🔄 OnlineOfflineManager ya inicializado, retornando instancia existente');
      return _instance!;
    }

    // Cargar variables de entorno
    try {
      await dotenv.load(fileName: ".env");
      print('✅ Variables de entorno cargadas');
    } catch (e) {
      print('⚠️ No se encontró archivo .env, continuando sin variables de entorno');
    }

    // Obtener URL del servidor de variables de entorno
    final url = serverUrl ?? 
                dotenv.env['SERVER_URL'] ?? 
                dotenv.env['API_URL'] ?? 
                dotenv.env['server'] ?? 
                'http://localhost:3000';

    print('🌐 URL del servidor: $url');

    // Crear manager con Singleton
    _instance = OnlineOfflineManager._(
      boxName: boxName,
      serverUrl: url,
      syncConfig: syncConfig ?? const SyncConfig(),
    );

    // Inicializar automáticamente
    await _instance!.init();

    return _instance!;
  }

  /// Inicializa el sistema completo
  Future<void> init() async {
    if (_isInitialized) {
      print('🔄 OnlineOfflineManager ya inicializado');
      return;
    }
    
    print('🚀 Inicializando OnlineOfflineManager...');
    
    // Inicializar base de datos local
    await Hive.initFlutter();
    _box = await Hive.openBox(boxName);
    print('💾 Base de datos local inicializada: $boxName');
    
    // Iniciar monitoreo de conectividad en tiempo real
    await _iniciarMonitoreoConectividad();
    
    // Iniciar sincronización programada
    _iniciarSincronizacionProgramada();
    
    _isInitialized = true;
    print('✅ OnlineOfflineManager inicializado exitosamente');
  }

  /// Guarda datos localmente
  Future<void> save(String key, dynamic value) async {
    await _box.put(key, value);
    
    // Sincronizar si hay internet
    if (_isConnected) {
      _sincronizarEnSegundoPlano();
    }
  }

  /// Obtiene datos por clave
  dynamic get(String key) {
    return _box.get(key);
  }

  /// Obtiene todos los datos
  Map<dynamic, dynamic> getAll() {
    return _box.toMap();
  }

  /// Elimina datos por clave
  Future<void> delete(String key) async {
    await _box.delete(key);
    
    // Sincronizar si hay internet
    if (_isConnected) {
      _sincronizarEnSegundoPlano();
    }
  }

  /// Verifica si existe una clave
  bool contains(String key) {
    return _box.containsKey(key);
  }

  /// Limpia todos los datos
  Future<void> clear() async {
    await _box.clear();
    
    // Sincronizar si hay internet
    if (_isConnected) {
      _sincronizarEnSegundoPlano();
    }
  }

  /// Sincroniza manualmente con el servidor
  Future<void> sync() async {
    if (!_isConnected) {
      print('❌ No hay conexión a internet para sincronizar');
      _statusController.add(SyncStatus.error);
      throw Exception('No hay conexión a internet');
    }

    try {
      print('🔄 Iniciando sincronización...');
      _statusController.add(SyncStatus.syncing);

      // Subir datos locales al servidor
      final localData = _box.toMap();
      print('📤 Subiendo ${localData.length} elementos locales al servidor...');
      
      for (final entry in localData.entries) {
        await _subirAlServidor(entry.key.toString(), entry.value);
      }

      // Descargar datos del servidor
      print('📥 Descargando datos del servidor...');
      final serverData = await _descargarDelServidor();
      print('📥 Descargados ${serverData.length} elementos del servidor');
      
      for (final item in serverData) {
        await _box.put(item['id'].toString(), item['value']);
      }

      _statusController.add(SyncStatus.success);
      print('✅ Sincronización completada exitosamente');
    } catch (e) {
      print('❌ Error en sincronización: $e');
      _statusController.add(SyncStatus.error);
      throw Exception('Error de sincronización: $e');
    }
  }

  /// Verifica si hay conexión a internet
  bool get isConnected => _isConnected;

  /// Verifica internet manualmente
  Future<bool> checkConnectivity() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.google.com'),
      ).timeout(const Duration(seconds: 5));
      
      _isConnected = response.statusCode == 200;
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  /// Inicia monitoreo de conectividad en tiempo real
  Future<void> _iniciarMonitoreoConectividad() async {
    print('📡 Iniciando monitoreo de conectividad...');
    
    // Verificar conectividad inicial
    await _verificarConectividadInicial();
    
    // Escuchar cambios de conectividad
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    
    print('✅ Monitoreo de conectividad iniciado');
  }

  /// Verifica conectividad inicial
  Future<void> _verificarConectividadInicial() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      _isConnected = _tieneInternet(connectivityResults);
      _connectivityController.add(_isConnected);
      
      if (_isConnected) {
        print('🌐 Conectividad inicial: ONLINE');
        _sincronizarEnSegundoPlano();
      } else {
        print('📴 Conectividad inicial: OFFLINE');
      }
    } catch (e) {
      print('❌ Error al verificar conectividad inicial: $e');
      _isConnected = false;
      _connectivityController.add(false);
    }
  }

  /// Maneja cambios de conectividad
  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final teniaInternet = _isConnected;
    _isConnected = _tieneInternet(results);
    _connectivityController.add(_isConnected);
    
    if (_isConnected && !teniaInternet) {
      print('🌐 Conectividad detectada - Iniciando sincronización automática');
      _sincronizarEnSegundoPlano();
    } else if (!_isConnected && teniaInternet) {
      print('📴 Pérdida de conectividad detectada');
    }
  }

  /// Verifica si tiene internet basado en los resultados de conectividad
  bool _tieneInternet(List<ConnectivityResult> results) {
    return results.any((result) => 
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn
    );
  }

  /// Inicia sincronización programada
  void _iniciarSincronizacionProgramada() {
    print('⏰ Iniciando sincronización programada cada ${syncConfig.syncInterval.inMinutes} minutos');
    
    _syncTimer = Timer.periodic(syncConfig.syncInterval, (timer) {
      print('📅 Sincronización programada activada');
      if (_isConnected) {
        _sincronizarEnSegundoPlano();
      } else {
        print('📴 Sin conexión - omitiendo sincronización programada');
      }
    });
  }

  /// Sincroniza en segundo plano
  Future<void> _sincronizarEnSegundoPlano() async {
    try {
      await sync();
    } catch (e) {
      // No mostrar errores de sincronización en segundo plano
      print('Sincronización en segundo plano falló: $e');
    }
  }

  /// Sube datos al servidor
  Future<void> _subirAlServidor(String id, dynamic value) async {
    final payload = {'id': id, 'value': value};
    
    await http.post(
      Uri.parse('$serverUrl${syncConfig.uploadEndpoint}'),
      body: jsonEncode(payload),
      headers: syncConfig.headers,
    ).timeout(syncConfig.timeout);
  }

  /// Descarga datos del servidor
  Future<List<Map<String, dynamic>>> _descargarDelServidor() async {
    final response = await http.get(
      Uri.parse('$serverUrl${syncConfig.downloadEndpoint}'),
      headers: syncConfig.headers,
    ).timeout(syncConfig.timeout);
    
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  /// Libera recursos
  void dispose() {
    print('🔄 Liberando recursos de OnlineOfflineManager...');
    
    _syncTimer?.cancel();
    _syncTimer = null;
    
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    
    _statusController.close();
    _connectivityController.close();
    
    _isInitialized = false;
    _instance = null;
    
    print('✅ Recursos liberados');
  }

  /// Método estático para liberar la instancia singleton
  static void disposeInstance() {
    _instance?.dispose();
  }
}

