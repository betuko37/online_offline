# 🚀 Betuko Offline Sync v2.0.0 - Release Summary

## ✨ **¿Qué es nuevo en v2.0.0?**

### 🌐 **Detección Automática de APIs**
- **Smart Detection**: Reconoce automáticamente respuestas anidadas como `{data: [...], total: N}`
- **Auto-Extraction**: Extrae el array `data` sin configuración adicional
- **Universal Support**: Funciona con APIs simples y complejas

### 🚀 **Nuevos Métodos Poderosos**

#### `getFromServer()` - Datos Frescos 🌊
```dart
// Obtiene datos directamente del servidor
final datosFrescos = await manager.getFromServer();
```

#### `getAllWithSync()` - Sincronización Inteligente 🧠
```dart
// Sincroniza automáticamente y retorna datos actualizados
final datosActualizados = await manager.getAllWithSync();
```

## 📦 **Instalación Rápida**

### 1. Agregar a pubspec.yaml
```yaml
dependencies:
  betuko_offline_sync: ^2.0.0
```

### 2. Configurar en main.dart
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  GlobalConfig.init(
    baseUrl: 'https://tu-api.com/api',
    token: 'tu-token',
  );
  
  runApp(MyApp());
}
```

### 3. ¡Usar en cualquier lugar!
```dart
// Auto-inicializado, sin configuración
final manager = OnlineOfflineManager(
  boxName: 'datos',
  endpoint: 'items',
);

// Una línea para datos sincronizados
final datos = await manager.getAllWithSync();
```

## 🎯 **Casos de Uso Perfectos**

### ✅ **Apps Offline-First**
- Formularios que se envían cuando hay conexión
- Listas que funcionan sin internet
- Sincronización automática en background

### ✅ **APIs Complejas**
- Respuestas anidadas: `{data: [...], total: 100, page: 1}`
- Respuestas simples: `[{...}, {...}]`
- APIs REST estándar

### ✅ **UI Reactiva**
- Streams para actualización automática
- Estados de sincronización en tiempo real
- Indicadores de conectividad

## 🌟 **Ejemplo Súper Simple**

```dart
class MiWidget extends StatefulWidget {
  @override
  _MiWidgetState createState() => _MiWidgetState();
}

