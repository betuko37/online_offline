# 📱 Offline-First Súper Simple

Una librería Flutter para manejar datos offline-first. **La API más simple posible.**

## 🚀 API Súper Simple

| Método | Descripción |
|--------|-------------|
| `get()` | Retorna datos locales (siempre rápido) |
| `save()` | Guarda datos localmente |
| `delete()` | Elimina datos |
| `syncAll()` | Sincroniza todos los managers con el servidor |

## 📦 Instalación

```yaml
dependencies:
  betuko_offline_sync: ^3.1.0
```

## 🔧 Uso Básico (3 pasos)

### 1. Configurar API (una sola vez)

```dart
GlobalConfig.init(
  baseUrl: 'https://tu-api.com',
  token: 'tu-token',
);
```

### 2. Crear Manager

```dart
final reportes = OnlineOfflineManager(
  boxName: 'reportes',
  endpoint: '/api/reportes',
);
```

### 3. Usar Datos

```dart
// Obtener datos (SIEMPRE locales - súper rápido)
final datos = await reportes.get();

// Guardar datos
await reportes.save({
  'titulo': 'Mi Reporte',
  'descripcion': 'Descripción',
});

// Sincronizar cuando el usuario quiera (opcional - también es automático)
await OnlineOfflineManager.syncAll();
```

**¡Eso es todo!**

## ⚡ Sincronización Automática

La librería sincroniza automáticamente en dos situaciones:

### 1. Sincronización Periódica (Cada 10 minutos)
Cuando tu app está online, se ejecuta `syncAll()` automáticamente cada 10 minutos para mantener los datos actualizados.

### 2. Sincronización al Reconectar
Cuando la app detecta que se recuperó la conexión a internet (de offline a online), ejecuta `syncAll()` automáticamente para sincronizar cualquier dato pendiente.

**¡No necesitas configurar nada!** Esto funciona automáticamente una vez que creas tu primer `OnlineOfflineManager`.

```dart
// Solo crea managers - el auto-sync comienza automáticamente
final reportes = OnlineOfflineManager(
  boxName: 'reportes',
  endpoint: '/api/reportes',
);

// El auto-sync:
// - Se ejecuta cada 10 minutos cuando hay internet
// - Se ejecuta inmediatamente cuando se recupera la conexión
```

Puedes seguir llamando `syncAll()` manualmente cuando quieras forzar una sincronización.

## 💡 Filosofía

La librería sigue un principio simple:

- **`get()`** → Siempre retorna datos locales (instantáneo)
- **`syncAll()`** → El usuario decide cuándo actualizar
- **Auto-sync** → Sincronización automática cada 10 minutos y al reconectar

Esto significa que:
1. Tu app SIEMPRE es rápida (datos locales)
2. El usuario controla cuándo sincronizar (manual)
3. La sincronización también es automática (cada 10 min y al reconectar)
4. Funciona offline perfectamente

## 📱 Ejemplo Completo

```dart
import 'package:flutter/material.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() {
  // Configurar una vez al inicio
  GlobalConfig.init(
    baseUrl: 'https://tu-api.com',
    token: 'tu-token',
  );
  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final reportes = OnlineOfflineManager(
    boxName: 'reportes',
    endpoint: '/api/reportes',
  );
  
  List<Map<String, dynamic>> datos = [];
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Siempre retorna datos locales (instantáneo)
    final data = await reportes.get();
    setState(() => datos = data);
  }

  Future<void> _syncData() async {
    setState(() => isSyncing = true);
    
    // Sincronizar con el servidor
    await OnlineOfflineManager.syncAll();
    
    // Recargar datos locales
    await _loadData();
    
    setState(() => isSyncing = false);
  }

  Future<void> _addData() async {
    await reportes.save({
      'titulo': 'Nuevo Reporte',
      'descripcion': 'Descripción del reporte',
      'fecha': DateTime.now().toIso8601String(),
    });
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mi App'),
        actions: [
          // Botón de sincronización
          IconButton(
            icon: isSyncing 
              ? CircularProgressIndicator(color: Colors.white)
              : Icon(Icons.sync),
            onPressed: isSyncing ? null : _syncData,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: datos.length,
        itemBuilder: (context, index) {
          final item = datos[index];
          final isSynced = item['sync'] == 'true';
          
          return ListTile(
            title: Text(item['titulo'] ?? 'Sin título'),
            trailing: Icon(
              isSynced ? Icons.cloud_done : Icons.cloud_off,
              color: isSynced ? Colors.green : Colors.orange,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addData,
        child: Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    reportes.dispose();
    super.dispose();
  }
}
```

## 🔄 Múltiples Managers

Puedes tener varios managers y sincronizarlos todos a la vez:

```dart
// Crear managers
final reportes = OnlineOfflineManager(
  boxName: 'reportes', 
  endpoint: '/api/reportes',
);

final usuarios = OnlineOfflineManager(
  boxName: 'usuarios', 
  endpoint: '/api/usuarios',
);

final productos = OnlineOfflineManager(
  boxName: 'productos', 
  endpoint: '/api/productos',
);

// Obtener datos de cada uno (siempre locales)
final misReportes = await reportes.get();
final misUsuarios = await usuarios.get();
final misProductos = await productos.get();

// Sincronizar TODOS con un solo comando
final results = await OnlineOfflineManager.syncAll();

// Ver resultados
for (final entry in results.entries) {
  if (entry.value.success) {
    print('✅ ${entry.key}: sincronizado');
  } else {
    print('❌ ${entry.key}: ${entry.value.error}');
  }
}
```

## 📊 Métodos Disponibles

### OnlineOfflineManager (instancia)

