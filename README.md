# 🚀 Betuko Offline Sync v2.0.0

Una librería Flutter **offline-first** completa y súper fácil de usar para aplicaciones que necesitan sincronización automática con servidores. Diseñada para funcionar perfectamente tanto online como offline.

## ✨ Características Principales

- 🔄 **Sincronización automática** cuando hay conexión
- 📱 **Offline-first**: La app funciona sin internet
- 🌐 **Detección inteligente** de respuestas del servidor (anidadas y simples)
- 🎯 **API súper simple** - solo crear y usar
- 🔧 **Auto-inicialización** - sin configuración compleja
- 📊 **Streams reactivos** para UI en tiempo real
- 🛡️ **Manejo robusto de errores**
- 🧪 **Completamente testeable**

## 🎯 Casos de Uso Perfectos

- ✅ Apps que necesitan funcionar sin internet
- ✅ Formularios que se envían cuando hay conexión
- ✅ Listas que se actualizan automáticamente
- ✅ Aplicaciones con datos críticos
- ✅ Apps con sincronización en background

## 📦 Instalación

Agrega a tu `pubspec.yaml`:

```yaml
dependencies:
  betuko_offline_sync: ^2.0.0
```

Luego ejecuta:

```bash
flutter pub get
```

## 🚀 Uso Básico - ¡3 Pasos!

### 1. Configuración Inicial (main.dart)

```dart
import 'package:flutter/material.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ¡Solo una línea de configuración!
  GlobalConfig.init(
    baseUrl: 'https://tu-api.com/api',
    token: 'tu-token-de-autenticacion',
  );
  
  runApp(MyApp());
}
```

### 2. Crear Manager (¡Auto-inicializado!)

```dart
class DataService {
  // ¡Se inicializa automáticamente!
  static final manager = OnlineOfflineManager(
    boxName: 'usuarios',
    endpoint: 'users',
  );
}
```

### 3. ¡Usar en tu UI!

```dart
class MiListaWidget extends StatefulWidget {
  @override
  _MiListaWidgetState createState() => _MiListaWidgetState();
}

class _MiListaWidgetState extends State<MiListaWidget> {
  List<Map<String, dynamic>> usuarios = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // Cargar datos (con sincronización automática)
  Future<void> _cargarDatos() async {
    setState(() { isLoading = true; });
    
    try {
      // ¡Una línea! Sincroniza y retorna datos actualizados
      final datos = await DataService.manager.getAllWithSync();
      setState(() {
        usuarios = datos;
        isLoading = false;
      });
    } catch (e) {
      setState(() { isLoading = false; });
      print('Error: $e');
    }
  }

  // Guardar nuevo usuario
  Future<void> _guardarUsuario() async {
    await DataService.manager.save({
      'nombre': 'Juan Pérez',
      'email': 'juan@ejemplo.com',
      'edad': 30,
    });
    
    _cargarDatos(); // Recargar lista
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _cargarDatos(),
        child: ListView.builder(
          itemCount: usuarios.length,
          itemBuilder: (context, index) {
            final usuario = usuarios[index];
            return ListTile(
              title: Text(usuario['nombre'] ?? 'Sin nombre'),
              subtitle: Text(usuario['email'] ?? 'Sin email'),
              trailing: usuario['sync'] == 'true' 
                ? Icon(Icons.cloud_done, color: Colors.green)
                : Icon(Icons.cloud_upload, color: Colors.orange),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _guardarUsuario,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

## 🎯 Métodos Principales

### 📥 Obtener Datos

```dart
// 1. Datos locales (súper rápido)
final datosLocales = await manager.getAll();

// 2. Datos frescos del servidor (requiere internet)
final datosFrescos = await manager.getFromServer();

// 3. Datos con sincronización automática (recomendado)
final datosActualizados = await manager.getAllWithSync();

// 4. Un registro específico
final usuario = await manager.getById('user_123');
```

### 💾 Guardar Datos

```dart
// Guardar (se sincroniza automáticamente cuando hay internet)
await manager.save({
  'nombre': 'Ana García',
  'email': 'ana@ejemplo.com',
  'departamento': 'Ventas',
});
```

### 🗑️ Eliminar Datos

```dart
// Eliminar
await manager.delete('user_123');
```

### 🔄 Sincronización Manual

```dart
// Forzar sincronización
await manager.sync();
```

### 📊 Filtros Útiles

```dart
// Solo datos pendientes de sincronizar
final pendientes = await manager.getPending();

// Solo datos ya sincronizados
final sincronizados = await manager.getSynced();

