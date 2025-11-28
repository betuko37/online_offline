import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/global_config.dart';
import '../online_offline_manager.dart';

/// Constantes para las tareas de WorkManager
class BackgroundSyncTasks {
  /// Tarea de sincronización periódica (cada 15 minutos)
  static const String periodicSync = 'com.betuko.offline_sync.periodic';
  
  /// Tarea de sincronización única (al recuperar conexión)
  static const String oneTimeSync = 'com.betuko.offline_sync.onetime';
  
  /// Prefijo para SharedPreferences
  static const String _prefsPrefix = 'betuko_offline_sync_';
  static const String prefsBaseUrl = '${_prefsPrefix}base_url';
  static const String prefsToken = '${_prefsPrefix}token';
  static const String prefsEndpoints = '${_prefsPrefix}endpoints';
  static const String prefsBoxNames = '${_prefsPrefix}box_names';
}

/// Callback principal para WorkManager - DEBE ser función top-level
/// 
/// Esta función se ejecuta en un isolate separado cuando WorkManager
/// dispara una tarea en background.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Usar print en lugar de debugPrint para que aparezca en logcat incluso con app cerrada
    final timestamp = DateTime.now().toIso8601String();
    print('═══════════════════════════════════════════════════════════');
    print('🔄 [BackgroundSync] [$timestamp] Iniciando tarea: $task');
    print('═══════════════════════════════════════════════════════════');
    
    try {
      // Inicializar Hive para el isolate de background
      print('📦 [BackgroundSync] Inicializando Hive...');
      await Hive.initFlutter();
      
      // Leer configuración de SharedPreferences
      print('📖 [BackgroundSync] Leyendo configuración...');
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString(BackgroundSyncTasks.prefsBaseUrl);
      final token = prefs.getString(BackgroundSyncTasks.prefsToken);
      
      if (baseUrl == null || token == null) {
        print('❌ [BackgroundSync] Configuración no encontrada (baseUrl: ${baseUrl != null}, token: ${token != null})');
        return Future.value(false);
      }
      print('✅ [BackgroundSync] Configuración cargada (baseUrl: ${baseUrl.substring(0, baseUrl.length > 30 ? 30 : baseUrl.length)}...)');
      
      // Leer endpoints y boxNames guardados
      final endpointsJson = prefs.getStringList(BackgroundSyncTasks.prefsEndpoints) ?? [];
      final boxNamesJson = prefs.getStringList(BackgroundSyncTasks.prefsBoxNames) ?? [];
      
      if (endpointsJson.isEmpty || boxNamesJson.isEmpty) {
        print('❌ [BackgroundSync] No hay managers registrados (endpoints: ${endpointsJson.length}, boxes: ${boxNamesJson.length})');
        return Future.value(false);
      }
      print('📋 [BackgroundSync] Managers encontrados: ${boxNamesJson.length}');
      
      // Inicializar GlobalConfig con los valores guardados
      print('⚙️ [BackgroundSync] Inicializando GlobalConfig...');
      GlobalConfig.init(baseUrl: baseUrl, token: token);
      
      // Crear managers temporales para sincronizar
      print('🔨 [BackgroundSync] Creando managers temporales...');
      final managers = <OnlineOfflineManager>[];
      for (int i = 0; i < boxNamesJson.length; i++) {
        final boxName = boxNamesJson[i];
        final endpoint = i < endpointsJson.length ? endpointsJson[i] : null;
        
        if (endpoint != null && endpoint.isNotEmpty) {
          managers.add(OnlineOfflineManager(
            boxName: boxName,
            endpoint: endpoint,
          ));
          print('   ✓ Manager creado: $boxName -> $endpoint');
        }
      }
      
      // Esperar inicialización de managers
      print('⏳ [BackgroundSync] Esperando inicialización de managers...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Ejecutar sincronización
      print('🔄 [BackgroundSync] Ejecutando sincronización...');
      final startTime = DateTime.now();
      final results = await OnlineOfflineManager.syncAll();
      final duration = DateTime.now().difference(startTime);
      
      // Limpiar managers
      print('🧹 [BackgroundSync] Limpiando managers...');
      for (final manager in managers) {
        manager.dispose();
      }
      
      final successCount = results.values.where((r) => r.success).length;
      final failedCount = results.length - successCount;
      print('═══════════════════════════════════════════════════════════');
      print('✅ [BackgroundSync] Sincronización completada en ${duration.inSeconds}s');
      print('   ✓ Exitosos: $successCount/${results.length}');
      if (failedCount > 0) {
        print('   ✗ Fallidos: $failedCount');
        for (final entry in results.entries) {
          if (!entry.value.success) {
            print('      - ${entry.key}: ${entry.value.error}');
          }
        }
      }
      print('═══════════════════════════════════════════════════════════');
      
      return Future.value(true);
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ [BackgroundSync] ERROR: $e');
      print('Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      return Future.value(false);
    }
  });
}

