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

// 5. Datos ordenados por fecha (NUEVO)
final datosOrdenados = await manager.getAll(); // Ya vienen ordenados

// 6. Últimos 50 registros por temporada (NUEVO)
final ultimosPorTemporada = await manager.getLatestBySeason('season_id', limit: 50);

// 7. Datos agrupados por temporada (NUEVO)
final datosPorTemporada = await manager.getLatestByAllSeasons(limit: 50);
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
// Sincronización inteligente (recomendado)
await manager.sync(); // Solo sincroniza si es necesario

// Sincronización forzada (ignora caché)
await manager.forceSync(); // Siempre sincroniza

// Sincronización inmediata (bypasa verificaciones)
await manager.syncNow(); // Sincroniza inmediatamente
```

### 📊 Filtros Útiles

```dart
// Solo datos pendientes de sincronizar
final pendientes = await manager.getPending();

// Solo datos ya sincronizados
final sincronizados = await manager.getSynced();

// Limpiar registros duplicados
await manager.cleanDuplicates();

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
    syncMinutes: 10, // Sincronizar cada 10 minutos
    maxPagesPerSync: 5, // Máximo 5 páginas por sincronización
    syncTimeoutMinutes: 30, // Usar descarga completa si han pasado más de 30 minutos
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

### 🚀 Configuración Optimizada para Evitar Descargas Masivas

Si experimentas descargas masivas en cada reinicio, usa esta configuración optimizada:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configuración optimizada para evitar descargas masivas
  GlobalConfig.init(
    baseUrl: 'https://tu-api.com',
    token: 'tu-token',
    syncMinutes: 15, // Sincronizar cada 15 minutos (más tiempo)
    useIncrementalSync: true, // Usar sincronización incremental
    pageSize: 50, // Páginas más grandes para menos requests
    lastModifiedField: 'lastModifiedAt', // Campo de timestamp
    syncOnReconnect: true, // Sincronizar al reconectar
    maxLocalRecords: 1000, // Límite de registros locales
    maxDaysToKeep: 7, // Mantener registros por 7 días
    maxPagesPerSync: 5, // Máximo 5 páginas por sincronización
    syncTimeoutMinutes: 30, // Usar descarga completa si han pasado más de 30 minutos
  );
  
  runApp(MyApp());
}
```

#### 🎯 Configuraciones Recomendadas por Tipo de App

**📱 Para aplicaciones móviles:**
```dart
GlobalConfig.init(
  baseUrl: '...',
  token: '...',
  syncMinutes: 15,
  maxPagesPerSync: 3,
  syncTimeoutMinutes: 30,
  pageSize: 50,
);
```

**💻 Para aplicaciones web:**
```dart
GlobalConfig.init(
  baseUrl: '...',
  token: '...',
  syncMinutes: 5,
  maxPagesPerSync: 10,
  syncTimeoutMinutes: 15,
  pageSize: 25,
);
```

**🏢 Para aplicaciones empresariales:**
```dart
GlobalConfig.init(
  baseUrl: '...',
  token: '...',
  syncMinutes: 30,
  maxPagesPerSync: 20,
  syncTimeoutMinutes: 60,
  pageSize: 100,
);
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

## 🌾 Manejo de Datos por Temporada (NUEVO)

### Últimos 50 Registros por Temporada

```dart
class HarvestService {
  static final manager = OnlineOfflineManager(
    boxName: 'harvest_delivery',
    endpoint: 'harvest-delivery',
    enableAutoCleanup: true, // Limpieza automática habilitada
  );
  
  /// Obtener los últimos 50 registros de una temporada específica
  static Future<List<Map<String, dynamic>>> getLatestHarvests(String seasonId) async {
    return await manager.getLatestBySeason(seasonId, limit: 50);
  }
  
  /// Obtener datos agrupados por todas las temporadas
  static Future<Map<String, List<Map<String, dynamic>>>> getAllSeasonsData() async {
    return await manager.getLatestByAllSeasons(limit: 50);
  }
  
  /// Crear un nuevo registro de cosecha
  static Future<void> createHarvestRecord({
    required String seasonId,
    required String folio,
    required int quantity,
    required String driverName,
    required String crewName,
  }) async {
    await manager.save({
      'seasonId': seasonId,
      'folio': folio,
      'quantity': quantity,
      'date': DateTime.now().toIso8601String(),
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      'driver': {'name': driverName},
      'crew': {'name': crewName},
      'isActive': true,
    });
  }
  
  /// Obtener estadísticas de sincronización
  static Future<Map<String, int>> getSyncStats() async {
    final allData = await manager.getAll();
    final syncedData = await manager.getSync();
    final localData = await manager.getLocal();
    
    return {
      'total': allData.length,
      'synced': syncedData.length,
      'pending': localData.length,
    };
  }
}
```

