# 📚 Betuko Offline Sync - Documentación Técnica Completa

## 🏗️ Arquitectura Modular

La librería `betuko_offline_sync` está diseñada con una **arquitectura modular** que te permite usar desde el manager completo hasta servicios individuales según tus necesidades.

### 📁 Estructura del Proyecto

```
lib/
├── betuko_offline_sync.dart          # Archivo principal con exports
├── src/
│   ├── online_offline_manager.dart   # Manager principal simplificado
│   ├── api/
│   │   └── api_client.dart           # Cliente HTTP simplificado
│   ├── storage/
│   │   └── local_storage.dart        # Almacenamiento local con Hive
│   ├── sync/
│   │   └── sync_service.dart         # Servicio de sincronización
│   ├── connectivity/
│   │   └── connectivity_service.dart # Servicio de conectividad
│   ├── config/
│   │   └── global_config.dart        # Configuración global
│   └── models/
│       └── sync_status.dart          # Estados de sincronización
```

---

## 🎯 OnlineOfflineManager

El **manager principal** que combina todos los servicios para un uso simplificado.

### Constructor

```dart
OnlineOfflineManager({
  required String boxName,  // Nombre del box de Hive
  String? endpoint,         // Endpoint opcional del servidor
})
```

### Métodos Principales

#### `save(Map<String, dynamic> data)`
Guarda datos localmente y sincroniza automáticamente si hay conexión.

```dart
final manager = OnlineOfflineManager(
  boxName: 'usuarios',
  endpoint: 'users',
);

await manager.save({
  'nombre': 'Juan Pérez',
  'email': 'juan@ejemplo.com',
  'edad': 30,
});
```

#### `getAll()`
Obtiene todos los datos almacenados localmente.

```dart
final datos = await manager.getAll();
print('Total de registros: ${datos.length}');
```

#### `getById(String id)`
Obtiene un registro específico por ID.

```dart
final usuario = await manager.getById('user_123');
if (usuario != null) {
  print('Usuario: ${usuario['nombre']}');
}
```

#### `delete(String id)`
Elimina un registro específico.

```dart
await manager.delete('user_123');
```

#### `sync()`
Fuerza una sincronización manual con el servidor.

```dart
await manager.sync();
```

#### `clear()`
Limpia todos los datos almacenados.

```dart
await manager.clear();
```

#### `getPending()`
Obtiene solo los registros pendientes de sincronizar.

```dart
final pendientes = await manager.getPending();
print('Registros pendientes: ${pendientes.length}');
```

#### `getSynced()`
Obtiene solo los registros ya sincronizados.

```dart
final sincronizados = await manager.getSynced();
print('Registros sincronizados: ${sincronizados.length}');
```

### Streams Reactivos

#### `dataStream`
Stream que emite todos los datos cuando cambian.

```dart
StreamBuilder<List<Map<String, dynamic>>>(
  stream: manager.dataStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return ListView.builder(
        itemCount: snapshot.data!.length,
        itemBuilder: (context, index) {
          final item = snapshot.data![index];
          return ListTile(
            title: Text(item['nombre'] ?? 'Sin nombre'),
            subtitle: Text(item['email'] ?? 'Sin email'),
          );
        },
      );
    }
    return CircularProgressIndicator();
  },
)
```

#### `statusStream`
Stream del estado de sincronización.

```dart
StreamBuilder<SyncStatus>(
  stream: manager.statusStream,
  builder: (context, snapshot) {
    switch (snapshot.data) {
      case SyncStatus.idle:
        return Icon(Icons.sync, color: Colors.grey);
      case SyncStatus.syncing:
        return CircularProgressIndicator();
      case SyncStatus.success:
        return Icon(Icons.check_circle, color: Colors.green);
      case SyncStatus.error:
        return Icon(Icons.error, color: Colors.red);
      default:
        return Container();
    }
  },
)
```

#### `connectivityStream`
Stream del estado de conectividad.

```dart
StreamBuilder<bool>(
  stream: manager.connectivityStream,
  builder: (context, snapshot) {
    final isOnline = snapshot.data ?? false;
    return Container(
      padding: EdgeInsets.all(8),
      color: isOnline ? Colors.green : Colors.red,
      child: Text(
        isOnline ? 'Conectado' : 'Sin conexión',
        style: TextStyle(color: Colors.white),
      ),
    );
  },
)
```