class _MiWidgetState extends State<MiWidget> {
  final manager = OnlineOfflineManager(boxName: 'posts', endpoint: 'posts');
  List<Map<String, dynamic>> datos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    // ✨ Una línea - sincroniza y retorna datos actualizados
    final datosActualizados = await manager.getAllWithSync();
    setState(() { datos = datosActualizados; });
  }

  Future<void> _onRefresh() async {
    // 🌊 Datos frescos del servidor
    final datosFrescos = await manager.getFromServer();
    setState(() { datos = datosFrescos; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView.builder(
          itemCount: datos.length,
          itemBuilder: (context, index) {
            final item = datos[index];
            return ListTile(
              title: Text(item['title'] ?? 'Sin título'),
              trailing: item['sync'] == 'true' 
                ? Icon(Icons.cloud_done, color: Colors.green)
                : Icon(Icons.cloud_upload, color: Colors.orange),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    manager.dispose(); // 🧹 Limpieza automática
    super.dispose();
  }
}
```

## 📊 **API Reference Rápida**

| Método | Uso | Ejemplo |
|--------|-----|---------|
| `getAll()` | Datos locales rápidos | `await manager.getAll()` |
| `getFromServer()` | Datos frescos del servidor | `await manager.getFromServer()` |
| `getAllWithSync()` | Datos con sincronización | `await manager.getAllWithSync()` |
| `save(data)` | Guardar datos | `await manager.save({...})` |
| `sync()` | Sincronizar manualmente | `await manager.sync()` |

## 🌊 **Streams Reactivos**

```dart
// 📊 Datos en tiempo real
StreamBuilder<List<Map<String, dynamic>>>(
  stream: manager.dataStream,
  builder: (context, snapshot) {
    final datos = snapshot.data ?? [];
    return ListView.builder(
      itemCount: datos.length,
      itemBuilder: (context, index) => ListTile(
        title: Text(datos[index]['title']),
      ),
    );
  },
)

// 🔄 Estado de sincronización
StreamBuilder<SyncStatus>(
  stream: manager.statusStream,
  builder: (context, snapshot) {
    switch (snapshot.data) {
      case SyncStatus.syncing:
        return CircularProgressIndicator();
      case SyncStatus.success:
        return Icon(Icons.check_circle, color: Colors.green);
      default:
        return Container();
    }
  },
)
```

## 🎯 **¿Cuándo usar cada método?**

### `getAll()` - Datos Locales
**✅ Usar cuando:**
- Necesitas mostrar datos inmediatamente
- Trabajas offline
- UI que carga rápido

### `getFromServer()` - Datos Frescos
**✅ Usar cuando:**
- "Pull to refresh"
- Verificar actualizaciones
- Datos críticos del servidor

### `getAllWithSync()` - Lo Mejor de Ambos
**✅ Usar cuando:**
- Carga inicial de pantallas
- Quieres datos actualizados
- Sincronización inteligente

## 🐛 **Manejo de Errores Robusto**

```dart
try {
  // Intentar datos del servidor
  final datos = await manager.getFromServer();
  setState(() { this.datos = datos; });
} catch (e) {
  // Fallback a datos locales
  final datosLocales = await manager.getAll();
  setState(() { this.datos = datosLocales; });
  
  // Mostrar mensaje amigable
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Sin conexión. Mostrando datos locales.'),
      backgroundColor: Colors.orange,
    ),
  );
}
```

## 🔧 **Características Técnicas**

### ✨ **Auto-Inicialización**
- Sin configuración compleja
- Funciona inmediatamente
- Gestión automática de recursos

### 🌐 **Smart API Detection**
- Detecta respuestas anidadas: `{data: [...], total: N}`
- Funciona con respuestas simples: `[{...}]`
- Logs informativos automáticos

### 📱 **Offline-First**
- Funciona sin internet
- Sincronización automática
- Datos siempre disponibles

### 🛡️ **Robusto**
- Manejo inteligente de errores
- Recuperación automática
- Estado consistente

## 🚀 **Migración desde v1.x**

### ✅ **Compatibilidad Total**
```dart
// ✅ ESTE CÓDIGO SIGUE FUNCIONANDO
final manager = OnlineOfflineManager(boxName: 'datos', endpoint: 'items');
await manager.save({'name': 'Juan'});
final datos = await manager.getAll();
```

### ✨ **Nuevas Funcionalidades**
```dart
// 🆕 NUEVOS MÉTODOS DISPONIBLES
final datosFrescos = await manager.getFromServer();
final datosActualizados = await manager.getAllWithSync();
```

## 📚 **Recursos**

- **📖 README Completo**: [README.md](README.md)
- **🔧 Ejemplo Completo**: [example/complete_example.dart](example/complete_example.dart)
- **📝 Changelog**: [CHANGELOG.md](CHANGELOG.md)
- **🐛 Issues**: [GitHub Issues](https://github.com/betuko37/online_offline/issues)

## 🎉 **¡Listo para Usar!**

```bash
# 1. Instalar
flutter pub add betuko_offline_sync

# 2. Configurar
GlobalConfig.init(baseUrl: '...', token: '...');

# 3. ¡Usar!
final manager = OnlineOfflineManager(boxName: 'datos', endpoint: 'items');
final datos = await manager.getAllWithSync();
```

---

**🚀 ¡Disfruta de la nueva versión 2.0.0!**

> 💡 **¿Primera vez?** Empieza con el ejemplo básico y ve explorando las nuevas funcionalidades paso a paso.