### UI Reactiva para Datos de Cosecha

```dart
class HarvestListWidget extends StatefulWidget {
  final String seasonId;
  
  const HarvestListWidget({Key? key, required this.seasonId}) : super(key: key);
  
  @override
  _HarvestListWidgetState createState() => _HarvestListWidgetState();
}

class _HarvestListWidgetState extends State<HarvestListWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cosechas - Temporada ${widget.seasonId}'),
        actions: [
          StreamBuilder<SyncStatus>(
            stream: HarvestService.manager.statusStream,
            builder: (context, snapshot) {
              switch (snapshot.data) {
                case SyncStatus.syncing:
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                case SyncStatus.success:
                  return Icon(Icons.cloud_done, color: Colors.green);
                case SyncStatus.error:
                  return Icon(Icons.cloud_off, color: Colors.red);
                default:
                  return Icon(Icons.sync, color: Colors.grey);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: HarvestService.manager.dataStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          
          // Filtrar por temporada y ordenar por fecha
          final allData = snapshot.data!;
          final seasonData = allData
              .where((item) => item['seasonId'] == widget.seasonId)
              .toList();
          
          if (seasonData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay registros de cosecha', 
                       style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }
          
          return ListView.builder(
            itemCount: seasonData.length,
            itemBuilder: (context, index) {
              final harvest = seasonData[index];
              final isSynced = harvest['sync'] == 'true';
              
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSynced ? Colors.green : Colors.orange,
                    child: Icon(
                      isSynced ? Icons.cloud_done : Icons.cloud_upload,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(harvest['folio'] ?? 'Sin folio'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cantidad: ${harvest['quantity']}'),
                      Text('Conductor: ${harvest['driver']?['name'] ?? 'N/A'}'),
                      Text('Cuadrilla: ${harvest['crew']?['name'] ?? 'N/A'}'),
                      Text('Fecha: ${_formatDate(harvest['date'])}'),
                    ],
                  ),
                  trailing: Text(
                    isSynced ? 'Sincronizado' : 'Pendiente',
                    style: TextStyle(
                      color: isSynced ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateHarvestDialog(),
        child: Icon(Icons.add),
      ),
    );
  }
  
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Fecha inválida';
    }
  }
  
  void _showCreateHarvestDialog() {
    // Implementar diálogo para crear nueva cosecha
  }
}
```

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
| `getAll()` | Datos locales ordenados | `await manager.getAll()` |
| `getFromServer()` | Datos frescos del servidor | `await manager.getFromServer()` |
| `getAllWithSync()` | Datos con sincronización | `await manager.getAllWithSync()` |
| `getById(id)` | Un registro específico | `await manager.getById('123')` |
| `save(data)` | Guardar datos | `await manager.save({...})` |
| `delete(id)` | Eliminar registro | `await manager.delete('123')` |
| `sync()` | Sincronización inteligente | `await manager.sync()` |
| `forceSync()` | Sincronización forzada | `await manager.forceSync()` |
| `syncNow()` | Sincronización inmediata | `await manager.syncNow()` |
| `clear()` | Limpiar todo | `await manager.clear()` |
| `getPending()` | Datos pendientes | `await manager.getPending()` |
| `getSynced()` | Datos sincronizados | `await manager.getSynced()` |
| **`cleanDuplicates()`** | **Limpiar registros duplicados** | **`await manager.cleanDuplicates()`** |
| **`getLatestBySeason(seasonId, limit)`** | **Últimos N registros por temporada** | **`await manager.getLatestBySeason('season_123', limit: 50)`** |
| **`getLatestByAllSeasons(limit)`** | **Datos agrupados por temporada** | **`await manager.getLatestByAllSeasons(limit: 50)`** |

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

### 🔄 Métodos de Sincronización

#### `sync()` - Sincronización Manual
**✅ Usar cuando:**
- Quieres sincronización manual que siempre sincroniza
- Necesitas datos frescos del servidor
- El usuario hace "pull to refresh" o botón de actualizar