// Limpiar todo
await manager.clear();
```

## 🌊 UI Reactiva con Streams

### Datos en Tiempo Real

```dart
StreamBuilder<List<Map<String, dynamic>>>(
  stream: manager.dataStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final datos = snapshot.data!;
      return ListView.builder(
        itemCount: datos.length,
        itemBuilder: (context, index) {
          final item = datos[index];
          return ListTile(
            title: Text(item['titulo'] ?? 'Sin título'),
            subtitle: Text('Creado: ${item['created_at']}'),
          );
        },
      );
    }
    return CircularProgressIndicator();
  },
)
```

### Estado de Sincronización

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

### Estado de Conectividad

```dart
StreamBuilder<bool>(
  stream: manager.connectivityStream,
  builder: (context, snapshot) {
    final isOnline = snapshot.data ?? false;
    return Container(
      padding: EdgeInsets.all(8),
      color: isOnline ? Colors.green : Colors.red,
      child: Text(
        isOnline ? '🌐 Conectado' : '📱 Sin conexión',
        style: TextStyle(color: Colors.white),
      ),
    );
  },
)
```

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

## 🌐 Soporte para APIs Anidadas

La librería **detecta automáticamente** diferentes formatos de respuesta:

### Respuesta Anidada (Extrae automáticamente)
```json
{
  "data": [
    {"id": 1, "nombre": "Juan"},
    {"id": 2, "nombre": "Ana"}
  ],
  "total": 2,
  "page": 1
}
```
→ **Resultado**: `[{"id": 1, "nombre": "Juan"}, {"id": 2, "nombre": "Ana"}]`

### Respuesta Simple (Sin modificación)
```json
[
  {"id": 1, "nombre": "Juan"},
  {"id": 2, "nombre": "Ana"}
]
```
→ **Resultado**: `[{"id": 1, "nombre": "Juan"}, {"id": 2, "nombre": "Ana"}]`

## 🎨 Ejemplos Completos

### Ejemplo 1: Lista de Tareas

```dart
class TaskManager {
  static final manager = OnlineOfflineManager(
    boxName: 'tasks',
    endpoint: 'tasks',
  );
  
  static Future<void> agregarTarea(String titulo, String descripcion) async {
    await manager.save({
      'titulo': titulo,
      'descripcion': descripcion,
      'completada': false,
      'prioridad': 'media',
    });
  }
  
  static Future<void> completarTarea(String id) async {
    final tarea = await manager.getById(id);
    if (tarea != null) {
      tarea['completada'] = true;
      tarea['fecha_completada'] = DateTime.now().toIso8601String();
      await manager.save(tarea);
    }
  }
  
  static Future<List<Map<String, dynamic>>> getTareasPendientes() async {
    final todas = await manager.getAllWithSync();
    return todas.where((tarea) => tarea['completada'] != true).toList();
  }
}

class TaskListWidget extends StatefulWidget {
  @override
  _TaskListWidgetState createState() => _TaskListWidgetState();
}

