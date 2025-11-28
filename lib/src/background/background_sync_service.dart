import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/global_config.dart';
import '../online_offline_manager.dart';

/// Log que funciona tanto en foreground como en background
void _bgLog(String message) {
  // Usar developer.log para que aparezca en logcat incluso en background
  developer.log(message, name: 'BackgroundSync');
  // También print para debug en foreground
  debugPrint(message);
}

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

/// Tipo de función para tareas personalizadas en background
/// 
/// La función debe retornar `true` si la tarea fue exitosa, `false` si falló.
/// Recibe el baseUrl y token de la configuración guardada para que pueda
/// hacer llamadas HTTP al backend.
typedef CustomBackgroundTask = Future<bool> Function(String baseUrl, String token);

/// Tipo de función para el callback de WorkManager
typedef WorkManagerCallback = void Function();

/// Callback principal para WorkManager - DEBE ser función top-level
/// 
/// Esta función se ejecuta en un isolate separado cuando WorkManager
/// dispara una tarea en background.
/// 
/// NOTA: Este callback solo sincroniza los OnlineOfflineManagers.
/// Para agregar lógica personalizada, usa initialize(customCallback: ...)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final result = await executeBackgroundSync();
    return result.success;
  });
}

/// Ejecuta la sincronización en background
/// 
/// Esta función puede ser llamada desde cualquier callbackDispatcher personalizado.
/// Sincroniza todos los OnlineOfflineManagers registrados.
/// 
/// Retorna [BackgroundSyncResult] con información de la sincronización.
/// 
/// ## Uso desde callback personalizado:
/// ```dart
/// @pragma('vm:entry-point')
/// void myAppCallbackDispatcher() {
///   Workmanager().executeTask((task, inputData) async {
///     // 1. Sincronizar managers del paquete
///     final result = await executeBackgroundSync();
///     
///     // 2. Tu lógica personalizada
///     await miSincronizacionPersonalizada(result.baseUrl!, result.token!);
///     
///     return true;
///   });
/// }
/// ```
Future<BackgroundSyncResult> executeBackgroundSync() async {
  final timestamp = DateTime.now().toIso8601String();
  _bgLog('═══════════════════════════════════════════════════════════');
  _bgLog('🔄 [BackgroundSync] [$timestamp] INICIANDO SINCRONIZACIÓN EN BACKGROUND');
  _bgLog('═══════════════════════════════════════════════════════════');
  
  try {
    // Inicializar Hive para el isolate de background
    _bgLog('📦 Inicializando Hive...');
    await Hive.initFlutter();
    _bgLog('   ✓ Hive inicializado');
    
    // Leer configuración de SharedPreferences
    _bgLog('📖 Leyendo configuración de SharedPreferences...');
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(BackgroundSyncTasks.prefsBaseUrl);
    final token = prefs.getString(BackgroundSyncTasks.prefsToken);
    
    _bgLog('   • baseUrl encontrado: ${baseUrl != null}');
    _bgLog('   • token encontrado: ${token != null}');
    
    if (baseUrl == null || token == null) {
      _bgLog('❌ ERROR: Configuración no encontrada');
      _bgLog('   Asegúrate de llamar BackgroundSyncService.saveConfig() después de login');
      return BackgroundSyncResult(success: false, error: 'Configuración no encontrada');
    }
    _bgLog('   ✓ Configuración cargada: $baseUrl');
    
    // Leer endpoints y boxNames guardados
    final endpointsJson = prefs.getStringList(BackgroundSyncTasks.prefsEndpoints) ?? [];
    final boxNamesJson = prefs.getStringList(BackgroundSyncTasks.prefsBoxNames) ?? [];
    
    _bgLog('📋 Managers registrados:');
    _bgLog('   • boxNames: $boxNamesJson');
    _bgLog('   • endpoints: $endpointsJson');
    
    if (endpointsJson.isEmpty || boxNamesJson.isEmpty) {
      _bgLog('⚠️ No hay managers registrados para sincronizar');
      _bgLog('   Asegúrate de llamar BackgroundSyncService.registerManager()');
      return BackgroundSyncResult(
        success: true, 
        baseUrl: baseUrl, 
        token: token,
        managersCount: 0,
      );
    }
    
    // Inicializar GlobalConfig con los valores guardados (SYNC, no async)
    _bgLog('⚙️ Inicializando GlobalConfig...');
    GlobalConfig.initSync(baseUrl: baseUrl, token: token);
    _bgLog('   ✓ GlobalConfig inicializado');
    
    // Crear managers temporales para sincronizar
    _bgLog('🔨 Creando ${boxNamesJson.length} managers temporales...');
    final managers = <OnlineOfflineManager>[];
    for (int i = 0; i < boxNamesJson.length; i++) {
      final boxName = boxNamesJson[i];
      final endpoint = i < endpointsJson.length ? endpointsJson[i] : null;
      
      if (endpoint != null && endpoint.isNotEmpty) {
        _bgLog('   • Creando: $boxName -> $endpoint');
        managers.add(OnlineOfflineManager(
          boxName: boxName,
          endpoint: endpoint,
        ));
      }
    }
    _bgLog('   ✓ ${managers.length} managers creados');
    
    // Esperar inicialización de managers (más tiempo en background)
    _bgLog('⏳ Esperando inicialización de managers (1.5s)...');
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Ejecutar sincronización de managers
    _bgLog('🔄 EJECUTANDO SINCRONIZACIÓN...');
    final startTime = DateTime.now();
    final results = await OnlineOfflineManager.syncAll();
    final duration = DateTime.now().difference(startTime);
    
    // Mostrar resultados detallados
    _bgLog('📊 RESULTADOS:');
    for (final entry in results.entries) {
      if (entry.value.success) {
        _bgLog('   ✓ ${entry.key}: ÉXITO');
      } else {
        _bgLog('   ✗ ${entry.key}: ERROR - ${entry.value.error}');
      }
    }
    
    // Limpiar managers
    _bgLog('🧹 Limpiando managers...');
    for (final manager in managers) {
      manager.dispose();
    }
    
    final successCount = results.values.where((r) => r.success).length;
    final failedCount = results.length - successCount;
    
    _bgLog('═══════════════════════════════════════════════════════════');
    _bgLog('✅ SINCRONIZACIÓN COMPLETADA en ${duration.inSeconds}s');
    _bgLog('   • Exitosos: $successCount/${results.length}');
    if (failedCount > 0) {
      _bgLog('   • Fallidos: $failedCount');
    }
    _bgLog('═══════════════════════════════════════════════════════════');
    
    return BackgroundSyncResult(
      success: true,
      baseUrl: baseUrl,
      token: token,
      managersCount: managers.length,
      successCount: successCount,
      failedCount: failedCount,
    );
  } catch (e, stackTrace) {
    _bgLog('═══════════════════════════════════════════════════════════');
    _bgLog('❌ ERROR EN SINCRONIZACIÓN BACKGROUND');
    _bgLog('   Error: $e');
    _bgLog('   Stack: $stackTrace');
    _bgLog('═══════════════════════════════════════════════════════════');
    return BackgroundSyncResult(success: false, error: e.toString());
  }
}