**Comportamiento:**
- Siempre sincroniza (no verifica tiempo)
- Usa la misma lógica que `forceSync()` y `syncNow()`
- Logs: "Sincronización manual iniciada..."

#### `forceSync()` - Sincronización Forzada
**✅ Usar cuando:**
- Quieres ignorar el caché y sincronizar siempre
- Necesitas datos frescos del servidor
- El usuario hace "pull to refresh"

**Comportamiento:**
- Ignora caché de tiempo
- Usa sincronización incremental optimizada
- Logs: "Sincronización forzada iniciada..."

#### `syncNow()` - Sincronización Inmediata
**✅ Usar cuando:**
- Necesitas sincronización inmediata sin verificaciones
- Quieres bypasar todas las optimizaciones de tiempo
- Es para casos especiales donde necesitas control total

**Comportamiento:**
- Omite todas las verificaciones
- Usa sincronización incremental optimizada
- Logs: "Sincronización inmediata iniciada..."

### 🤖 Sincronización Automática vs Manual

#### **Sincronización Automática (por tiempo)**
- **Se activa en:** `getAll()`, timer automático, reconexión
- **Comportamiento:** Verifica tiempo transcurrido antes de sincronizar
- **Lógica:** Solo sincroniza si han pasado los minutos configurados
- **Método usado:** `_smartSync()` → `_downloadFromServer()`
- **Logs:** "Sincronización automática iniciada..." o "Sincronización omitida (datos recientes)"

#### **Sincronización Manual**
- **Se activa en:** `sync()`, `forceSync()`, `syncNow()`
- **Comportamiento:** Siempre sincroniza sin verificar tiempo
- **Lógica:** Usa `_downloadFromServerManual()` que siempre sincroniza
- **Método usado:** `_syncService.sync()`, `_syncService.forceSync()`, `_syncService.syncNow()`
- **Logs:** "Sincronización manual/forzada/inmediata iniciada..."

### 🔧 Diferencia Técnica

#### **Sincronización Automática:**
```dart
// Usa _downloadFromServer() que verifica tiempo
if (timeSinceLastSync.inMinutes > GlobalConfig.syncTimeoutMinutes) {
  await _downloadFull(); // Descarga completa
} else {
  await _downloadUltraSmart(); // Verifica si es muy reciente
}
```

#### **Sincronización Manual:**
```dart
// Usa _downloadFromServerManual() que siempre sincroniza
if (GlobalConfig.useIncrementalSync) {
  await _downloadIncremental(); // Siempre sincroniza
} else {
  await _downloadFull(); // Siempre sincroniza
}
```

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

## 🧹 Manejo de Duplicados

### Problema de Duplicados

Si experimentas registros duplicados en la interfaz, esto puede deberse a:

- Sincronización incremental que no detecta correctamente registros existentes
- Backend que no respeta el parámetro `since` correctamente
- Problemas de conectividad durante la sincronización

### Solución Automática

La librería ahora incluye limpieza automática de duplicados:

```dart
// La sincronización incremental limpia duplicados automáticamente
await manager.sync();

// También puedes limpiar duplicados manualmente
await manager.cleanDuplicates();
```

### Solución Manual

Si necesitas limpiar duplicados manualmente:

```dart
class DataService {
  static final manager = OnlineOfflineManager(
    boxName: 'usuarios',
    endpoint: 'users',
  );
  
  /// Limpiar duplicados y actualizar UI
  static Future<void> cleanupDuplicates() async {
    await manager.cleanDuplicates();
    // La UI se actualizará automáticamente
  }
  
  /// Verificar si hay duplicados
  static Future<bool> hasDuplicates() async {
    final allData = await manager.getAll();
    final idCounts = <String, int>{};
    
    for (final record in allData) {
      final id = record['id']?.toString();
      if (id != null) {
        idCounts[id] = (idCounts[id] ?? 0) + 1;
      }
    }
    
    return idCounts.values.any((count) => count > 1);
  }
}
```

### UI para Limpieza de Duplicados

