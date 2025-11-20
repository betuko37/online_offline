# 📚 Guía Completa - Betuko Offline Sync

Guía completa paso a paso para usar la librería **betuko_offline_sync** desde cero hasta casos avanzados.

---

## 📋 Tabla de Contenidos

1. [Instalación](#instalación)
2. [Configuración Inicial](#configuración-inicial)
3. [Crear Managers](#crear-managers)
4. [Uso Básico](#uso-básico)
5. [Sincronización](#sincronización)
6. [Reset y Limpieza](#reset-y-limpieza)
7. [Métodos Disponibles](#métodos-disponibles)
8. [Streams Reactivos](#streams-reactivos)
9. [Ejemplos Prácticos](#ejemplos-prácticos)
10. [Mejores Prácticas](#mejores-prácticas)

---

## 📦 Instalación

### Paso 1: Agregar dependencia

Agrega la librería a tu `pubspec.yaml`:

```yaml
dependencies:
  betuko_offline_sync: ^2.2.0
```

### Paso 2: Instalar

```bash
flutter pub get
```

### Paso 3: Importar

```dart
import 'package:betuko_offline_sync/betuko_offline_sync.dart';
```

---

## ⚙️ Configuración Inicial

### Paso 1: Configurar en main.dart

**IMPORTANTE**: La configuración debe hacerse **ANTES** de `runApp()`:

```dart
import 'package:flutter/material.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() async {
  // 1. SIEMPRE inicializar Flutter binding primero
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializar Hive (opcional, se hace automáticamente)
  // await Hive.initFlutter();
  
  // 3. Configurar betuko_offline_sync
  GlobalConfig.init(
    baseUrl: 'https://tu-api.com/api',  // URL base de tu API
    token: 'tu-token-de-autenticacion',  // Token de autenticación
  );
  
  // 4. Ahora sí, ejecutar la app
  runApp(MyApp());
}
```

### Paso 2: Configuración Avanzada (Opcional)

Para aplicaciones que necesitan optimización, puedes configurar parámetros adicionales:

```dart
GlobalConfig.init(
  baseUrl: 'https://tu-api.com/api',
  token: 'tu-token',
  
  // Configuración de sincronización
  syncMinutes: 15,                    // Sincronizar cada 15 minutos
  useIncrementalSync: true,           // Solo descargar cambios (más eficiente)
  syncOnReconnect: true,              // Sincronizar al reconectar
  pageSize: 50,                       // 50 registros por página
  maxPagesPerSync: 5,                 // Máximo 5 páginas por sincronización
  syncTimeoutMinutes: 30,             // Timeout de 30 minutos
  lastModifiedField: 'lastModifiedAt', // Campo de timestamp
  maxLocalRecords: 1000,              // Máximo 1000 registros locales
  maxDaysToKeep: 7,                   // Mantener registros por 7 días
);
```

#### Parámetros de Configuración

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `baseUrl` | `String` | **Requerido** | URL base de tu API |
| `token` | `String` | **Requerido** | Token de autenticación |
| `syncMinutes` | `int` | `5` | Minutos entre sincronizaciones automáticas |
| `useIncrementalSync` | `bool` | `true` | Usar sincronización incremental (solo cambios) |
| `syncOnReconnect` | `bool` | `true` | Sincronizar automáticamente al reconectar |
| `pageSize` | `int` | `25` | Registros por página en paginación |
| `maxPagesPerSync` | `int` | `10` | Máximo de páginas por sincronización |
| `syncTimeoutMinutes` | `int` | `30` | Minutos para usar descarga completa |
| `lastModifiedField` | `String` | `'lastModifiedAt'` | Campo de timestamp para sincronización |
| `maxLocalRecords` | `int` | `1000` | Máximo de registros locales (con limpieza) |
| `maxDaysToKeep` | `int` | `7` | Días para mantener registros sincronizados |

---

## 🏗️ Crear Managers

### ¿Qué es un Manager?

Un **Manager** es una instancia de `OnlineOfflineManager` que gestiona los datos de un tipo específico (usuarios, productos, reportes, etc.). Cada manager tiene su propia "caja" (box) de almacenamiento.

### Crear un Manager Básico

```dart
// En un archivo de servicio o provider
class UserService {
  // Se inicializa automáticamente - no necesitas llamar init()
  static final manager = OnlineOfflineManager(
    boxName: 'users',           // Nombre único de la caja
    endpoint: 'users',          // Endpoint de la API (opcional)
  );
}
```

### Crear un Manager con Limpieza Automática

```dart
class ReportService {
  static final manager = OnlineOfflineManager(
    boxName: 'reports',
    endpoint: 'reports',
    enableAutoCleanup: true,  // Limpia registros antiguos automáticamente
  );
}
```

### Parámetros del Manager

| Parámetro | Tipo | Requerido | Descripción |
|-----------|------|-----------|-------------|
| `boxName` | `String` | **Sí** | Nombre único de la caja de almacenamiento |
| `endpoint` | `String?` | No | Endpoint de la API para sincronización |
| `enableAutoCleanup` | `bool` | No | Limpiar registros antiguos automáticamente (default: `false`) |

### Ejemplo: Múltiples Managers

```dart
// Servicio de usuarios
class UserService {
  static final manager = OnlineOfflineManager(
    boxName: 'users',
    endpoint: 'users',
  );
}

// Servicio de productos
class ProductService {
  static final manager = OnlineOfflineManager(
    boxName: 'products',
    endpoint: 'products',
  );
}

// Servicio de reportes (con limpieza automática)
class ReportService {
  static final manager = OnlineOfflineManager(
    boxName: 'reports',
    endpoint: 'reports',
    enableAutoCleanup: true,
  );
}
```

---

## 📖 Uso Básico

### Obtener Todos los Datos

El método `getAll()` obtiene todos los datos y sincroniza automáticamente si hay conexión:

```dart
// Obtener todos los usuarios
final usuarios = await UserService.manager.getAll();

// Los datos vienen como List<Map<String, dynamic>>
for (final usuario in usuarios) {
  print('Usuario: ${usuario['name']}');
  print('Email: ${usuario['email']}');
}
```

### Guardar Datos

```dart
// Guardar un nuevo usuario
await UserService.manager.save({
  'name': 'Juan Pérez',
  'email': 'juan@example.com',
  'age': 30,
});

// El dato se guarda localmente y se sincroniza automáticamente cuando hay conexión
```

### Eliminar Datos

```dart
// Eliminar por ID
await UserService.manager.delete('user_123');
```

### Obtener Datos Específicos

```dart
// Solo datos sincronizados (del servidor)
final sincronizados = await UserService.manager.getSync();

// Solo datos locales (pendientes de sincronizar)
final pendientes = await UserService.manager.getLocal();

// Solo datos pendientes (alias de getLocal)
final pendientes2 = await UserService.manager.getPending();

// Solo datos sincronizados (alias de getSync)
final sincronizados2 = await UserService.manager.getSynced();
```

---

## 🔄 Sincronización

### Sincronización Automática

La sincronización automática está **habilitada por defecto**. Se ejecuta:

- ✅ Cada X minutos (configurado en `syncMinutes`)
- ✅ Al reconectar a internet (si `syncOnReconnect: true`)
- ✅ Al llamar `getAll()` si hay conexión

**No necesitas hacer nada** - funciona automáticamente.

### Sincronización Manual

Si necesitas forzar una sincronización:

```dart
// Sincronización inteligente (respeta el caché)
await UserService.manager.sync();

// Sincronización forzada (ignora caché)
await UserService.manager.forceSync();

// Sincronización inmediata (bypasa todas las verificaciones)
await UserService.manager.syncNow();
```

### Diferencia entre Métodos de Sincronización

| Método | Descripción | Cuándo Usar |
|--------|-------------|-------------|
| `sync()` | Sincronización inteligente que respeta el caché | Uso normal, respeta tiempos de sincronización |
| `forceSync()` | Fuerza sincronización ignorando caché | Cuando necesitas datos frescos |
| `syncNow()` | Sincronización inmediata sin verificaciones | Cuando necesitas sincronizar urgentemente |

### Obtener Datos del Servidor Directamente

```dart
// Obtener datos directamente del servidor (requiere conexión)
final datosFrescos = await UserService.manager.getFromServer();

// Obtener datos con sincronización automática
final datosActualizados = await UserService.manager.getAllWithSync();
```

---

## 🗑️ Reset y Limpieza

### Resetear un Manager Específico

```dart
// Resetear un manager (limpia datos locales y caché)
await UserService.manager.reset();
```

El método `reset()` hace:
- ✅ Limpia todos los datos locales
- ✅ Limpia el caché de sincronización
- ✅ Resetea el estado de sincronización

### Limpiar Solo Datos Locales

```dart
// Limpiar solo los datos (sin resetear caché)
await UserService.manager.clear();
```

### Limpiar Duplicados

```dart
// Limpiar registros duplicados
await UserService.manager.cleanDuplicates();
```

### Resetear TODAS las Boxes

Para resetear todas las boxes de tu aplicación (detecta automáticamente todas):

```dart
// Resetea automáticamente todas las boxes detectadas
// No necesitas proporcionar los nombres manualmente
await OnlineOfflineManager.resetAllBoxes(
  includeCacheBox: true,  // También limpia _cache_metadata
);
```

### Ver Boxes Abiertas

```dart
// Ver información de todas las boxes (detecta automáticamente)
// No necesitas proporcionar los nombres
final boxesInfo = await OnlineOfflineManager.getAllOpenBoxesInfo();

for (final box in boxesInfo) {
  print('📦 Box: ${box.name}');
  print('   Abierta: ${box.isOpen ? "✅ Sí" : "❌ No"}');
  print('   Registros: ${box.recordCount}');
  if (box.existsOnDisk != null) {
    print('   En disco: ${box.existsOnDisk! ? "✅ Sí" : "❌ No"}');
  }
}
```

### Eliminar Boxes del Disco

```dart
// Elimina automáticamente todas las boxes detectadas
// No necesitas proporcionar los nombres
await OnlineOfflineManager.deleteAllBoxes(
  includeCacheBox: true,
);
```

---

## 📚 Métodos Disponibles

### Métodos de Lectura

| Método | Retorna | Descripción |
|--------|---------|-------------|
| `getAll()` | `List<Map>` | Todos los datos (con sincronización automática) |
| `getSync()` | `List<Map>` | Solo datos sincronizados |
| `getLocal()` | `List<Map>` | Solo datos locales (pendientes) |
| `getPending()` | `List<Map>` | Alias de `getLocal()` |
| `getSynced()` | `List<Map>` | Alias de `getSync()` |
| `getFromServer()` | `List<Map>` | Datos directamente del servidor |
| `getAllWithSync()` | `List<Map>` | Datos con sincronización automática |

### Métodos de Escritura

| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `save(data)` | `Map<String, dynamic>` | Guardar un registro |
| `delete(id)` | `String` | Eliminar un registro por ID |

### Métodos de Sincronización

| Método | Descripción |
|--------|-------------|
| `sync()` | Sincronización inteligente |
| `forceSync()` | Sincronización forzada |
| `syncNow()` | Sincronización inmediata |

### Métodos de Limpieza

| Método | Descripción |
|--------|-------------|
| `clear()` | Limpiar todos los datos locales |
| `reset()` | Resetear completamente (datos + caché) |
| `cleanDuplicates()` | Limpiar registros duplicados |

### Métodos Estáticos (Gestión Global)

| Método | Descripción |
|--------|-------------|
| `getAllOpenBoxesInfo()` | Ver información de boxes abiertas (detecta automáticamente) |
| `resetAllBoxes()` | Resetear todas las boxes (detecta automáticamente) |
| `deleteAllBoxes()` | Eliminar todas las boxes del disco (detecta automáticamente) |

### Getters

| Getter | Tipo | Descripción |
|--------|------|-------------|
| `dataStream` | `Stream<List<Map>>` | Stream de datos |
| `statusStream` | `Stream<SyncStatus>` | Stream de estado de sincronización |
| `connectivityStream` | `Stream<bool>` | Stream de conectividad |
| `status` | `SyncStatus` | Estado actual de sincronización |
| `isOnline` | `bool` | Si hay conexión a internet |
| `boxName` | `String` | Nombre de la caja |

---

## 📡 Streams Reactivos

### Stream de Datos

Escuchar cambios en los datos en tiempo real:

```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    
    // Escuchar cambios en los datos
    UserService.manager.dataStream.listen((usuarios) {
      setState(() {
        // Actualizar UI cuando cambien los datos
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: UserService.manager.dataStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }
        
        final usuarios = snapshot.data!;
        return ListView.builder(
          itemCount: usuarios.length,
          itemBuilder: (context, index) {
            final usuario = usuarios[index];
            return ListTile(
              title: Text(usuario['name'] ?? 'Sin nombre'),
              subtitle: Text(usuario['email'] ?? ''),
            );
          },
        );
      },
    );
  }
}
```

### Stream de Estado de Sincronización

```dart
StreamBuilder<SyncStatus>(
  stream: UserService.manager.statusStream,
  builder: (context, snapshot) {
    final status = snapshot.data ?? SyncStatus.idle;
    
    switch (status) {
      case SyncStatus.idle:
        return Icon(Icons.check_circle, color: Colors.grey);
      case SyncStatus.syncing:
        return CircularProgressIndicator();
      case SyncStatus.success:
        return Icon(Icons.check_circle, color: Colors.green);
      case SyncStatus.error:
        return Icon(Icons.error, color: Colors.red);
    }
  },
)
```

### Stream de Conectividad

```dart
StreamBuilder<bool>(
  stream: UserService.manager.connectivityStream,
  builder: (context, snapshot) {
    final isOnline = snapshot.data ?? false;
    
    return Chip(
      label: Text(isOnline ? 'Online' : 'Offline'),
      backgroundColor: isOnline ? Colors.green : Colors.red,
    );
  },
)
```

---

## 💡 Ejemplos Prácticos

### Ejemplo 1: Servicio de Usuarios

```dart
class UserService {
  static final manager = OnlineOfflineManager(
    boxName: 'users',
    endpoint: 'users',
  );

  /// Obtener todos los usuarios
  static Future<List<User>> getAllUsers() async {
    final data = await manager.getAll();
    return data.map((json) => User.fromJson(json)).toList();
  }

  /// Guardar un usuario
  static Future<void> saveUser(User user) async {
    await manager.save(user.toJson());
  }

  /// Eliminar un usuario
  static Future<void> deleteUser(String userId) async {
    await manager.delete(userId);
  }

  /// Sincronizar manualmente
  static Future<void> syncUsers() async {
    await manager.forceSync();
  }
}
```

### Ejemplo 2: Servicio de Reportes con Limpieza Automática

```dart
class ReportService {
  static final manager = OnlineOfflineManager(
    boxName: 'reports',
    endpoint: 'reports',
    enableAutoCleanup: true,  // Limpia automáticamente
  );

  /// Obtener reportes
  static Future<List<Report>> getReports() async {
    final data = await manager.getAll();
    return data.map((json) => Report.fromJson(json)).toList();
  }

  /// Obtener solo reportes sincronizados
  static Future<List<Report>> getSyncedReports() async {
    final data = await manager.getSync();
    return data.map((json) => Report.fromJson(json)).toList();
  }

  /// Obtener reportes pendientes
  static Future<List<Report>> getPendingReports() async {
    final data = await manager.getPending();
    return data.map((json) => Report.fromJson(json)).toList();
  }
}
```

### Ejemplo 3: UI con Streams

```dart
class UsersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Usuarios'),
        actions: [
          // Indicador de estado de sincronización
          StreamBuilder<SyncStatus>(
            stream: UserService.manager.statusStream,
            builder: (context, snapshot) {
              final status = snapshot.data ?? SyncStatus.idle;
              if (status == SyncStatus.syncing) {
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
          // Indicador de conectividad
          StreamBuilder<bool>(
            stream: UserService.manager.connectivityStream,
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? false;
              return Icon(
                isOnline ? Icons.cloud : Icons.cloud_off,
                color: isOnline ? Colors.green : Colors.red,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: UserService.manager.dataStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final usuarios = snapshot.data!;
          
          if (usuarios.isEmpty) {
            return Center(child: Text('No hay usuarios'));
          }

          return RefreshIndicator(
            onRefresh: () => UserService.manager.forceSync(),
            child: ListView.builder(
              itemCount: usuarios.length,
              itemBuilder: (context, index) {
                final usuario = usuarios[index];
                final isSynced = usuario['sync'] == 'true';
                
                return ListTile(
                  title: Text(usuario['name'] ?? 'Sin nombre'),
                  subtitle: Text(usuario['email'] ?? ''),
                  trailing: Icon(
                    isSynced ? Icons.cloud_done : Icons.cloud_upload,
                    color: isSynced ? Colors.green : Colors.orange,
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await UserService.manager.save({
            'name': 'Nuevo Usuario',
            'email': 'nuevo@example.com',
          });
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
```

### Ejemplo 4: Reset Completo de la Aplicación

```dart
class ResetService {
  /// Resetear toda la aplicación
  /// Detecta automáticamente todas las boxes
  static Future<void> resetApp() async {
    try {
      // Resetea automáticamente todas las boxes detectadas
      // No necesitas proporcionar los nombres manualmente
      await OnlineOfflineManager.resetAllBoxes(
        includeCacheBox: true,  // Limpiar también caché
      );

      print('✅ Reset completado');
    } catch (e) {
      print('❌ Error al resetear: $e');
      rethrow;
    }
  }
  
  /// Ver todas las boxes antes de resetear
  static Future<void> showAllBoxes() async {
    // Detecta automáticamente todas las boxes
    final boxesInfo = await OnlineOfflineManager.getAllOpenBoxesInfo();
    
    print('📦 Boxes detectadas: ${boxesInfo.length}');
    for (final box in boxesInfo) {
      print('  - ${box.name}: ${box.isOpen ? "Abierta" : "Cerrada"} (${box.recordCount} registros)');
    }
  }
}
```

### Ejemplo 5: Configuración Optimizada para App de Asistencias/Nómina

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración optimizada para app de asistencias/nómina
  GlobalConfig.init(
    baseUrl: 'https://tu-api.com/api',
    token: 'tu-token',
    
    // Configuración optimizada
    syncMinutes: 15,                    // Sincronizar cada 15 minutos
    useIncrementalSync: true,           // Solo descargar cambios
    syncOnReconnect: true,              // Sincronizar al reconectar
    pageSize: 50,                       // 50 registros por página
    maxPagesPerSync: 5,                 // Máximo 5 páginas
    syncTimeoutMinutes: 30,             // Timeout de 30 minutos
    lastModifiedField: 'lastModifiedAt', // Campo de timestamp
    maxLocalRecords: 1000,              // Máximo 1000 registros
    maxDaysToKeep: 7,                   // Mantener por 7 días
  );

  runApp(MyApp());
}
```

---

## 🎯 Mejores Prácticas

### 1. Configuración Global

✅ **Hazlo en main.dart antes de runApp()**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GlobalConfig.init(...);  // ✅ Correcto
  runApp(MyApp());
}
```

❌ **No lo hagas después de runApp()**
```dart
void main() {
  runApp(MyApp());
  GlobalConfig.init(...);  // ❌ Incorrecto
}
```

### 2. Crear Managers como Estáticos

✅ **Usa managers estáticos en servicios**
```dart
class UserService {
  static final manager = OnlineOfflineManager(...);  // ✅ Correcto
}
```

❌ **No crees managers en cada widget**
```dart
class MyWidget extends StatelessWidget {
  final manager = OnlineOfflineManager(...);  // ❌ Incorrecto
}
```

### 3. Usar Streams para UI Reactiva

✅ **Usa StreamBuilder para UI reactiva**
```dart
StreamBuilder<List<Map<String, dynamic>>>(
  stream: manager.dataStream,
  builder: (context, snapshot) {
    // UI que se actualiza automáticamente
  },
)
```

### 4. Manejo de Errores

✅ **Siempre maneja errores**
```dart
try {
  final data = await manager.getAll();
} catch (e) {
  // Manejar error
  print('Error: $e');
}
```

### 5. Reset Completo

✅ **Resetea todas las boxes al cambiar de usuario**
```dart
Future<void> logout() async {
  // Resetear todas las boxes
  await OnlineOfflineManager.resetAllBoxes(
    boxNames: ['users', 'products', 'reports'],
    includeCacheBox: true,
  );
  
  // Luego hacer logout
  // ...
}
```

### 6. Limpieza de Recursos

✅ **Dispose de managers cuando no se necesiten**
```dart
@override
void dispose() {
  manager.dispose();  // Limpiar recursos
  super.dispose();
}
```

---

## 🔍 Troubleshooting

### Problema: Los datos no se sincronizan

**Solución:**
1. Verifica que `GlobalConfig.init()` se haya llamado
2. Verifica que el `endpoint` esté configurado en el manager
3. Verifica la conectividad con `manager.isOnline`
4. Intenta una sincronización manual: `await manager.forceSync()`

### Problema: Los datos no se guardan

**Solución:**
1. Verifica que el manager esté inicializado
2. Verifica que el formato de datos sea correcto (`Map<String, dynamic>`)
3. Revisa los logs en consola

### Problema: Reset no limpia todas las boxes

**Solución:**
1. Los métodos ahora detectan automáticamente todas las boxes - no necesitas proporcionar nombres
2. Usa `includeCacheBox: true` para limpiar también el caché
3. Verifica las boxes con `getAllOpenBoxesInfo()` antes de resetear si quieres ver qué se va a limpiar

### Problema: Sincronización muy lenta

**Solución:**
1. Ajusta `pageSize` para más registros por página
2. Ajusta `maxPagesPerSync` para limitar páginas
3. Usa `useIncrementalSync: true` para solo descargar cambios

---

## 📝 Resumen Rápido

### Setup Mínimo (3 pasos)

```dart
// 1. Configurar en main.dart
GlobalConfig.init(
  baseUrl: 'https://tu-api.com/api',
  token: 'tu-token',
);

// 2. Crear manager
final manager = OnlineOfflineManager(
  boxName: 'datos',
  endpoint: 'datos',
);

// 3. Usar
final datos = await manager.getAll();
```

### Comandos Más Usados

```dart
// Obtener datos
await manager.getAll();

// Guardar
await manager.save({'key': 'value'});

// Eliminar
await manager.delete('id');

// Sincronizar
await manager.forceSync();

// Resetear
await manager.reset();
```

---

## 🎉 ¡Listo!

Ahora tienes todo lo necesario para usar **betuko_offline_sync** en tu aplicación. 

¿Tienes dudas? Revisa los ejemplos o consulta la documentación completa en el README.md principal.

**¡Feliz desarrollo! 🚀**