/// Resultado de la sincronización en background
class BackgroundSyncResult {
  final bool success;
  final String? error;
  final String? baseUrl;
  final String? token;
  final int managersCount;
  final int successCount;
  final int failedCount;
  
  BackgroundSyncResult({
    required this.success,
    this.error,
    this.baseUrl,
    this.token,
    this.managersCount = 0,
    this.successCount = 0,
    this.failedCount = 0,
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
  /// ## Uso básico (solo sincroniza managers):
  /// ```dart
  /// await BackgroundSyncService.initialize();
  /// ```
  /// 
  /// ## Uso con callback personalizado (para agregar lógica propia):
  /// ```dart
  /// await BackgroundSyncService.initialize(
  ///   customCallback: myAppCallbackDispatcher,
  /// );
  /// ```
  /// 
  /// Donde `myAppCallbackDispatcher` es una función top-level:
  /// ```dart
  /// @pragma('vm:entry-point')
  /// void myAppCallbackDispatcher() {
  ///   Workmanager().executeTask((task, inputData) async {
  ///     // Sincronizar managers del paquete
  ///     final result = await executeBackgroundSync();
  ///     
  ///     // Tu lógica personalizada aquí
  ///     if (result.success && result.baseUrl != null) {
  ///       await miLogicaPersonalizada(result.baseUrl!, result.token!);
  ///     }
  ///     
  ///     return true;
  ///   });
  /// }
  /// ```
  static Future<void> initialize({
    WorkManagerCallback? customCallback,
  }) async {
    if (_isInitialized) return;
    
    // Solo inicializar en Android
    if (!Platform.isAndroid) {
      debugPrint('⚠️ [BackgroundSync] Solo disponible en Android');
      return;
    }
    
    // Usar callback personalizado o el default
    final callback = customCallback ?? callbackDispatcher;
    
    await Workmanager().initialize(
      callback,
      isInDebugMode: kDebugMode,
    );
    
    _isInitialized = true;
    if (customCallback != null) {
      debugPrint('✅ [BackgroundSync] WorkManager inicializado con callback personalizado');
    } else {
      debugPrint('✅ [BackgroundSync] WorkManager inicializado');
    }
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