---

## 🗄️ LocalStorage

Servicio de almacenamiento local usando Hive.

### Constructor

```dart
final storage = LocalStorage(boxName: 'mi_box');
await storage.initialize();
```

### Métodos

```dart
// Guardar datos
await storage.save('key_1', {'nombre': 'Juan', 'edad': 30});

// Obtener datos
final datos = await storage.get('key_1');

// Obtener todos
final todos = await storage.getAll();

// Filtrar datos
final adultos = await storage.where((item) => item['edad'] > 18);

// Verificar existencia
final existe = await storage.contains('key_1');

// Contar registros
final cantidad = await storage.length();

// Eliminar
await storage.delete('key_1');

// Limpiar todo
await storage.clear();
```

---

## 🌐 ApiClient

Cliente HTTP simplificado para comunicación con el servidor.

### Métodos

#### `post(String endpoint, Map<String, dynamic> data)`
Envía datos al servidor.

```dart
final client = ApiClient();
final response = await client.post('users', {
  'nombre': 'Juan',
  'email': 'juan@ejemplo.com',
});

if (response.isSuccess) {
  print('Datos enviados correctamente');
  print('Respuesta: ${response.data}');
} else {
  print('Error: ${response.error}');
}
```

#### `get(String endpoint)`
Obtiene datos del servidor.

```dart
final response = await client.get('users');

if (response.isSuccess) {
  final usuarios = response.data as List;
  print('Usuarios obtenidos: ${usuarios.length}');
} else {
  print('Error: ${response.error}');
}
```

### Clase ApiResponse

```dart
class ApiResponse {
  final bool isSuccess;      // Si la petición fue exitosa
  final int statusCode;      // Código de estado HTTP
  final dynamic data;        // Datos de la respuesta
  final String? error;       // Mensaje de error si existe
}
```

---

## 🔄 SyncService

Servicio de sincronización offline-first.

### Constructor

```dart
final storage = LocalStorage(boxName: 'datos');
await storage.initialize();

final syncService = SyncService(
  storage: storage,
  endpoint: 'mi-endpoint',
);
```

### Métodos

#### `sync()`
Sincroniza datos con el servidor.

```dart
await syncService.sync();
```

### Stream de Estado

```dart
syncService.statusStream.listen((status) {
  switch (status) {
    case SyncStatus.syncing:
      print('Sincronizando...');
      break;
    case SyncStatus.success:
      print('Sincronización exitosa');
      break;
    case SyncStatus.error:
      print('Error en sincronización');
      break;
  }
});
```

---

## 📡 ConnectivityService

Servicio de monitoreo de conectividad.

### Uso

```dart
final connectivity = ConnectivityService();
await connectivity.initialize();

// Escuchar cambios de conectividad
connectivity.connectivityStream.listen((isOnline) {
  if (isOnline) {
    print('🌐 Conectado a internet');
    // Ejecutar sincronización
  } else {
    print('📱 Sin conexión a internet');
    // Trabajar en modo offline
  }
});

// Verificar estado actual
if (connectivity.isOnline) {
  print('Hay conexión');
} else {
  print('Sin conexión');
}
```

---

## ⚙️ GlobalConfig

Configuración global de la librería.

### Configuración

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  GlobalConfig.init(
    baseUrl: 'https://mi-api.com/api',
    token: 'mi_token_de_autenticacion',
  );
  
  runApp(MyApp());
}
```

### Métodos

```dart
// Verificar si está inicializado
if (GlobalConfig.isInitialized) {
  print('Configuración lista');
}

// Obtener configuración
final baseUrl = GlobalConfig.baseUrl;
final token = GlobalConfig.token;

// Limpiar configuración (útil para tests)
GlobalConfig.clear();
```

---

## 🎯 SyncStatus

Enum que define los estados de sincronización.

```dart
enum SyncStatus {
  idle,     // Sin actividad
  syncing,  // Sincronizando
  success,  // Sincronización exitosa
  error,    // Error en sincronización
}
```

---

## 🧪 Ejemplos Avanzados

### Uso Modular Personalizado

```dart
class MiServicioPersonalizado {
  final LocalStorage _storage;
  final ApiClient _apiClient;
  final ConnectivityService _connectivity;
  
  MiServicioPersonalizado() 
    : _storage = LocalStorage(boxName: 'mi_servicio'),
      _apiClient = ApiClient(),
      _connectivity = ConnectivityService();
  