| Método | Descripción |
|--------|-------------|
| `get()` | Todos los datos |
| `getSynced()` | Solo datos sincronizados (List) |
| `getPending()` | Solo datos pendientes (List) |
| `getFullData()` | TODO: datos + contadores (FullSyncData) |
| `getSyncInfo()` | Solo contadores (SyncInfo) |
| `save(Map data)` | Guardar |
| `delete(String id)` | Eliminar |
| `clear()` | Limpiar datos |
| `reset()` | Reset completo |
| `dispose()` | Liberar recursos |

### OnlineOfflineManager (estático)

| Método | Descripción |
|--------|-------------|
| `syncAll()` | Sincroniza todos los managers activos |
| `getAllSyncInfo()` | Estado de sync de todos los managers |
| `resetAll()` | Resetea TODO (managers, boxes, caché) |
| `getAllBoxesInfo()` | Info de todas las boxes Hive |
| `debugInfo()` | Imprime info de debug en consola |
| `getTotalRecordCount()` | Total de registros en todos los managers |
| `getTotalPendingCount()` | Total de registros pendientes |
| `deleteAllBoxes()` | Elimina todas las boxes del disco |

### GlobalConfig

| Método | Descripción |
|--------|-------------|
| `init(baseUrl, token)` | Configura la API |
| `updateToken(token)` | Actualiza solo el token |
| `clear()` | Limpia la configuración |

## 📊 Ver Estado de Sincronización

### Obtener datos separados
```dart
// Obtener solo datos sincronizados (con todos sus campos)
final sincronizados = await reportes.getSynced();
for (final item in sincronizados) {
  print('Sync: ${item['titulo']} - ID: ${item['id']}');
}

// Obtener solo datos pendientes (con todos sus campos)
final pendientes = await reportes.getPending();
for (final item in pendientes) {
  print('Pendiente: ${item['titulo']}');
}
```

### Obtener TODO junto (datos + contadores)
```dart
final data = await reportes.getFullData();

// Contadores
print('Total: ${data.total}');
print('Sincronizados: ${data.syncedCount}');
print('Pendientes: ${data.pendingCount}');
print('Porcentaje: ${data.syncPercentage}%');
print('¿Todo sync?: ${data.isFullySynced}');

// Ver datos sincronizados
print('--- SINCRONIZADOS ---');
for (final item in data.synced) {
  print('  ${item['titulo']}');
}

// Ver datos pendientes
print('--- PENDIENTES ---');
for (final item in data.pending) {
  print('  ${item['titulo']}');
}
```

### Solo contadores (más ligero)
```dart
final info = await reportes.getSyncInfo();
print('Total: ${info.total}');
print('Sincronizados: ${info.synced}');
print('Pendientes: ${info.pending}');
```

### De todos los managers
```dart
final estados = await OnlineOfflineManager.getAllSyncInfo();

for (final entry in estados.entries) {
  final nombre = entry.key;
  final info = entry.value;
  print('$nombre: ${info.synced}/${info.total} (${info.pending} pendientes)');
}

// Ejemplo de salida:
// reportes: 147/150 (3 pendientes)
// usuarios: 50/50 (0 pendientes)
// productos: 200/200 (0 pendientes)
```

### Contadores globales rápidos
```dart
final totalRegistros = await OnlineOfflineManager.getTotalRecordCount();
final totalPendientes = await OnlineOfflineManager.getTotalPendingCount();
print('Total: $totalRegistros, Pendientes: $totalPendientes');
```

## 🔧 Debug y Reset

### Ver información de debug
```dart
// Imprime info completa en consola
await OnlineOfflineManager.debugInfo();

// Salida:
// ═══════════════════════════════════════════════════════════
// 📊 DEBUG INFO - OnlineOfflineManager
// ═══════════════════════════════════════════════════════════
// 📦 Managers activos: 2
//    • reportes: 150 registros (3 pendientes)
//    • usuarios: 50 registros (0 pendientes)
// 💾 Boxes Hive:
//    • reportes: 150 registros (abierta)
//    • usuarios: 50 registros (abierta)
// ⚙️ GlobalConfig:
//    • Inicializado: true
//    • BaseURL: https://api.com
// ═══════════════════════════════════════════════════════════
```

### Obtener info de boxes
```dart
final boxes = await OnlineOfflineManager.getAllBoxesInfo();
for (final box in boxes) {
  print('${box.name}: ${box.recordCount} registros');
}
```

### Contadores globales
```dart
final total = await OnlineOfflineManager.getTotalRecordCount();
final pendientes = await OnlineOfflineManager.getTotalPendingCount();
print('Total: $total, Pendientes: $pendientes');
```

### Reset global (limpia TODO)
```dart
// ⚠️ Cuidado: elimina todos los datos locales
await OnlineOfflineManager.resetAll();
```

## 🎯 Ventajas

- ✅ **Súper simple**: Solo 4 métodos principales
- ✅ **Siempre rápido**: `get()` retorna datos locales
- ✅ **Control total**: El usuario decide cuándo sincronizar
- ✅ **Funciona offline**: Los datos siempre están disponibles
- ✅ **Automático**: Sincronización y manejo de errores incluidos

## 🔧 Streams (Opcional)

Si prefieres usar streams para reactividad:

```dart
// Escuchar cambios en los datos
reportes.dataStream.listen((datos) {
  setState(() => misDatos = datos);
});

// Escuchar estado de sincronización
reportes.statusStream.listen((status) {
  print('Estado: $status');
});

// Escuchar conectividad
reportes.connectivityStream.listen((isOnline) {
  print('Online: $isOnline');
});
```

## 🎉 ¡Listo!

Con solo:
- `GlobalConfig.init()` - Configurar una vez
- `get()` - Obtener datos
- `save()` - Guardar datos  
- `syncAll()` - Sincronizar

**¡Tu app offline-first está lista!** 🚀