```dart
class DuplicateCleanupWidget extends StatefulWidget {
  @override
  _DuplicateCleanupWidgetState createState() => _DuplicateCleanupWidgetState();
}

class _DuplicateCleanupWidgetState extends State<DuplicateCleanupWidget> {
  bool _isCleaning = false;
  
  Future<void> _cleanDuplicates() async {
    setState(() { _isCleaning = true; });
    
    try {
      await DataService.cleanupDuplicates();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicados eliminados correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al limpiar duplicados: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() { _isCleaning = false; });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _isCleaning ? null : _cleanDuplicates,
      child: _isCleaning 
        ? CircularProgressIndicator(color: Colors.white)
        : Icon(Icons.cleaning_services),
      tooltip: 'Limpiar duplicados',
    );
  }
}
```

## ⚡ Optimización de Sincronización

### 🧠 Sincronización Ultra-Inteligente

La librería ahora incluye **sincronización ultra-inteligente** que optimiza el rendimiento:

- 🔍 **Verificación previa**: Hace una consulta pequeña para verificar si hay cambios
- 📊 **Comparación local**: Compara registros existentes con los del servidor
- ⚡ **Procesamiento selectivo**: Solo procesa registros nuevos o modificados
- 📈 **Logs detallados**: Muestra estadísticas de registros procesados

```dart
// ✅ Sincronización ultra-inteligente (recomendado)
await manager.sync(); // Verifica cambios antes de descargar

// ⚡ Sincronización forzada (para pull-to-refresh)
await manager.forceSync(); // Ignora caché pero usa optimizaciones

// 🚀 Sincronización inmediata (para casos especiales)
await manager.syncNow(); // Bypasa verificaciones pero optimiza descarga
```

### 📊 Comparación de Métodos

| Método | Velocidad | Uso Recomendado | Verifica Tiempo | Optimización |
|--------|-----------|-----------------|-----------------|--------------|
| `sync()` | ⚡⚡⚡⚡⚡ Muy rápida | Uso general | ✅ Sí | 🧠 Ultra-inteligente |
| `forceSync()` | ⚡⚡⚡ Rápida | Pull to refresh | ❌ No | 🎯 Incremental optimizada |
| `syncNow()` | ⚡⚡ Moderada | Casos especiales | ❌ No | 🎯 Incremental optimizada |

### 🎯 Cuándo Usar Cada Método

```dart
// Para la mayoría de casos (más eficiente)
await manager.sync(); // Ultra-inteligente con verificación previa

// Para "pull to refresh" en la UI
await manager.forceSync(); // Forzada pero optimizada

// Para casos especiales donde necesitas control total
await manager.syncNow(); // Inmediata pero optimizada
```

### 🚀 Optimizaciones Implementadas

#### Sincronización Incremental Inteligente
- **Verificación previa**: Hace una consulta pequeña para verificar si hay cambios
- **Comparación local**: Compara registros existentes con los del servidor
- **Procesamiento selectivo**: Solo procesa registros nuevos o modificados
- **Logs detallados**: Muestra cuántos registros son nuevos vs actualizados

#### Mejoras de Rendimiento
- **Menos descargas**: Solo descarga cuando realmente hay cambios
- **Procesamiento eficiente**: Evita actualizar registros sin cambios
- **Logs informativos**: Muestra estadísticas de registros procesados
- **Límites de seguridad**: Evita bucles infinitos en la descarga

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
- 🌾 **Soporte para datos por temporada** con los últimos 50 registros
- 📅 **Ordenamiento automático** por fecha/timestamp
- 🎯 **Métodos especializados** para manejo de temporadas
- ⚡ **Sincronización inteligente** que verifica si es necesario sincronizar
- 🚀 **Múltiples métodos de sincronización** para diferentes casos de uso
- 🧠 **Sincronización ultra-inteligente** con verificación previa de cambios
- 🎯 **Sincronización incremental optimizada** que solo procesa registros nuevos/modificados
- 📈 **Logs detallados** con estadísticas de sincronización

### 🔧 Mejoras
- **Performance optimizada** en procesamiento de respuestas
- **Logs más informativos** para debugging
- **Documentación completa** con ejemplos reales
- **Mejor soporte** para APIs REST estándar
- **Sincronización incremental inteligente** que evita descargas innecesarias
- **Comparación local eficiente** para detectar cambios
- **Procesamiento selectivo** de registros
- **Límites de seguridad** para evitar bucles infinitos

### 🐛 Correcciones
- Arreglado procesamiento de respuestas anidadas
- Mejorado manejo de errores de red
- Corregida sincronización automática
- Optimizada sincronización incremental para evitar descargas masivas
- Corregido procesamiento de registros duplicados

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