  Future<void> initialize() async {
    await _storage.initialize();
    await _connectivity.initialize();
    
    // Escuchar cambios de conectividad
    _connectivity.connectivityStream.listen((isOnline) {
      if (isOnline) {
        _syncDatosPendientes();
      }
    });
  }
  
  Future<void> guardarDato(Map<String, dynamic> dato) async {
    // Agregar timestamp
    dato['created_at'] = DateTime.now().toIso8601String();
    dato['synced'] = false;
    
    // Guardar localmente
    final id = 'item_${DateTime.now().millisecondsSinceEpoch}';
    await _storage.save(id, dato);
    
    // Intentar sincronizar si hay conexión
    if (_connectivity.isOnline) {
      await _sincronizarDato(id, dato);
    }
  }
  
  Future<void> _sincronizarDato(String id, Map<String, dynamic> dato) async {
    try {
      final response = await _apiClient.post('mi-endpoint', dato);
      
      if (response.isSuccess) {
        // Marcar como sincronizado
        dato['synced'] = true;
        await _storage.save(id, dato);
      }
    } catch (e) {
      print('Error sincronizando: $e');
    }
  }
  
  Future<void> _syncDatosPendientes() async {
    final pendientes = await _storage.where((item) => item['synced'] == false);
    
    for (final dato in pendientes) {
      // Encontrar ID del dato
      final keys = await _storage.getKeys();
      for (final key in keys) {
        final item = await _storage.get(key);
        if (item != null && item['created_at'] == dato['created_at']) {
          await _sincronizarDato(key, dato);
          break;
        }
      }
    }
  }
}
```

### Manager con Validación Personalizada

```dart
class ValidatedManager extends OnlineOfflineManager {
  ValidatedManager({
    required String boxName,
    String? endpoint,
  }) : super(boxName: boxName, endpoint: endpoint);
  
  @override
  Future<void> save(Map<String, dynamic> data) async {
    // Validar datos antes de guardar
    if (!_validarDatos(data)) {
      throw Exception('Datos inválidos');
    }
    
    // Agregar metadatos
    data['validated_at'] = DateTime.now().toIso8601String();
    data['version'] = '1.0';
    
    await super.save(data);
  }
  
  bool _validarDatos(Map<String, dynamic> data) {
    // Validaciones personalizadas
    if (data['nombre'] == null || data['nombre'].toString().isEmpty) {
      return false;
    }
    
    if (data['email'] != null) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(data['email'])) {
        return false;
      }
    }
    
    return true;
  }
}
```

---

## 🧪 Testing

### Test del OnlineOfflineManager

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() {
  group('OnlineOfflineManager Tests', () {
    late OnlineOfflineManager manager;
    
    setUp(() {
      GlobalConfig.init(
        baseUrl: 'https://test-api.com',
        token: 'test-token',
      );
      
      manager = OnlineOfflineManager(
        boxName: 'test_box',
        endpoint: 'test',
      );
    });
    
    tearDown(() {
      manager.dispose();
      GlobalConfig.clear();
    });
    
    test('debería guardar datos localmente', () async {
      final testData = {
        'nombre': 'Test User',
        'email': 'test@ejemplo.com',
      };
      
      await manager.save(testData);
      
      final allData = await manager.getAll();
      expect(allData.length, 1);
      expect(allData.first['nombre'], 'Test User');
    });
    
    test('debería filtrar datos pendientes y sincronizados', () async {
      // Guardar dato sin sincronizar
      await manager.save({'tipo': 'pendiente'});
      
      // Simular dato sincronizado
      final storage = LocalStorage(boxName: 'test_box');
      await storage.initialize();
      await storage.save('synced_1', {
        'tipo': 'sincronizado',
        'sync': DateTime.now().toIso8601String(),
      });
      
      final pendientes = await manager.getPending();
      final sincronizados = await manager.getSynced();
      
      expect(pendientes.length, 1);
      expect(sincronizados.length, 1);
      expect(pendientes.first['tipo'], 'pendiente');
      expect(sincronizados.first['tipo'], 'sincronizado');
    });
  });
}
```