class _TaskListWidgetState extends State<TaskListWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mis Tareas')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: TaskManager.manager.dataStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          
          final tareas = snapshot.data!;
          final pendientes = tareas.where((t) => t['completada'] != true).toList();
          
          return ListView.builder(
            itemCount: pendientes.length,
            itemBuilder: (context, index) {
              final tarea = pendientes[index];
              return CheckboxListTile(
                title: Text(tarea['titulo'] ?? 'Sin título'),
                subtitle: Text(tarea['descripcion'] ?? 'Sin descripción'),
                value: tarea['completada'] == true,
                onChanged: (bool? value) {
                  if (value == true) {
                    TaskManager.completarTarea(tarea['id']);
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoNuevaTarea(),
        child: Icon(Icons.add),
      ),
    );
  }
  
  void _mostrarDialogoNuevaTarea() {
    // Implementar diálogo para nueva tarea
  }
}
```

### Ejemplo 2: Sistema de Comentarios

```dart
class CommentSystem {
  static final manager = OnlineOfflineManager(
    boxName: 'comments',
    endpoint: 'posts/123/comments',
  );
  
  static Future<void> agregarComentario(String autor, String mensaje) async {
    await manager.save({
      'autor': autor,
      'mensaje': mensaje,
      'timestamp': DateTime.now().toIso8601String(),
      'likes': 0,
    });
  }
  
  static Future<List<Map<String, dynamic>>> getComentariosRecientes() async {
    final comentarios = await manager.getAllWithSync();
    comentarios.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    return comentarios;
  }
}
```

## 🧪 Testing

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
    
    test('debería obtener datos del servidor', () async {
      // Mock del servidor aquí
      final serverData = await manager.getFromServer();
      expect(serverData, isA<List<Map<String, dynamic>>>());
    });
  });
}
```

## 📚 API Completa

### OnlineOfflineManager

| Método | Descripción | Ejemplo |
|--------|-------------|---------|
| `getAll()` | Datos locales | `await manager.getAll()` |
| `getFromServer()` | Datos frescos del servidor | `await manager.getFromServer()` |
| `getAllWithSync()` | Datos con sincronización | `await manager.getAllWithSync()` |
| `getById(id)` | Un registro específico | `await manager.getById('123')` |
| `save(data)` | Guardar datos | `await manager.save({...})` |
| `delete(id)` | Eliminar registro | `await manager.delete('123')` |
| `sync()` | Sincronizar manualmente | `await manager.sync()` |
| `clear()` | Limpiar todo | `await manager.clear()` |
| `getPending()` | Datos pendientes | `await manager.getPending()` |
| `getSynced()` | Datos sincronizados | `await manager.getSynced()` |

### Streams Reactivos

| Stream | Tipo | Descripción |
|--------|------|-------------|
| `dataStream` | `List<Map<String, dynamic>>` | Datos en tiempo real |
| `statusStream` | `SyncStatus` | Estado de sincronización |
| `connectivityStream` | `bool` | Estado de conectividad |

### Estados de Sincronización

```dart
enum SyncStatus {
  idle,     // Sin actividad
  syncing,  // Sincronizando
  success,  // Éxito
  error,    // Error
}
```

## 🎯 Guía de Uso: ¿Cuándo usar cada método?

### `getAll()` - Datos Locales Rápidos
**✅ Usar cuando:**
- Necesitas mostrar datos inmediatamente en la UI
- Trabajas en modo offline
- No requieres los datos más actualizados

### `getFromServer()` - Datos Frescos
**✅ Usar cuando:**
- Necesitas los datos más recientes del servidor
- Implementas "pull to refresh"
- Quieres verificar cambios

### `getAllWithSync()` - Lo Mejor de Ambos Mundos
**✅ Usar cuando:**
- Quieres datos actualizados con fallback local
- Implementas carga inicial de pantallas importantes
- Necesitas sincronización inteligente

## 🚨 Manejo de Errores

```dart
try {
  final datos = await manager.getFromServer();
  // Usar datos del servidor
} catch (e) {
  // Sin internet o error del servidor
  final datosLocales = await manager.getAll();
  // Usar datos locales como fallback
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Sin conexión. Mostrando datos locales.'),
      backgroundColor: Colors.orange,
    ),
  );
}
```

## ⚡ Mejores Prácticas

### 1. Inicialización
```dart
// ✅ Correcto
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GlobalConfig.init(baseUrl: '...', token: '...');
  runApp(MyApp());
}

// ❌ Incorrecto
void main() {
  runApp(MyApp());
  // GlobalConfig no inicializado
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
    manager = OnlineOfflineManager(boxName: 'datos');
  }
  
  @override
  void dispose() {
    manager.dispose(); // ¡IMPORTANTE!
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

## 🔄 Changelog v2.0.0

### ✨ Nuevas Características
- 🌐 **Detección automática** de respuestas anidadas `{data: [...]}`
- 🚀 **Nuevo método `getFromServer()`** para datos frescos del servidor
- 🔄 **Nuevo método `getAllWithSync()`** para sincronización inteligente
- 📊 **Mejor manejo** de diferentes formatos de API
- 🛡️ **Manejo de errores mejorado**

### 🔧 Mejoras
- **Performance optimizada** en procesamiento de respuestas
- **Logs más informativos** para debugging
- **Documentación completa** con ejemplos reales
- **Mejor soporte** para APIs REST estándar

### 🐛 Correcciones
- Arreglado procesamiento de respuestas anidadas
- Mejorado manejo de errores de red
- Corregida sincronización automática

## 🤝 Contribuir

¿Encontraste un bug o tienes una idea? ¡Contribuye!

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -m 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## 📄 Licencia

MIT License - ver [LICENSE](LICENSE) para más detalles.

## 🆘 Soporte

- 📧 Email: [betuko37@gmail.com](mailto:betuko37@gmail.com)
- 🐛 Issues: [GitHub Issues](https://github.com/betuko37/online_offline/issues)
- 📖 Docs: [Documentación Completa](https://github.com/betuko37/online_offline#readme)

---

**¡Hecho con ❤️ para la comunidad Flutter!**

> 💡 **Tip**: ¿Primera vez usándola? Empieza con el ejemplo básico y ve probando los métodos uno por uno. ¡La librería está diseñada para ser súper fácil de usar!