# 📚 Ejemplos de Uso de la Librería

## 🎯 **Ejemplos Básicos para Empezar**

Esta carpeta contiene ejemplos básicos y claros para aprender a usar la librería de forma rápida y efectiva.

## 📁 **Archivos de Ejemplo:**

### **1️⃣ main_example.dart** - Configuración Global
**Propósito:** Mostrar cómo configurar la librería en el archivo `main()`

**Qué muestra:**
- ✅ Cómo inicializar `GlobalConfig` en `main()`
- ✅ Configuración de `baseUrl` y `token`
- ✅ Información de configuración activa
- ✅ Navegación básica entre pantallas

**Cuándo usarlo:**
- Cuando quieres ver cómo configurar la librería globalmente
- Para entender el flujo de inicialización
- Como referencia para tu propio `main()`

### **2️⃣ widget_example.dart** - Widgets Básicos
**Propósito:** Mostrar cómo usar la librería en widgets reales con operaciones CRUD

**Qué muestra:**
- ✅ Inicialización del `OnlineOfflineManager`
- ✅ Formulario para agregar usuarios
- ✅ Lista reactiva con `StreamBuilder`
- ✅ Operaciones CRUD (Create, Read, Update, Delete)
- ✅ Sincronización manual
- ✅ Manejo de errores y estados de carga
- ✅ Diálogos de confirmación

**Cuándo usarlo:**
- Cuando quieres implementar la librería en tus widgets
- Para ver operaciones CRUD completas
- Como referencia para tu propia implementación

## 🚀 **Cómo Usar los Ejemplos:**

### **Paso 1: Configuración Global**
```dart
// En tu main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configurar la librería globalmente
  GlobalConfig.init(
    baseUrl: 'https://tu-api.com/api',
    token: 'tu_token_de_autenticacion',
  );
  
  runApp(MyApp());
}
```

### **Paso 2: Usar en Widgets**
```dart
// En tu widget
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late OnlineOfflineManager _manager;
  
  @override
  void initState() {
    super.initState();
    _initializeManager();
  }
  
  void _initializeManager() async {
    _manager = OnlineOfflineManager(
      boxName: 'usuarios',    // Nombre del box local
      endpoint: 'users',      // Endpoint del servidor
    );
    
    await _manager.initialize();
  }
  
  // Usar el manager para operaciones CRUD
  Future<void> _saveData() async {
    await _manager.save('123', {'nombre': 'Juan', 'email': 'juan@ejemplo.com'});
  }
  
  Future<void> _getData() async {
    final data = await _manager.getAll();
    print(data);
  }
  
  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }
}
```

## 🎯 **Características Principales de los Ejemplos:**

### **📱 main_example.dart:**
- **Configuración visual** - Muestra el estado de la configuración
- **Información clara** - Explica cómo funciona la configuración global
- **Navegación simple** - Botón para ir al ejemplo de widgets
- **Diseño limpio** - Cards con colores para mejor visualización

### **📱 widget_example.dart:**
- **Formulario completo** - Campos para nombre, email y teléfono
- **Lista reactiva** - Se actualiza automáticamente con `StreamBuilder`
- **Operaciones CRUD** - Agregar, editar, eliminar usuarios
- **Estados de carga** - Indicadores visuales durante operaciones
- **Manejo de errores** - SnackBars informativos
- **Sincronización manual** - Botón para sincronizar con servidor
- **Información del manager** - Diálogo con detalles del estado

## 🔧 **Funcionalidades Demostradas:**

### **✅ Operaciones Básicas:**
- **Save** - Guardar datos localmente y sincronizar
- **Get** - Obtener datos por ID
- **GetAll** - Obtener todos los datos
- **Delete** - Eliminar datos
- **Sync** - Sincronización manual

### **✅ Características Avanzadas:**
- **Streams reactivos** - Datos en tiempo real
- **Autosync** - Sincronización automática
- **Manejo de conectividad** - Detección de internet
- **Estados de sincronización** - Tracking del proceso
- **Manejo de errores** - Try-catch robusto

### **✅ UI/UX:**
- **Formularios** - Campos de entrada con validación
- **Listas** - Mostrar datos de forma organizada
- **Estados de carga** - Indicadores visuales
- **Mensajes** - SnackBars informativos
- **Diálogos** - Confirmaciones y información

## 📖 **Cómo Estudiar los Ejemplos:**

### **1️⃣ Para Principiantes:**
1. **Empieza con `main_example.dart`** - Entiende la configuración global
2. **Luego ve a `widget_example.dart`** - Ve cómo se usa en widgets
3. **Copia el código** - Adapta los ejemplos a tu proyecto
4. **Experimenta** - Modifica los ejemplos para aprender

### **2️⃣ Para Desarrolladores Experimentados:**
1. **Revisa la arquitectura** - Entiende cómo están organizados los servicios
2. **Estudia los patrones** - Ve cómo se manejan los streams y estados
3. **Adapta a tu caso** - Usa los ejemplos como base para tu implementación
4. **Extiende funcionalidad** - Agrega características específicas

## 🎯 **Casos de Uso Comunes:**

### **📱 Aplicación de Usuarios:**
- Lista de usuarios con CRUD completo
- Sincronización automática con servidor
- Funciona offline y online

### **📱 Aplicación de Productos:**
- Catálogo de productos
- Inventario local
- Sincronización de precios

### **📱 Aplicación de Tareas:**
- Lista de tareas
- Estado local persistente
- Sincronización de cambios

## 🚀 **Próximos Pasos:**

1. **Ejecuta los ejemplos** - Ve cómo funcionan en acción
2. **Modifica el código** - Experimenta con diferentes configuraciones
3. **Integra en tu proyecto** - Usa los ejemplos como base
4. **Personaliza** - Adapta a tus necesidades específicas

## 💡 **Consejos:**

- **Empieza simple** - Usa solo `OnlineOfflineManager` al principio
- **Configura globalmente** - Usa `GlobalConfig.init()` en `main()`
- **Maneja errores** - Siempre usa try-catch en operaciones async
- **Libera recursos** - Llama `dispose()` cuando termines
- **Usa streams** - Aprovecha los `StreamBuilder` para UI reactiva

**¡Los ejemplos están listos para usar y aprender!** 🎉