/// Servicio para sincronización en background usando WorkManager
/// 
/// Permite ejecutar sincronizaciones incluso cuando la app está cerrada.
/// 
/// ## Uso básico
/// 
/// ```dart
/// // 1. Inicializar en main()
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   GlobalConfig.init(
///     baseUrl: 'https://api.com',
///     token: 'token',
///   );
///   
///   // Inicializar background sync
///   await BackgroundSyncService.initialize();
///   
///   runApp(MyApp());
/// }
/// 
/// // 2. Registrar managers para sync en background
/// final reportes = OnlineOfflineManager(boxName: 'reportes', endpoint: '/api/reportes');
/// await BackgroundSyncService.registerManager(reportes);
/// ```
/// 
/// ## Configuración Android
/// 
/// Agregar en `android/app/src/main/AndroidManifest.xml`:
/// ```xml
/// <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
/// ```
class BackgroundSyncService {
  static bool _isInitialized = false;
  
  /// Intervalo mínimo de sincronización periódica (15 minutos es el mínimo de Android)
  static const Duration minimumPeriodicInterval = Duration(minutes: 15);
  
  /// Inicializa WorkManager para sincronización en background
  /// 
  /// Debe llamarse una vez al inicio de la app, después de
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  /// 
  /// Ejemplo:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await BackgroundSyncService.initialize();
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Solo inicializar en Android
    if (!Platform.isAndroid) {
      debugPrint('⚠️ [BackgroundSync] Solo disponible en Android');
      return;
    }
    
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    
    _isInitialized = true;
    debugPrint('✅ [BackgroundSync] WorkManager inicializado');
  }
  
  /// Guarda la configuración actual para que el background task pueda accederla
  /// 
  /// Debe llamarse después de `GlobalConfig.init()` y cada vez que
  /// cambie el token.
  static Future<void> saveConfig() async {
    if (!GlobalConfig.isInitialized) {
      throw Exception('GlobalConfig debe estar inicializado antes de guardar config');
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(BackgroundSyncTasks.prefsBaseUrl, GlobalConfig.baseUrl!);
    await prefs.setString(BackgroundSyncTasks.prefsToken, GlobalConfig.token!);
    
    debugPrint('✅ [BackgroundSync] Configuración guardada');
  }
  
  /// Registra un manager para sincronización en background
  /// 
  /// Los managers registrados se sincronizarán cuando se ejecute
  /// la tarea de background.
  /// 
  /// Ejemplo:
  /// ```dart
  /// final reportes = OnlineOfflineManager(boxName: 'reportes', endpoint: '/api/reportes');
  /// await BackgroundSyncService.registerManager(reportes);
  /// ```
  static Future<void> registerManager(OnlineOfflineManager manager) async {
    if (manager.endpoint == null) {
      debugPrint('⚠️ [BackgroundSync] Manager sin endpoint, no se registra');
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    
    // Obtener listas actuales
    final boxNames = prefs.getStringList(BackgroundSyncTasks.prefsBoxNames) ?? [];
    final endpoints = prefs.getStringList(BackgroundSyncTasks.prefsEndpoints) ?? [];
    
    // Verificar si ya existe
    final existingIndex = boxNames.indexOf(manager.boxName);
    if (existingIndex >= 0) {
      // Actualizar endpoint si existe
      endpoints[existingIndex] = manager.endpoint!;
    } else {
      // Agregar nuevo
      boxNames.add(manager.boxName);
      endpoints.add(manager.endpoint!);
    }
    
    // Guardar
    await prefs.setStringList(BackgroundSyncTasks.prefsBoxNames, boxNames);
    await prefs.setStringList(BackgroundSyncTasks.prefsEndpoints, endpoints);
    
    debugPrint('✅ [BackgroundSync] Manager registrado: ${manager.boxName}');
  }
  
  /// Desregistra un manager de la sincronización en background
  static Future<void> unregisterManager(String boxName) async {
    final prefs = await SharedPreferences.getInstance();
    
    final boxNames = prefs.getStringList(BackgroundSyncTasks.prefsBoxNames) ?? [];
    final endpoints = prefs.getStringList(BackgroundSyncTasks.prefsEndpoints) ?? [];
    
    final index = boxNames.indexOf(boxName);
    if (index >= 0) {
      boxNames.removeAt(index);
      if (index < endpoints.length) {
        endpoints.removeAt(index);
      }
      
      await prefs.setStringList(BackgroundSyncTasks.prefsBoxNames, boxNames);
      await prefs.setStringList(BackgroundSyncTasks.prefsEndpoints, endpoints);
      
      debugPrint('✅ [BackgroundSync] Manager desregistrado: $boxName');
    }
  }
  
  /// Inicia la sincronización periódica en background
  /// 
  /// La sincronización se ejecutará cada [interval] (mínimo 15 minutos).
  /// Solo se ejecutará cuando haya conexión a internet.
  /// 
  /// Ejemplo:
  /// ```dart
  /// await BackgroundSyncService.startPeriodicSync();
  /// ```
  static Future<void> startPeriodicSync({
    Duration interval = minimumPeriodicInterval,
  }) async {
    if (!Platform.isAndroid) {
      debugPrint('⚠️ [BackgroundSync] Solo disponible en Android');
      return;
    }
    
    if (!_isInitialized) {
      await initialize();
    }
    
    // Asegurar intervalo mínimo
    final effectiveInterval = interval < minimumPeriodicInterval 
        ? minimumPeriodicInterval 
        : interval;
    
    // Guardar configuración actual
    await saveConfig();
    
    // Registrar tarea periódica
    await Workmanager().registerPeriodicTask(
      BackgroundSyncTasks.periodicSync,
      BackgroundSyncTasks.periodicSync,
      frequency: effectiveInterval,
      constraints: Constraints(
        networkType: NetworkType.connected, // Solo con internet
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
    
    debugPrint('✅ [BackgroundSync] Sincronización periódica iniciada (cada ${effectiveInterval.inMinutes} min)');
  }
  
  /// Inicia una sincronización única cuando haya conexión a internet
  /// 
  /// Útil para programar una sincronización cuando el dispositivo
  /// recupere la conexión.
  /// 
  /// Ejemplo:
  /// ```dart
  /// // Programar sync cuando haya internet
  /// await BackgroundSyncService.syncWhenConnected();
  /// ```
  static Future<void> syncWhenConnected() async {
    if (!Platform.isAndroid) {
      debugPrint('⚠️ [BackgroundSync] Solo disponible en Android');
      return;
    }
    
    if (!_isInitialized) {
      await initialize();
    }
    
    // Guardar configuración actual
    await saveConfig();
    
    // Registrar tarea única
    await Workmanager().registerOneOffTask(
      '${BackgroundSyncTasks.oneTimeSync}_${DateTime.now().millisecondsSinceEpoch}',
      BackgroundSyncTasks.oneTimeSync,
      constraints: Constraints(
        networkType: NetworkType.connected, // Solo cuando haya internet
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
    
    debugPrint('✅ [BackgroundSync] Sincronización programada para cuando haya conexión');
  }
  
  /// Detiene la sincronización periódica en background
  /// 
  /// Ejemplo:
  /// ```dart
  /// await BackgroundSyncService.stopPeriodicSync();
  /// ```
  static Future<void> stopPeriodicSync() async {
    if (!Platform.isAndroid) return;
    
    await Workmanager().cancelByUniqueName(BackgroundSyncTasks.periodicSync);
    debugPrint('✅ [BackgroundSync] Sincronización periódica detenida');
  }
  
  /// Cancela todas las tareas de sincronización en background
  /// 
  /// Ejemplo:
  /// ```dart
  /// await BackgroundSyncService.cancelAll();
  /// ```
  static Future<void> cancelAll() async {
    if (!Platform.isAndroid) return;
    
    await Workmanager().cancelAll();
    debugPrint('✅ [BackgroundSync] Todas las tareas canceladas');
  }
  
  /// Limpia la configuración guardada
  /// 
  /// Útil al cerrar sesión para evitar sincronizaciones con
  /// credenciales inválidas.
  static Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(BackgroundSyncTasks.prefsBaseUrl);
    await prefs.remove(BackgroundSyncTasks.prefsToken);
    await prefs.remove(BackgroundSyncTasks.prefsBoxNames);
    await prefs.remove(BackgroundSyncTasks.prefsEndpoints);
    
    debugPrint('✅ [BackgroundSync] Configuración limpiada');
  }
  
  /// Verifica si el servicio está inicializado
  static bool get isInitialized => _isInitialized;
}

