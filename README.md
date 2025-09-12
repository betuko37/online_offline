# 🚀 Betuko Offline Sync

[![pub package](https://img.shields.io/pub/v/betuko_offline_sync.svg)](https://pub.dev/packages/betuko_offline_sync)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)

**La librería Flutter más simple y modular para apps que funcionan offline y se sincronizan automáticamente.**

## 🎯 ¿Qué Hace?

Resuelve el problema más común en apps móviles: **¿Qué pasa cuando no hay internet?**

### ❌ **Sin Esta Librería:**
- Tu app se rompe sin internet
- Los usuarios pierden datos
- Necesitas programar sincronización manual
- Código complejo y difícil de mantener

### ✅ **Con Esta Librería:**
- Tu app **siempre funciona**, con o sin internet
- Los datos se **sincronizan automáticamente**
- **Arquitectura modular** - usa solo lo que necesitas
- **Cero configuración** para uso básico
- **Alta personalización** para casos avanzados

## 🚀 Instalación

```yaml
dependencies:
  betuko_offline_sync: ^1.0.0
```

```bash
flutter pub get
```

## 🎯 Uso Rápido (3 Líneas)

### 1. Configuración Global (Una Vez)
```dart
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🎯 CONFIGURAR UNA SOLA VEZ
  GlobalConfig.init(
    baseUrl: 'https://tu-api.com/api',
    token: 'tu_token_de_autenticacion',
  );
  
  runApp(MyApp());
}
```

### 2. Uso Básico con OnlineOfflineManager
```dart
class MiWidget extends StatefulWidget {
  @override
  _MiWidgetState createState() => _MiWidgetState();
}

class _MiWidgetState extends State<MiWidget> {
  late OnlineOfflineManager manager;
  
  @override
  void initState() {
    super.initState();
    
    // 🎯 LÍNEA 1: Crear manager
    manager = OnlineOfflineManager(
      boxName: 'usuarios',    // Nombre de tu tabla local
      endpoint: 'users',      // Endpoint de tu API
    );
  }

  Future<void> _guardarUsuario() async {
    // 🎯 LÍNEA 2: Preparar datos
    final usuarioData = {
      'nombre': 'Juan Pérez',
      'email': 'juan@ejemplo.com',
    };

    // 🎯 LÍNEA 3: Guardar (funciona offline y online)
    await manager.save(usuarioData);
    
    // ✅ ¡Listo! Se guarda localmente y sincroniza automáticamente
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: manager.dataStream,  // ✅ Stream automático de datos
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final usuarios = snapshot.data!;
          
          return ListView.builder(
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final usuario = usuarios[index];
              return ListTile(
                title: Text(usuario['nombre'] ?? 'Sin nombre'),
                subtitle: Text(usuario['email'] ?? 'Sin email'),
              );
            },
          );
        }
        
        return CircularProgressIndicator();
      },
    );
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }
}
```

## 🏗️ Arquitectura Modular

La librería está diseñada con **arquitectura modular**. Puedes usar el manager completo o solo los servicios que necesites:

### 📦 **OnlineOfflineManager** (Uso Simple)
```dart
// Todo incluido - perfecto para comenzar
final manager = OnlineOfflineManager(
  boxName: 'datos',
  endpoint: 'mi-endpoint',
);
```

### 🧩 **Servicios Individuales** (Uso Avanzado)
```dart
// Almacenamiento local
final storage = LocalStorage(boxName: 'mi_box');
await storage.initialize();

// Cliente HTTP
final apiClient = ApiClient();

// Servicio de sincronización
final syncService = SyncService(
  storage: storage,
  endpoint: 'mi-endpoint',
);

// Servicio de conectividad
final connectivity = ConnectivityService();
await connectivity.initialize();
```

## 📊 Streams Reactivos

### **Estado de Sincronización**
```dart
StreamBuilder<SyncStatus>(
  stream: manager.statusStream,
  builder: (context, snapshot) {
    switch (snapshot.data) {
      case SyncStatus.syncing:
        return CircularProgressIndicator();
      case SyncStatus.success:
        return Icon(Icons.check_circle, color: Colors.green);
      case SyncStatus.error:
        return Icon(Icons.error, color: Colors.red);
      default:
        return Icon(Icons.sync);
    }
  },
)
```

### **Estado de Conectividad**
```dart
StreamBuilder<bool>(
  stream: manager.connectivityStream,
  builder: (context, snapshot) {
    if (snapshot.data == true) {
      return Text('🌐 Conectado', style: TextStyle(color: Colors.green));
    }
    return Text('📱 Sin conexión', style: TextStyle(color: Colors.red));
  },
)
```

## 🗄️ Configuración del Backend

### **Tu Backend Solo Necesita 2 Endpoints:**

#### 1. **GET /api/users** (Para obtener datos)
```http
GET https://tu-api.com/api/users
Authorization: Bearer tu_token
```

**Respuesta esperada:**
```json
[
  {
    "id": "1",
    "nombre": "Juan Pérez",
    "email": "juan@ejemplo.com"
  }
]
```

#### 2. **POST /api/users** (Para sincronizar datos)
```http
POST https://tu-api.com/api/users
Authorization: Bearer tu_token
Content-Type: application/json
```

**Payload que envía la librería:**
```json
{
  "nombre": "Juan Pérez",
  "email": "juan@ejemplo.com",
  "created_at": "2024-01-15T10:30:00Z"
}
```

## 📚 Documentación Completa

- 📖 **[Documentación Técnica Completa](lib/COMPLETE_DOCUMENTATION.md)** - Guía detallada de todos los servicios
- 🏗️ **[Guía de Arquitectura](docs/ARCHITECTURE.md)** - Entender la estructura modular
- 🔄 **[Guía de Migración](docs/MIGRATION.md)** - Migrar desde versiones anteriores
- 🧪 **[Ejemplos Avanzados](examples/)** - Casos de uso complejos

## 🧪 Testing

```bash
flutter test
```

### **Ejemplo de Test**
```dart
test('debería guardar datos localmente', () async {
  final manager = OnlineOfflineManager(
    boxName: 'test_box',
    endpoint: 'test_endpoint',
  );
  
  final testData = {
    'nombre': 'Juan',
    'email': 'juan@ejemplo.com'
  };

  await manager.save(testData);
  
  final allData = await manager.getAll();
  expect(allData.length, 1);
  expect(allData.first['nombre'], 'Juan');
  
  manager.dispose();
});
```

## 📚 API Reference Rápida

### **OnlineOfflineManager**
- `save(data)` - Guarda datos localmente y sincroniza
- `getAll()` - Obtiene todos los datos
- `getById(id)` - Obtiene datos por ID
- `delete(id)` - Elimina datos
- `sync()` - Sincronización manual
- `clear()` - Limpia todos los datos
- `getPending()` - Obtiene datos pendientes de sincronizar
- `getSynced()` - Obtiene datos ya sincronizados

### **Streams**
- `dataStream` - Stream de todos los datos
- `statusStream` - Stream del estado de sincronización
- `connectivityStream` - Stream del estado de conectividad

### **Servicios Modulares**
- `LocalStorage` - Almacenamiento local con Hive
- `ApiClient` - Cliente HTTP simplificado
- `SyncService` - Servicio de sincronización
- `ConnectivityService` - Servicio de conectividad

## 🎯 Casos de Uso

- **Apps de Campo** - Agricultura, construcción, ventas móviles
- **Apps Empresariales** - CRM, inventarios, gestión de empleados
- **Apps Médicas** - Consultas, expedientes, datos críticos
- **Apps de Ventas** - E-commerce, catálogos offline
- **Apps de Encuestas** - Recolección de datos en áreas remotas

## 🔧 Personalización Avanzada

### **Uso Modular Personalizado**
```dart
// Crear tus propios servicios personalizados
class MiAppService {
  final LocalStorage _storage;
  final ApiClient _apiClient;
  
  MiAppService() 
    : _storage = LocalStorage(boxName: 'mi_app'),
      _apiClient = ApiClient();
  
  Future<void> operacionCustom() async {
    // Tu lógica personalizada
    final data = await _storage.getAll();
    final response = await _apiClient.post('custom-endpoint', data.first);
    // ...
  }
}
```

## 🤝 Contribuir

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## 🙏 Agradecimientos

- [Hive](https://pub.dev/packages/hive) - Almacenamiento local rápido
- [Connectivity Plus](https://pub.dev/packages/connectivity_plus) - Detección de conectividad
- [HTTP](https://pub.dev/packages/http) - Cliente HTTP para sincronización

## 📞 Soporte

- 📧 Email: soporte@betuko.com
- 🐛 Issues: [GitHub Issues](https://github.com/betuko37/online_offline/issues)
- 📖 Documentación: [GitHub Wiki](https://github.com/betuko37/online_offline/wiki)

---

**¡Hecho con ❤️ para la comunidad Flutter!**

## 🎯 Resumen: ¿Por Qué Usar Betuko Offline Sync?

### ✅ **Beneficios:**
- **Tu app nunca se rompe** - Funciona offline y online
- **Arquitectura modular** - Usa solo lo que necesitas
- **Cero configuración** - Solo 3 líneas para empezar
- **Alta personalización** - Servicios individuales disponibles
- **Sincronización automática** - No necesitas programar nada
- **UI reactiva** - Se actualiza automáticamente
- **Funciona con cualquier backend** - No necesitas cambiar tu API

### ✅ **Ahorro de Tiempo:**
- **Sin librería:** 2-3 semanas programando sincronización
- **Con librería:** 30 minutos configurando
- **Arquitectura modular:** Fácil mantenimiento y testing

**¡Empieza ahora y haz tu app offline-first en minutos!** 🚀
