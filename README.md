# 🌐 Flutter Offline Sync

[![pub package](https://img.shields.io/pub/v/flutter_offline_sync.svg)](https://pub.dev/packages/flutter_offline_sync)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)

Una librería Flutter poderosa para aplicaciones **offline-first** con sincronización automática, resolución de conflictos y manejo de conectividad.

## ✨ Características

- 🚀 **Offline-First**: Funciona sin conexión a internet
- 🔄 **Sincronización Automática**: Sincroniza cuando hay conexión
- 🛡️ **Resolución de Conflictos**: Maneja conflictos entre dispositivos
- 📱 **Múltiples Tablas**: Soporte para múltiples bases de datos locales
- 🌐 **APIs Flexibles**: Configuración completa de endpoints
- ⚡ **Singleton Pattern**: Fácil acceso global
- 📊 **Estado en Tiempo Real**: Streams para conectividad y sincronización
- 🔧 **Configuración Flexible**: Variables de entorno y configuración personalizada

## 🚀 Instalación

Agrega `flutter_offline_sync` a tu `pubspec.yaml`:

```yaml
dependencies:
  flutter_offline_sync: ^1.0.2
```

Luego ejecuta:

```bash
flutter pub get
```

## 📖 Uso Básico

### 1. Inicialización Simple

```dart
import 'package:flutter_offline_sync/flutter_offline_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar con configuración básica
  await OnlineOfflineManager.initSimple(
    boxName: 'mi_app',
    serverUrl: 'https://mi-api.com/api',
    syncConfig: const SyncConfig(
      uploadEndpoint: '/api/datos',
      downloadEndpoint: '/api/datos',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer tu_token',
      },
      syncInterval: Duration(minutes: 5),
    ),
  );
  
  runApp(MyApp());
}
```

### 2. Guardar Datos

```dart
// Guardar datos (se sincroniza automáticamente si hay internet)
await OnlineOfflineManager.instance.save('usuario_123', {
  'nombre': 'Juan Pérez',
  'email': 'juan@ejemplo.com',
  'fecha': DateTime.now().toIso8601String(),
});
```

### 3. Obtener Datos

```dart
// Obtener datos específicos
final usuario = OnlineOfflineManager.instance.get('usuario_123');

// Obtener todos los datos
final todosLosDatos = OnlineOfflineManager.instance.getAll();
```

### 4. Sincronización Manual

```dart
// Sincronizar manualmente
await OnlineOfflineManager.instance.sync();
```

## 🎯 Ejemplos Avanzados

### Formulario con Sincronización Automática

```dart
class FormularioScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        child: Column(
          children: [
            TextFormField(controller: _nombreController),
            TextFormField(controller: _emailController),
            ElevatedButton(
              onPressed: _enviarFormulario,
              child: Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _enviarFormulario() async {
    final payload = {
      'nombre': _nombreController.text,
      'email': _emailController.text,
      'fecha': DateTime.now().toIso8601String(),
    };
    
    final id = 'form_${DateTime.now().millisecondsSinceEpoch}';
    
    // Se guarda localmente y sincroniza automáticamente
    await OnlineOfflineManager.instance.save(id, payload);
  }
}
```

### Monitoreo de Estado

```dart
class EstadoScreen extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    
    // Escuchar cambios de conectividad
    OnlineOfflineManager.instance.connectivity.listen((isConnected) {
      print('Conectado: $isConnected');
    });
    
    // Escuchar estado de sincronización
    OnlineOfflineManager.instance.status.listen((status) {
      print('Estado de sync: $status');
    });
  }
}
```

## 🔧 Configuración Avanzada

### Variables de Entorno

```dart
// Cargar variables de entorno
await dotenv.load(fileName: ".env");

// Usar en configuración
await OnlineOfflineManager.initSimple(
  boxName: dotenv.env['DATABASE_NAME'] ?? 'mi_app',
  serverUrl: dotenv.env['SERVER_URL'] ?? 'https://mi-api.com/api',
  syncConfig: SyncConfig(
    uploadEndpoint: dotenv.env['UPLOAD_ENDPOINT'] ?? '/api/datos',
    downloadEndpoint: dotenv.env['DOWNLOAD_ENDPOINT'] ?? '/api/datos',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${dotenv.env['API_TOKEN']}',
    },
    syncInterval: Duration(
      minutes: int.tryParse(dotenv.env['SYNC_INTERVAL_MINUTES'] ?? '5') ?? 5
    ),
  ),
);
```

### Múltiples Tablas

```dart
// Crear múltiples tablas
final localDB = LocalDB(databaseName: 'mi_app');
await localDB.init();

await localDB.createTable('usuarios');
await localDB.createTable('productos');
await localDB.createTable('pedidos');

// Usar tablas específicas
await localDB.put('usuarios', 'user_1', {'nombre': 'Juan'});
await localDB.put('productos', 'prod_1', {'nombre': 'Laptop'});
```

### Resolución de Conflictos

```dart
final syncManager = SyncManager(
  local: localDB,
  remote: remoteDB,
  tableName: 'usuarios',
  endpoint: '/api/usuarios',
  conflictStrategy: ConflictResolutionStrategy.lastWriteWins,
  customStrategies: {
    'usuario_admin': ConflictResolutionStrategy.serverWins,
    'usuario_temp': ConflictResolutionStrategy.clientWins,
  },
);

// Sincronizar con manejo de conflictos
await syncManager.sync();
```

## 📊 API Reference

### OnlineOfflineManager

| Método | Descripción |
|--------|-------------|
| `initSimple()` | Inicialización simple con configuración básica |
| `save(id, data)` | Guarda datos localmente |
| `get(id)` | Obtiene datos específicos |
| `getAll()` | Obtiene todos los datos |
| `delete(id)` | Elimina datos específicos |
| `sync()` | Sincroniza manualmente |
| `clear()` | Limpia todos los datos |
| `dispose()` | Libera recursos |

### SyncConfig

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `uploadEndpoint` | String | Endpoint para subir datos |
| `downloadEndpoint` | String | Endpoint para descargar datos |
| `headers` | Map<String, String> | Headers HTTP |
| `timeout` | Duration | Timeout de requests |
| `syncInterval` | Duration | Intervalo de sincronización automática |

### ConflictResolutionStrategy

| Estrategia | Descripción |
|------------|-------------|
| `lastWriteWins` | El último cambio gana |
| `firstWriteWins` | El primer cambio gana |
| `serverWins` | El servidor siempre gana |
| `clientWins` | El cliente siempre gana |
| `manual` | Resolución manual requerida |
| `merge` | Fusión inteligente de datos |

## 🧪 Testing

```dart
// Ejecutar tests
flutter test

// Tests específicos
flutter test test/online_offline_test.dart
flutter test test/conflict_manager_test.dart
```

## 🤝 Contribuir

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📝 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## 🙏 Agradecimientos

- [Hive](https://pub.dev/packages/hive) - Base de datos local
- [HTTP](https://pub.dev/packages/http) - Requests HTTP
- [Connectivity Plus](https://pub.dev/packages/connectivity_plus) - Detección de conectividad
- [Flutter DotEnv](https://pub.dev/packages/flutter_dotenv) - Variables de entorno

## 📞 Soporte

Si tienes preguntas o necesitas ayuda:

- 📧 Email: tu-email@ejemplo.com
- 🐛 Issues: [GitHub Issues](https://github.com/tu-usuario/online_offline/issues)
- 📖 Documentación: [Wiki](https://github.com/tu-usuario/online_offline/wiki)

---

**¡Hecho con ❤️ para la comunidad Flutter!**