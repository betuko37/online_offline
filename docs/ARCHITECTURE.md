# 🏗️ Arquitectura de Betuko Offline Sync

## 🎯 Visión General

`betuko_offline_sync` utiliza una **arquitectura modular** que separa responsabilidades y permite tanto uso simple como personalización avanzada.

## 📐 Principios de Diseño

### 1. **Separación de Responsabilidades**
Cada servicio tiene una responsabilidad específica:
- `OnlineOfflineManager`: Coordinación general
- `LocalStorage`: Persistencia de datos
- `ApiClient`: Comunicación HTTP
- `SyncService`: Lógica de sincronización
- `ConnectivityService`: Monitoreo de red
- `GlobalConfig`: Configuración centralizada

### 2. **Inversión de Dependencias**
Los servicios de alto nivel no dependen de implementaciones específicas, sino de abstracciones.

### 3. **Composición sobre Herencia**
El `OnlineOfflineManager` compone servicios en lugar de heredar funcionalidades.

## 🧩 Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              OnlineOfflineManager                          │
│  ┌─────────────────┬─────────────────┬─────────────────┐   │
│  │   LocalStorage  │   SyncService   │ ConnectivitySvc │   │
│  └─────────────────┼─────────────────┼─────────────────┘   │
└──────────────────────┼─────────────────┼─────────────────────┘
                       │                 │
            ┌──────────▼─────────┐       │
            │     ApiClient      │       │
            └────────────────────┘       │
                       │                 │
            ┌──────────▼─────────┐   ┌───▼───────┐
            │   GlobalConfig     │   │   Hive    │
            └────────────────────┘   └───────────┘
                       │
            ┌──────────▼─────────┐
            │    HTTP Server     │
            └────────────────────┘
```

## 📦 Detalles de Cada Capa

### **Capa de Presentación (Flutter App)**
- Widgets de la aplicación
- StreamBuilders para UI reactiva
- Manejo de estados de la UI

### **Capa de Coordinación (OnlineOfflineManager)**
- Punto de entrada principal
- Coordinación entre servicios
- Gestión de streams
- Auto-sync en cambios de conectividad

### **Capa de Servicios**

#### **LocalStorage**
- **Responsabilidad**: Persistencia local de datos
- **Tecnología**: Hive (NoSQL local)
- **Funciones**: CRUD, filtrado, búsqueda

#### **SyncService**
- **Responsabilidad**: Lógica de sincronización
- **Funciones**: Upload pendientes, download servidor, manejo de conflictos

#### **ConnectivityService**
- **Responsabilidad**: Monitoreo de conectividad
- **Tecnología**: connectivity_plus
- **Funciones**: Detección de cambios de red, streams de conectividad

#### **ApiClient**
- **Responsabilidad**: Comunicación HTTP
- **Tecnología**: http package
- **Funciones**: GET, POST, manejo de headers y autenticación

### **Capa de Configuración (GlobalConfig)**
- **Responsabilidad**: Configuración centralizada
- **Funciones**: URL base, tokens, configuración global

## 🔄 Flujo de Datos

### **Guardar Datos (Write Flow)**
```
1. App calls manager.save(data)
2. Manager generates ID and timestamp
3. LocalStorage saves data locally
4. Manager notifies dataStream
5. If online: SyncService uploads to server
6. Server confirms: Mark as synced
7. UI updates automatically
```

### **Leer Datos (Read Flow)**
```
1. App subscribes to manager.dataStream
2. Manager queries LocalStorage
3. LocalStorage returns all data
4. Manager emits via dataStream
5. UI updates automatically
```

### **Sincronización (Sync Flow)**
```
1. ConnectivityService detects internet
2. Manager triggers SyncService.sync()
3. SyncService uploads pending data
4. SyncService downloads server data
5. LocalStorage merges data
6. Manager notifies dataStream
7. UI updates with synced data
```

## 🎛️ Configuraciones Soportadas

### **Configuración Simple**
```dart
final manager = OnlineOfflineManager(
  boxName: 'datos',
  endpoint: 'users',
);
```

### **Configuración Modular**
```dart
final storage = LocalStorage(boxName: 'datos');
final apiClient = ApiClient();
final syncService = SyncService(storage: storage, endpoint: 'users');
final connectivity = ConnectivityService();

// Uso personalizado de servicios individuales
```

### **Configuración Personalizada**
```dart
class MiManager extends OnlineOfflineManager {
  MiManager() : super(boxName: 'mi_app', endpoint: 'mi_endpoint');
  
  @override
  Future<void> save(Map<String, dynamic> data) async {
    // Lógica personalizada antes de guardar
    data['custom_field'] = 'custom_value';
    await super.save(data);
  }
}
```

## 🔒 Principios de Seguridad

### **Autenticación**
- Token centralizado en `GlobalConfig`
- Headers automáticos en todas las peticiones
- Renovación de token transparente

### **Datos Locales**
- Encriptación opcional con Hive
- Limpieza automática de datos sensibles
- Validación de integridad

### **Comunicación**
- HTTPS obligatorio en producción
- Timeouts configurables
- Retry automático con backoff

## 🚀 Optimizaciones de Rendimiento

### **Almacenamiento Local**
- Índices automáticos en Hive
- Compresión de datos
- Lazy loading de datos grandes

### **Sincronización**
- Batch upload de múltiples registros
- Sincronización incremental
- Compresión de payloads

### **Memoria**
- Streams con auto-cleanup
- Weak references donde sea posible
- Disposal automático de recursos

## 🧪 Estrategias de Testing

### **Unit Tests**
- Cada servicio testeable independientemente
- Mocks para dependencias externas
- Test coverage > 90%

### **Integration Tests**
- Flujos completos de datos
- Scenarios offline/online
- Performance benchmarks

### **Widget Tests**
- UI reactiva con streams
- Estados de error y loading
- Manejo de edge cases

## 📈 Escalabilidad

### **Horizontal**
- Múltiples managers para diferentes dominios
- Servicios compartidos entre managers
- Cache distribuido

### **Vertical**
- Configuración por endpoints
- Transformadores de datos
- Validadores personalizados

## 🔮 Futuras Mejoras

### **Planificadas v2.0**
- Sincronización diferencial (delta sync)
- Resolución automática de conflictos
- Compresión de datos avanzada
- Métricas de sincronización

### **Consideradas**
- Soporte para GraphQL
- Encriptación end-to-end
- Sincronización P2P
- Worker isolates para sync

---

Esta arquitectura permite que `betuko_offline_sync` sea tanto simple para casos básicos como extensible para necesidades complejas, manteniendo siempre la separación de responsabilidades y la testabilidad.