### Test de Servicios Individuales

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() {
  group('LocalStorage Tests', () {
    late LocalStorage storage;
    
    setUp(() async {
      storage = LocalStorage(boxName: 'test_storage');
      await storage.initialize();
    });
    
    tearDown(() async {
      await storage.clear();
      await storage.close();
    });
    
    test('debería guardar y recuperar datos', () async {
      final testData = {'key': 'value', 'number': 42};
      
      await storage.save('test_key', testData);
      final retrieved = await storage.get('test_key');
      
      expect(retrieved, equals(testData));
    });
    
    test('debería filtrar datos correctamente', () async {
      await storage.save('item1', {'edad': 25, 'activo': true});
      await storage.save('item2', {'edad': 17, 'activo': true});
      await storage.save('item3', {'edad': 30, 'activo': false});
      
      final adultos = await storage.where((item) => item['edad'] >= 18);
      final activos = await storage.where((item) => item['activo'] == true);
      
      expect(adultos.length, 2);
      expect(activos.length, 2);
    });
  });
}
```

---

## 🚨 Manejo de Errores

### Errores Comunes y Soluciones

#### Error: "Base URL no configurada"
```dart
// ❌ Error
final client = ApiClient();
await client.get('users'); // Throws exception

// ✅ Solución
GlobalConfig.init(
  baseUrl: 'https://mi-api.com',
  token: 'mi-token',
);
```

#### Error: "Box no inicializado"
```dart
// ❌ Error
final storage = LocalStorage(boxName: 'mi_box');
await storage.save('key', data); // Throws exception

// ✅ Solución
final storage = LocalStorage(boxName: 'mi_box');
await storage.initialize();
await storage.save('key', data);
```

#### Manejo de Errores de Sincronización
```dart
manager.statusStream.listen((status) {
  if (status == SyncStatus.error) {
    // Mostrar mensaje de error al usuario
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error en sincronización. Los datos se guardarán localmente.'),
        backgroundColor: Colors.orange,
      ),
    );
  }
});
```

---

## ⚡ Mejores Prácticas

### 1. Inicialización Correcta
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configurar ANTES de crear managers
  GlobalConfig.init(
    baseUrl: 'https://mi-api.com/api',
    token: await obtenerToken(),
  );
  
  runApp(MyApp());
}
```

### 2. Manejo de Recursos
```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late OnlineOfflineManager manager;
  
  @override
  void initState() {
    super.initState();
    manager = OnlineOfflineManager(boxName: 'datos', endpoint: 'users');
  }
  
  @override
  void dispose() {
    manager.dispose(); // ¡IMPORTANTE! Liberar recursos
    super.dispose();
  }
}
```

### 3. Validación de Datos
```dart
Future<void> guardarUsuario(Map<String, dynamic> usuario) async {
  // Validar antes de guardar
  if (usuario['email'] == null || !esEmailValido(usuario['email'])) {
    throw Exception('Email inválido');
  }
  
  // Agregar metadatos
  usuario['created_at'] = DateTime.now().toIso8601String();
  usuario['app_version'] = await getAppVersion();
  
  await manager.save(usuario);
}
```

### 4. Optimización de Sincronización
```dart
// Sincronizar solo cuando sea necesario
connectivity.connectivityStream.listen((isOnline) {
  if (isOnline) {
    // Verificar si hay datos pendientes antes de sincronizar
    manager.getPending().then((pending) {
      if (pending.isNotEmpty) {
        manager.sync();
      }
    });
  }
});
```

---

## 🔧 Configuración Avanzada

### Variables de Entorno
```dart
class AppConfig {
  static String get baseUrl {
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api-dev.miapp.com',
    );
  }
  
  static String get apiToken {
    return const String.fromEnvironment('API_TOKEN');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  GlobalConfig.init(
    baseUrl: AppConfig.baseUrl,
    token: AppConfig.apiToken,
  );
  
  runApp(MyApp());
}
```

### Configuración por Entorno
```dart
enum Environment { development, staging, production }

class EnvironmentConfig {
  static const environment = Environment.development;
  
  static String get baseUrl {
    switch (environment) {
      case Environment.development:
        return 'https://dev-api.miapp.com';
      case Environment.staging:
        return 'https://staging-api.miapp.com';
      case Environment.production:
        return 'https://api.miapp.com';
    }
  }
}
```

---

Esta documentación cubre todos los aspectos técnicos de la librería `betuko_offline_sync`. Para ejemplos específicos o casos de uso avanzados, consulta la documentación del repositorio o contacta al equipo de soporte.
