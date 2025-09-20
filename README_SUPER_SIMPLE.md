# 📱 Offline-First Súper Simple

Una librería Flutter para manejar datos offline-first con sincronización automática inteligente. **Solo necesitas 3 métodos: `getAll()`, `getSync()`, `getLocal()`**

## 🚀 Uso Súper Simple

### 1. Configuración (solo una vez)
```dart
// Configurar tu API con configuración de sincronización
GlobalConfig.init(
  baseUrl: 'https://tu-api.com',
  token: 'tu-token',
  syncMinutes: 5, // Sincronizar cada 5 minutos
  useIncrementalSync: true, // Usar sincronización incremental
  pageSize: 25, // 25 registros por página
  lastModifiedField: 'updated_at', // Campo de timestamp
);
```

### 2. Crear Manager
```dart
final manager = OnlineOfflineManager(
  boxName: 'reports',
  endpoint: 'api/reports',
);
```

### 3. Usar Datos (¡ESTO ES TODO!)
```dart
// ¡SÚPER SIMPLE! Solo estos 3 métodos:

// Obtener todos los datos (con sincronización automática)
final allData = await manager.getAll();

// Obtener solo datos sincronizados (del servidor)
final syncData = await manager.getSync();

// Obtener solo datos locales (pendientes de sincronización)
final localData = await manager.getLocal();
```

**¡Eso es todo!** La librería automáticamente:
- ✅ Sincroniza datos pendientes hacia el servidor
- ✅ Descarga datos nuevos/modificados del servidor  
- ✅ Retorna todos los datos (locales + sincronizados)
- ✅ Funciona offline y online
- ✅ Optimizado para grandes volúmenes (2280+ registros)

## 📊 Configuración de Sincronización

### En GlobalConfig.init():
```dart
GlobalConfig.init(
  baseUrl: 'https://tu-api.com',
  token: 'tu-token',
  syncMinutes: 5, // ← Minutos entre sincronizaciones
  useIncrementalSync: true, // ← Sincronización incremental
  pageSize: 25, // ← Registros por página
  lastModifiedField: 'updated_at', // ← Campo de timestamp
);
```

### Configuraciones Recomendadas:

#### Para Grandes Volúmenes (Tu Caso - 2280+ registros)
```dart
GlobalConfig.init(
  baseUrl: 'https://tu-api.com',
  token: 'tu-token',
  syncMinutes: 5, // Sincronizar cada 5 minutos
  useIncrementalSync: true, // Sincronización incremental
  pageSize: 25, // 25 registros por página
  lastModifiedField: 'updated_at',
);
```

#### Para Datos Frecuentes
```dart
GlobalConfig.init(
  baseUrl: 'https://tu-api.com',
  token: 'tu-token',
  syncMinutes: 1, // Sincronizar cada 1 minuto
  useIncrementalSync: true,
  pageSize: 20, // 20 registros por página
  lastModifiedField: 'updated_at',
);
```

#### Para Datos Ocasionales
```dart
GlobalConfig.init(
  baseUrl: 'https://tu-api.com',
  token: 'tu-token',
  syncMinutes: 15, // Sincronizar cada 15 minutos
  useIncrementalSync: true,
  pageSize: 50, // 50 registros por página
  lastModifiedField: 'updated_at',
);
```

## 🔄 Cómo Funciona

### getAll() - Método Principal
1. **Sincroniza automáticamente** si hay conexión
2. **Descarga datos nuevos/modificados** del servidor
3. **Sube datos pendientes** al servidor
4. **Retorna todos los datos** (locales + sincronizados)

### getSync() - Solo Sincronizados
- Retorna solo datos que vienen del servidor
- Útil para mostrar datos "oficiales"

### getLocal() - Solo Locales
- Retorna solo datos pendientes de sincronización
- Útil para mostrar datos "pendientes"

## 💾 Operaciones Básicas

### Guardar Datos
```dart
await manager.save({
  'title': 'Mi Reporte',
  'description': 'Descripción',
  'status': 'active',
});
// Se sincroniza automáticamente con getAll()
```

### Eliminar Datos
```dart
await manager.delete('item_id');
// Se sincroniza automáticamente con getAll()
```

## 📱 Ejemplo Completo

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late OnlineOfflineManager _manager;
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _syncData = [];
  List<Map<String, dynamic>> _localData = [];

  @override
  void initState() {
    super.initState();
    _initializeManager();
  }

  void _initializeManager() async {
    // 1. Configurar API
    GlobalConfig.init(
      baseUrl: 'https://tu-api.com',
      token: 'tu-token',
      syncMinutes: 5,
      useIncrementalSync: true,
      pageSize: 25,
      lastModifiedField: 'updated_at',
    );

    // 2. Crear manager
    _manager = OnlineOfflineManager(
      boxName: 'reports',
      endpoint: 'api/reports',
    );

    // 3. Escuchar cambios
    _manager.dataStream.listen((data) {
      setState(() {
        _allData = data;
      });
    });

    // 4. ¡ESTO ES TODO! Solo estos 3 métodos
    final allData = await _manager.getAll();
    final syncData = await _manager.getSync();
    final localData = await _manager.getLocal();
    
    setState(() {
      _allData = allData;
      _syncData = syncData;
      _localData = localData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mi App')),
      body: Column(
        children: [
          Text('Total: ${_allData.length}'),
          Text('Sincronizados: ${_syncData.length}'),
          Text('Locales: ${_localData.length}'),
          Expanded(
            child: ListView.builder(
              itemCount: _allData.length,
              itemBuilder: (context, index) {
                final item = _allData[index];
                return ListTile(
                  title: Text(item['title'] ?? 'Sin título'),
                  trailing: item['sync'] == 'true'
                      ? Icon(Icons.cloud_done, color: Colors.green)
                      : Icon(Icons.cloud_off, color: Colors.orange),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

## 🎯 Beneficios

### Antes (Sincronización Completa)
- ❌ Descarga 2280 registros cada vez
- ❌ Lento y consume mucha banda
- ❌ API compleja con muchos métodos

### Después (Súper Simple)
- ✅ Solo 3 métodos: `getAll()`, `getSync()`, `getLocal()`
- ✅ Sincronización incremental (25 registros por página)
- ✅ Configuración en `GlobalConfig`
- ✅ Rápido y eficiente
- ✅ API súper simple

## 🔧 Configuración del Servidor

Tu servidor debe soportar estos parámetros:

```http
GET /api/reports?since=2024-01-01T00:00:00Z&limit=25&offset=0&last_modified_field=updated_at
```

### Respuesta Esperada
```json
{
  "data": [
    {
      "id": 1,
      "title": "Reporte 1",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  ]
}
```

## 📝 Logs Automáticos

La librería incluye logs informativos:

```
🔄 Sincronización automática iniciada...
📅 Sincronizando desde: 2024-01-01 00:00:00.000
📥 Descargando página 1...
🔄 Actualizado registro existente
➕ Agregado nuevo registro
✅ Sincronización automática completada
```

## 🎉 ¡Eso es Todo!

**Solo necesitas 3 métodos y la librería maneja todo automáticamente:**

- ✅ `getAll()` - Todos los datos con sincronización automática
- ✅ `getSync()` - Solo datos sincronizados
- ✅ `getLocal()` - Solo datos locales
- ✅ Configuración en `GlobalConfig`
- ✅ Sincronización incremental
- ✅ Optimización para grandes volúmenes

**¡Tu problema de 2280 registros está resuelto!** 🚀
