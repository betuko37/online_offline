# 📱 Guía Completa: WorkManager y Sincronización en Background

Esta guía explica cómo configurar y usar WorkManager para sincronizar datos en segundo plano, incluso cuando la app está completamente cerrada.

## 📋 Tabla de Contenidos

1. [¿Qué es WorkManager?](#qué-es-workmanager)
2. [Configuración Requerida](#configuración-requerida)
3. [Permisos Android](#permisos-android)
4. [Configuración del AndroidManifest](#configuración-del-androidmanifest)
5. [Configuración en Flutter](#configuración-en-flutter)
6. [Uso del BackgroundSyncService](#uso-del-backgroundsyncservice)
7. [Troubleshooting](#troubleshooting)
8. [Limitaciones y Consideraciones](#limitaciones-y-consideraciones)

---

## ¿Qué es WorkManager?

**WorkManager** es una biblioteca de Android que permite ejecutar tareas en segundo plano de forma confiable, incluso cuando:
- ✅ La app está en segundo plano
- ✅ La app está completamente cerrada
- ✅ El dispositivo se reinicia (con permisos adecuados)
- ✅ El dispositivo está en modo de ahorro de batería

### ¿Cómo Funciona?

1. **WorkManager** programa tareas que se ejecutan en un **isolate separado** de Flutter
2. El sistema Android decide **cuándo ejecutar** las tareas basándose en:
   - Restricciones (red, batería, etc.)
   - Optimización de batería
   - Políticas del fabricante
3. Las tareas se ejecutan incluso si la app está cerrada

---

## Configuración Requerida

### Dependencias

Asegúrate de tener estas dependencias en tu `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  betuko_offline_sync: ^latest_version
  workmanager: ^0.5.2
  shared_preferences: ^2.2.2
  hive_flutter: ^1.1.0
```

---

## Permisos Android

### Permisos Básicos (Requeridos)

Agrega estos permisos en `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.tu.app">
    
    <!-- Permiso para recibir eventos de arranque (opcional pero recomendado) -->
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    
    <!-- Permisos de red (ya deberían estar) -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    
    <!-- Permiso para ejecutar en background (Android 8.0+) -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    
    <!-- Permiso para ignorar optimización de batería (opcional, para mejor funcionamiento) -->
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
    
    <application
        android:label="Tu App"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Tu actividad principal -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
    </application>
</manifest>
```

### Permisos Adicionales (Recomendados para Mejor Funcionamiento)

Para dispositivos con optimización agresiva de batería (Xiaomi, Huawei, Samsung, etc.):

```xml
<!-- En AndroidManifest.xml, dentro de <application> -->
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

---

## Configuración del AndroidManifest

### Configuración Completa Recomendada

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.tu.app">
    
    <!-- ============================================ -->
    <!-- PERMISOS -->
    <!-- ============================================ -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    
    <application
        android:label="Tu App"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
        
        <!-- Actividad principal -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <!-- Meta-data para Flutter -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

---

## Configuración en Flutter

### 1. Inicializar en `main()`

```dart
import 'package:flutter/material.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() async {
  // IMPORTANTE: Siempre inicializar Flutter binding primero
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Configurar GlobalConfig
  await GlobalConfig.init(
    baseUrl: 'https://tu-api.com',
    token: 'tu-token-jwt',
  );
  
  // 2. Inicializar WorkManager (solo Android)
  await BackgroundSyncService.initialize();
  
  // 3. Guardar configuración para background
  await BackgroundSyncService.saveConfig();
  
  runApp(MyApp());
}
```

### 2. Registrar Managers Después del Login

```dart
// Después de que el usuario hace login
Future<void> onLoginSuccess(String token) async {
  // 1. Actualizar token en GlobalConfig
  await GlobalConfig.updateToken(token);
  
  // 2. Guardar configuración para background
  await BackgroundSyncService.saveConfig();
  
  // 3. Crear y registrar managers
  // Manager de asistencias (con POST habilitado)
  final asistencias = OnlineOfflineManager(
    boxName: 'asistencias',
    endpoint: 'processes/payroll/daily-capture',
    uploadEnabled: true, // ✅ Permite POST
  );
  await BackgroundSyncService.registerManager(asistencias);
  
  // Manager de catalogos (solo lectura, sin POST)
  final labors = OnlineOfflineManager(
    boxName: 'labors',
    endpoint: 'catalogs/labors',
    uploadEnabled: false, // ❌ Solo GET
  );
  await BackgroundSyncService.registerManager(labors);
  
  // 4. Iniciar sincronización periódica
  await BackgroundSyncService.startPeriodicSync();
}
```

### 3. Actualizar Token Cuando Cambie

```dart
// Cuando el token se renueva
Future<void> onTokenRefreshed(String newToken) async {
  await GlobalConfig.updateToken(newToken);
  await BackgroundSyncService.saveConfig(); // Actualizar en background
}
```

### 4. Limpiar al Cerrar Sesión

```dart
// Al hacer logout
Future<void> onLogout() async {
  // 1. Detener sincronización periódica
  await BackgroundSyncService.stopPeriodicSync();
  
  // 2. Cancelar todas las tareas pendientes
  await BackgroundSyncService.cancelAll();
  
  // 3. Limpiar configuración guardada
  await BackgroundSyncService.clearConfig();
  
  // 4. Limpiar datos locales (opcional)
  await OnlineOfflineManager.resetAll();
}
```

---

## Uso del BackgroundSyncService

### Métodos Principales

#### `initialize()`
Inicializa WorkManager. Debe llamarse una vez en `main()`.

```dart
await BackgroundSyncService.initialize();
```

#### `saveConfig()`
Guarda la configuración (baseUrl y token) para que esté disponible en background.

```dart
await BackgroundSyncService.saveConfig();
```

**IMPORTANTE**: Debe llamarse:
- Después de `GlobalConfig.init()`
- Después de cada login
- Cuando el token se renueva

#### `registerManager()`
Registra un manager para sincronización en background.

```dart
final manager = OnlineOfflineManager(
  boxName: 'asistencias',
  endpoint: 'processes/payroll/daily-capture',
  uploadEnabled: true,
);
await BackgroundSyncService.registerManager(manager);
```

#### `startPeriodicSync()`
Inicia sincronización periódica (cada 15 minutos mínimo).

```dart
// Sincronizar cada 15 minutos (mínimo)
await BackgroundSyncService.startPeriodicSync();

// O con intervalo personalizado (mínimo 15 min)
await BackgroundSyncService.startPeriodicSync(
  interval: Duration(minutes: 30),
);
```

#### `syncWhenConnected()`
Programa una sincronización única cuando haya conexión.

```dart
// Útil después de estar offline
await BackgroundSyncService.syncWhenConnected();
```

#### `stopPeriodicSync()`
Detiene la sincronización periódica.

```dart
await BackgroundSyncService.stopPeriodicSync();
```

#### `cancelAll()`
Cancela todas las tareas pendientes.

```dart
await BackgroundSyncService.cancelAll();
```

#### `clearConfig()`
Limpia la configuración guardada (útil en logout).

```dart
await BackgroundSyncService.clearConfig();
```

---

## Ejemplo Completo

```dart
import 'package:flutter/material.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configurar API
  await GlobalConfig.init(
    baseUrl: 'https://api.tuapp.com',
    token: '', // Se actualizará después del login
  );
  
  // Inicializar WorkManager
  await BackgroundSyncService.initialize();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _handleLogin(String email, String password) async {
    // 1. Hacer login y obtener token
    final token = await authService.login(email, password);
    
    // 2. Actualizar configuración
    await GlobalConfig.updateToken(token);
    await BackgroundSyncService.saveConfig();
    
    // 3. Crear managers
    final asistencias = OnlineOfflineManager(
      boxName: 'asistencias',
      endpoint: 'processes/payroll/daily-capture',
      uploadEnabled: true, // ✅ POST habilitado
    );
    
    final labors = OnlineOfflineManager(
      boxName: 'labors',
      endpoint: 'catalogs/labors',
      uploadEnabled: false, // ❌ Solo GET
    );
    
    // 4. Registrar managers
    await BackgroundSyncService.registerManager(asistencias);
    await BackgroundSyncService.registerManager(labors);
    
    // 5. Iniciar sincronización periódica
    await BackgroundSyncService.startPeriodicSync();
    
    // 6. Navegar a home
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen()),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => _handleLogin('user@example.com', 'password'),
          child: Text('Login'),
        ),
      ),
    );
  }
}
```

---

## Troubleshooting

### ❌ Problema: WorkManager no se ejecuta en background

**Soluciones:**

1. **Verificar permisos en AndroidManifest.xml**
   ```xml
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
   ```

2. **Verificar que se llamó `saveConfig()` después del login**
   ```dart
   await BackgroundSyncService.saveConfig();
   ```

3. **Verificar que se registraron los managers**
   ```dart
   await BackgroundSyncService.registerManager(manager);
   ```

4. **Verificar que se inició la sincronización periódica**
   ```dart
   await BackgroundSyncService.startPeriodicSync();
   ```

5. **Desactivar optimización de batería para tu app**
   - Ir a Configuración > Apps > Tu App > Batería
   - Seleccionar "Sin restricciones" o "No optimizar"

### ❌ Problema: Los POST no funcionan en background

**Soluciones:**

1. **Verificar que el manager tiene `uploadEnabled: true`**
   ```dart
   final manager = OnlineOfflineManager(
     boxName: 'asistencias',
     endpoint: 'tu/endpoint',
     uploadEnabled: true, // ✅ IMPORTANTE
   );
   ```

2. **Verificar logs en logcat**
   ```bash
   adb logcat -s BackgroundSync:V ApiClient:V
   ```

3. **Verificar que ConnectivityService está inicializado**
   - El código ya lo hace automáticamente, pero verifica los logs

### ❌ Problema: La sincronización no se ejecuta con la app cerrada

**Soluciones:**

1. **Verificar que WorkManager está inicializado**
   ```dart
   await BackgroundSyncService.initialize();
   ```

2. **Verificar permisos de batería**
   - Algunos fabricantes (Xiaomi, Huawei) requieren permisos especiales
   - Ir a Configuración > Apps > Tu App > Batería > Sin restricciones

3. **Verificar que la tarea está registrada**
   ```dart
   await BackgroundSyncService.startPeriodicSync();
   ```

4. **Revisar logs de WorkManager**
   ```bash
   adb logcat | grep -i workmanager
   ```

### ❌ Problema: Timeout en peticiones POST

**Soluciones:**

1. **Aumentar timeout en ApiClient** (si es necesario)
   - El timeout por defecto es 60 segundos
   - WorkManager tiene límites de tiempo de ejecución

2. **Verificar que los datos no son demasiado grandes**
   - WorkManager puede matar procesos que tardan mucho

3. **Usar `syncWhenConnected()` en vez de periódico para POST grandes**

### 📊 Ver Logs en Background

Para ver los logs cuando la app está cerrada:

```bash
# Ver todos los logs de BackgroundSync
adb logcat -s BackgroundSync:V

# Ver logs de ApiClient también
adb logcat -s BackgroundSync:V ApiClient:V

# Ver logs de WorkManager
adb logcat | grep -i workmanager

# Ver todos los logs relacionados
adb logcat | grep -E "BackgroundSync|ApiClient|WorkManager|POST|GET"
```

### 🔍 Verificar Estado de WorkManager

Para verificar si WorkManager está funcionando:

```dart
// En tu app, agregar un botón de debug
ElevatedButton(
  onPressed: () async {
    final isInitialized = BackgroundSyncService.isInitialized;
    print('WorkManager inicializado: $isInitialized');
    
    // Verificar configuración guardada
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('betuko_offline_sync_base_url');
    final token = prefs.getString('betuko_offline_sync_token');
    print('BaseUrl guardado: ${baseUrl != null}');
    print('Token guardado: ${token != null}');
  },
  child: Text('Verificar Estado'),
)
```

---

## Limitaciones y Consideraciones

### ⚠️ Limitaciones de Android

1. **Intervalo Mínimo**: 15 minutos (limitación de Android WorkManager)
   - No se puede sincronizar más frecuentemente

2. **Optimización de Batería**: Android puede demorar la ejecución
   - Especialmente en dispositivos Xiaomi, Huawei, Samsung
   - Solución: Pedir al usuario desactivar optimización de batería

3. **Tiempo de Ejecución**: WorkManager puede matar procesos que tardan mucho
   - Máximo recomendado: 10 minutos por tarea
   - Si tus POSTs son muy grandes, considera dividirlos

4. **Solo Android**: iOS tiene restricciones más estrictas
   - WorkManager solo funciona en Android
   - En iOS, la sincronización solo funciona cuando la app está en foreground

### ✅ Mejores Prácticas

1. **Siempre llamar `saveConfig()` después de login**
   ```dart
   await BackgroundSyncService.saveConfig();
   ```

2. **Limpiar al hacer logout**
   ```dart
   await BackgroundSyncService.clearConfig();
   await BackgroundSyncService.cancelAll();
   ```

3. **Usar `uploadEnabled: false` para managers de solo lectura**
   ```dart
   final catalogos = OnlineOfflineManager(
     boxName: 'catalogos',
     endpoint: 'catalogs/items',
     uploadEnabled: false, // Solo GET
   );
   ```

4. **Manejar errores de red graciosamente**
   - WorkManager reintentará automáticamente
   - No necesitas manejar reintentos manualmente

5. **Monitorear logs en producción**
   - Usa `developer.log()` para logs que aparezcan en logcat
   - Los logs ayudan a debuggear problemas

### 📱 Dispositivos Problemáticos

Algunos fabricantes tienen optimizaciones agresivas:

- **Xiaomi (MIUI)**: Requiere permisos especiales
- **Huawei (EMUI)**: Similar a Xiaomi
- **Samsung**: Puede requerir desactivar optimización
- **OnePlus (OxygenOS)**: Generalmente funciona bien

**Solución**: Pedir al usuario que:
1. Vaya a Configuración > Apps > Tu App
2. Batería > Sin restricciones
3. Inicio automático > Permitir

---

## Preguntas Frecuentes

### ¿Por qué no funciona en iOS?

iOS tiene restricciones muy estrictas para ejecutar código en background. WorkManager solo funciona en Android. En iOS, la sincronización solo funciona cuando la app está en foreground.

### ¿Puedo sincronizar más frecuentemente que cada 15 minutos?

No, 15 minutos es el mínimo que permite Android WorkManager. Es una limitación del sistema operativo.

### ¿Funciona cuando el dispositivo está en modo ahorro de batería?

Depende del fabricante. Algunos dispositivos pueden pausar WorkManager en modo ahorro de batería. La solución es pedir al usuario que desactive la optimización de batería para tu app.

### ¿Qué pasa si el token expira durante una sincronización en background?

La sincronización fallará. Debes implementar un mecanismo para renovar el token y llamar `saveConfig()` nuevamente. WorkManager reintentará la próxima vez.

### ¿Puedo ejecutar código personalizado en background?

Sí, puedes usar un callback personalizado:

```dart
@pragma('vm:entry-point')
void myCustomCallback() {
  Workmanager().executeTask((task, inputData) async {
    // 1. Sincronizar managers
    final result = await executeBackgroundSync();
    
    // 2. Tu código personalizado
    await miLogicaPersonalizada(result.baseUrl!, result.token!);
    
    return true;
  });
}

// Inicializar con callback personalizado
await BackgroundSyncService.initialize(
  customCallback: myCustomCallback,
);
```

---

## Recursos Adicionales

- [Documentación oficial de WorkManager](https://developer.android.com/topic/libraries/architecture/workmanager)
- [Documentación de workmanager Flutter](https://pub.dev/packages/workmanager)
- [Guía de optimización de batería Android](https://developer.android.com/training/monitoring-device-state/doze-standby)

---

## Soporte

Si tienes problemas:

1. Revisa los logs con `adb logcat`
2. Verifica que todos los permisos están configurados
3. Verifica que `saveConfig()` se llamó después del login
4. Verifica que los managers están registrados
5. Verifica que la sincronización periódica está iniciada

---

**Última actualización**: 2025-01-XX

