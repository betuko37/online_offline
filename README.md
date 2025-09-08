# 🚀 Betuko Offline Sync

[![pub package](https://img.shields.io/pub/v/betuko_offline_sync.svg)](https://pub.dev/packages/betuko_offline_sync)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)

**La librería Flutter más simple para apps que funcionan offline y se sincronizan automáticamente.**

## 🎯 ¿Qué Hace?

Resuelve el problema más común en apps móviles: **¿Qué pasa cuando no hay internet?**

### ❌ **Sin Esta Librería:**
- Tu app se rompe sin internet
- Los usuarios pierden datos
- Necesitas programar sincronización manual

### ✅ **Con Esta Librería:**
- Tu app **siempre funciona**, con o sin internet
- Los datos se **sincronizan automáticamente**
- **Cero configuración** - solo usas la librería

## 🚀 Instalación

```yaml
dependencies:
  betuko_offline_sync: ^1.0.0
```

```bash
flutter pub get
```

## ⚙️ Configuración (Solo Una Vez)

### En tu main.dart
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

## 🎯 Uso Básico (3 Líneas)

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
    await manager.save('123', usuarioData);
    
    // ✅ ¡Listo! Se guarda localmente y sincroniza automáticamente
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }
}
```

## 📊 Mostrar Datos (UI Reactiva)

```dart
@override
Widget build(BuildContext context) {
  return StreamBuilder<Map<String, dynamic>>(
    stream: manager.data,  // ✅ Stream automático de datos
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final usuarios = snapshot.data!;
        
        return ListView.builder(
          itemCount: usuarios.length,
          itemBuilder: (context, index) {
            final usuario = usuarios[index.toString()];
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
```

## 🔄 ¿Cómo Funciona?

### **Sincronización Automática**
```dart
// ✅ La librería sincroniza automáticamente cuando:
// 1. Guardas datos (save)
// 2. Obtienes datos (getAll)
// 3. Eliminas datos (delete)
// 4. Se detecta internet
// 5. Se inicia la app (si hay datos pendientes)
```

### **Flujo de Sincronización**
```
1. Usuario guarda datos → Se guardan localmente
2. Se detecta internet → Sincronización automática
3. Datos se envían al servidor → Se confirma recepción
4. UI se actualiza → Usuario ve cambios
5. Si falla → Se reintenta automáticamente
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
  "id": "1234567890",
  "nombre": "Juan Pérez",
  "email": "juan@ejemplo.com",
  "_local_id": "1234567890",
  "_synced_at": "2024-01-15T10:30:00Z"
}
```

### **Implementación en Node.js + Prisma**
```typescript
// GET /api/users
app.get('/api/users', async (req, res) => {
  try {
    const usuarios = await prisma.user.findMany({
      where: { activo: true }
    });
    res.json(usuarios);
  } catch (error) {
    res.status(500).json({ error: 'Error obteniendo usuarios' });
  }
});

// POST /api/users
app.post('/api/users', async (req, res) => {
  try {
    const { _local_id, _synced_at, ...userData } = req.body;
    
    // Upsert en PostgreSQL
    const usuario = await prisma.user.upsert({
      where: { id: userData.id },
      update: {
        ...userData,
        syncedAt: _synced_at ? new Date(_synced_at) : new Date(),
      },
      create: {
        ...userData,
        syncedAt: _synced_at ? new Date(_synced_at) : new Date(),
      }
    });
    
    res.json(usuario);
  } catch (error) {
    res.status(500).json({ error: 'Error sincronizando usuario' });
  }
});
```

## 📊 Streams Reactivos

### **Estado de Sincronización**
```dart
StreamBuilder<SyncStatus>(
  stream: manager.status,
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
  stream: manager.connectivity,
  builder: (context, snapshot) {
    if (snapshot.data == true) {
      return Text('Conectado', style: TextStyle(color: Colors.green));
    }
    return Text('Sin conexión', style: TextStyle(color: Colors.red));
  },
)
```

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
    'id': '123',
    'nombre': 'Juan',
    'email': 'juan@ejemplo.com'
  };

  await manager.save('123', testData);
  
  final savedData = await manager.get('123');
  expect(savedData, testData);
  
  await manager.dispose();
});
```

## 📚 API Reference

### **OnlineOfflineManager**

#### **Constructor**
```dart
OnlineOfflineManager({
  required String boxName,    // Nombre de tu tabla local
  String? endpoint,           // Endpoint de tu API
})
```

#### **Métodos Principales**
- `Future<void> save(String key, dynamic value)` - Guarda datos
- `Future<dynamic> get(String key)` - Obtiene datos por clave
- `Future<Map<String, dynamic>> getAll()` - Obtiene todos los datos
- `Future<void> delete(String key)` - Elimina datos
- `Future<void> sync()` - Sincronización manual

#### **Streams**
- `Stream<SyncStatus> status` - Estado de sincronización
- `Stream<bool> connectivity` - Estado de conectividad
- `Stream<Map<String, dynamic>> data` - Datos almacenados

### **GlobalConfig**

#### **Métodos**
- `void init({required String baseUrl, required String token})` - Inicializar configuración
- `String? get baseUrl` - Obtener URL base
- `String? get token` - Obtener token
- `bool get isInitialized` - Verificar si está inicializado

## 🎯 Casos de Uso

- **Apps de Campo** - Agricultura, construcción, ventas móviles
- **Apps Empresariales** - CRM, inventarios, gestión de empleados
- **Apps Médicas** - Consultas, expedientes, datos críticos
- **Apps de Ventas** - E-commerce, catálogos offline

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
- 🐛 Issues: [GitHub Issues](https://github.com/betuko/offline_sync/issues)
- 📖 Documentación: [Wiki](https://github.com/betuko/offline_sync/wiki)

---

**¡Hecho con ❤️ para la comunidad Flutter!**

## 🎯 Resumen: ¿Por Qué Usar Betuko Offline Sync?

### ✅ **Beneficios:**
- **Tu app nunca se rompe** - Funciona offline y online
- **Cero configuración** - Solo 3 líneas para empezar
- **Sincronización automática** - No necesitas programar nada
- **UI reactiva** - Se actualiza automáticamente
- **Funciona con cualquier backend** - No necesitas cambiar tu API

### ✅ **Ahorro de Tiempo:**
- **Sin librería:** 2-3 semanas programando sincronización
- **Con librería:** 30 minutos configurando

**¡Empieza ahora y haz tu app offline-first en minutos!** 🚀