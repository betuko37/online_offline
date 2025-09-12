# 🔄 Guía de Migración - Betuko Offline Sync

## 📋 Resumen de Cambios

La nueva versión de `betuko_offline_sync` introduce una **arquitectura modular** que mejora significativamente la flexibilidad y mantenibilidad del código.

### 🆕 **Nueva Arquitectura Modular**

#### **Antes (v1.0.x)**
```dart
// Un solo archivo monolítico
OnlineOfflineManager - Todo en una clase
```

#### **Ahora (v1.1.x)**
```dart
// Arquitectura modular
OnlineOfflineManager     // Coordinador principal
├── LocalStorage        // Almacenamiento local
├── ApiClient          // Cliente HTTP
├── SyncService        // Servicio de sincronización
├── ConnectivityService // Servicio de conectividad
└── GlobalConfig       // Configuración centralizada
```

## 🚀 Migración Automática (Sin Cambios)

### ✅ **Tu Código Actual Sigue Funcionando**

Si usas el `OnlineOfflineManager` básico, **no necesitas cambiar nada**:

```dart
// ✅ ESTE CÓDIGO SIGUE FUNCIONANDO IGUAL
final manager = OnlineOfflineManager(
  boxName: 'usuarios',
  endpoint: 'users',
);

await manager.save({'nombre': 'Juan'});
final datos = await manager.getAll();
```

### ✅ **Streams Siguen Igual**

```dart
// ✅ ESTOS STREAMS SIGUEN FUNCIONANDO
StreamBuilder<List<Map<String, dynamic>>>(
  stream: manager.dataStream,
  builder: (context, snapshot) {
    // Tu código actual
  },
)

StreamBuilder<SyncStatus>(
  stream: manager.statusStream,
  builder: (context, snapshot) {
    // Tu código actual
  },
)
```

## 🔧 Migraciones Opcionales (Mejoras)

### 1. **Usar Servicios Modulares (Opcional)**

#### **Antes**
```dart
// Solo podías usar el manager completo
final manager = OnlineOfflineManager(boxName: 'datos', endpoint: 'users');
```

#### **Ahora - Opción 1: Manager Completo (Igual que antes)**
```dart
// ✅ Sigue funcionando igual
final manager = OnlineOfflineManager(boxName: 'datos', endpoint: 'users');
```

#### **Ahora - Opción 2: Servicios Modulares (Nuevo)**
```dart
// 🆕 Ahora puedes usar servicios individuales
final storage = LocalStorage(boxName: 'datos');
await storage.initialize();

final apiClient = ApiClient();
final syncService = SyncService(storage: storage, endpoint: 'users');
```

### 2. **Configuración Avanzada (Opcional)**

#### **Antes**
```dart
// Configuración limitada
GlobalConfig.init(baseUrl: 'https://api.com', token: 'token');
```

#### **Ahora**
```dart
// ✅ Misma configuración básica funciona
GlobalConfig.init(baseUrl: 'https://api.com', token: 'token');

// 🆕 Pero ahora también puedes usar servicios por separado
final storage = LocalStorage(boxName: 'custom');
final client = ApiClient(); // Usa GlobalConfig automáticamente
```

## 📊 Comparación de APIs

### **OnlineOfflineManager**

| Método | v1.0.x | v1.1.x | Cambios |
|--------|--------|--------|---------|
| `save(data)` | ✅ Funciona | ✅ Funciona | ✅ Sin cambios |
| `getAll()` | ✅ Funciona | ✅ Funciona | ✅ Sin cambios |
| `getById(id)` | ✅ Funciona | ✅ Funciona | ✅ Sin cambios |
| `delete(id)` | ✅ Funciona | ✅ Funciona | ✅ Sin cambios |
| `sync()` | ✅ Funciona | ✅ Funciona | ✅ Sin cambios |
| `dataStream` | ✅ Funciona | ✅ Funciona | ✅ Sin cambios |
| `statusStream` | ✅ Funciona | ✅ Funciona | ✅ Sin cambios |

### **Nuevos Servicios Disponibles**

| Servicio | Descripción | Uso |
|----------|-------------|-----|
| `LocalStorage` | Almacenamiento local | Para casos que solo necesitan persistencia |
| `ApiClient` | Cliente HTTP | Para casos que solo necesitan HTTP |
| `SyncService` | Sincronización | Para lógica de sync personalizada |
| `ConnectivityService` | Conectividad | Para monitoreo de red |

## 🔧 Casos de Migración Específicos

### **Caso 1: Solo Almacenamiento Local**

#### **Antes**
```dart
// Tenías que usar el manager completo aunque no necesitaras sync
final manager = OnlineOfflineManager(boxName: 'cache');
await manager.save({'data': 'value'});
```

#### **Ahora**
```dart
// 🆕 Ahora puedes usar solo el almacenamiento
final storage = LocalStorage(boxName: 'cache');
await storage.initialize();
await storage.save('key', {'data': 'value'});
```

### **Caso 2: Solo Cliente HTTP**

#### **Antes**
```dart
// Tenías que configurar manager aunque solo quisieras HTTP
GlobalConfig.init(baseUrl: 'https://api.com', token: 'token');
// Luego usar manager para HTTP...
```

#### **Ahora**
```dart
// 🆕 Ahora puedes usar solo el cliente HTTP
GlobalConfig.init(baseUrl: 'https://api.com', token: 'token');
final client = ApiClient();
final response = await client.get('endpoint');
```

### **Caso 3: Lógica de Sync Personalizada**

#### **Antes**
```dart
// Tenías que extender OnlineOfflineManager
class CustomManager extends OnlineOfflineManager {
  // Override métodos internos complejos
}
```

#### **Ahora**
```dart
// 🆕 Ahora puedes componer servicios
class CustomSyncLogic {
  final LocalStorage storage;
  final ApiClient client;
  
  CustomSyncLogic(this.storage, this.client);
  
  Future<void> customSync() async {
    final data = await storage.getAll();
    // Tu lógica personalizada
    await client.post('custom-endpoint', data.first);
  }
}
```

## 🧪 Migración de Tests

### **Tests Existentes**

#### **Antes y Ahora - Sin Cambios**
```dart
// ✅ TUS TESTS ACTUALES SIGUEN FUNCIONANDO
test('should save data', () async {
  final manager = OnlineOfflineManager(boxName: 'test', endpoint: 'test');
  await manager.save({'test': 'data'});
  final data = await manager.getAll();
  expect(data.length, 1);
});
```

### **Nuevas Posibilidades de Testing**

#### **Tests Modulares**
```dart
// 🆕 Ahora puedes testear servicios individualmente
test('LocalStorage should save and retrieve', () async {
  final storage = LocalStorage(boxName: 'test');
  await storage.initialize();
  
  await storage.save('key', {'test': 'data'});
  final retrieved = await storage.get('key');
  
  expect(retrieved['test'], 'data');
});

test('ApiClient should make requests', () async {
  GlobalConfig.init(baseUrl: 'https://test.com', token: 'test');
  final client = ApiClient();
  
  // Mock o test real
  final response = await client.get('endpoint');
  expect(response.isSuccess, true);
});
```

## 📋 Checklist de Migración

### ✅ **Migración Básica (Recomendada)**
- [ ] Actualizar `pubspec.yaml` a la nueva versión
- [ ] Ejecutar `flutter pub get`
- [ ] Ejecutar tests existentes - deberían pasar sin cambios
- [ ] ¡Listo! No necesitas más cambios

### 🚀 **Migración Avanzada (Opcional)**
- [ ] Identificar código que puede beneficiarse de servicios modulares
- [ ] Refactorizar usando `LocalStorage` para casos solo-local
- [ ] Refactorizar usando `ApiClient` para casos solo-HTTP
- [ ] Crear servicios personalizados componiendo servicios básicos
- [ ] Agregar tests para nuevos servicios modulares

## ⚠️ Cambios que Requieren Atención

### **Dependencias Removidas**
La nueva versión removió `path_provider` como dependencia requerida:

#### **Antes**
```yaml
# path_provider era requerido
dependencies:
  betuko_offline_sync: ^1.0.x
  # path_provider se instalaba automáticamente
```

#### **Ahora**
```yaml
# path_provider ya no es requerido automáticamente
dependencies:
  betuko_offline_sync: ^1.1.x
  # Solo instala las dependencias que realmente usas
```

**⚠️ Acción requerida**: Si tu app usaba `path_provider` directamente, agrégalo manualmente a tu `pubspec.yaml`.

## 🆘 Solución de Problemas

### **Error: "No se encuentran archivos Hive"**
```dart
// ❌ Problema: Archivos de la versión anterior no se encuentran
// ✅ Solución: Limpiar cache de Hive
await Hive.deleteBoxFromDisk('tu_box_name');
```

### **Error: "Configuración no encontrada"**
```dart
// ❌ Problema: GlobalConfig no inicializado
// ✅ Solución: Asegurar inicialización antes de usar servicios
GlobalConfig.init(baseUrl: 'https://api.com', token: 'token');
```

### **Tests fallan después de actualizar**
```bash
# ✅ Solución: Limpiar y regenerar
flutter clean
flutter pub get
flutter test
```

## 📞 Soporte para Migración

Si encuentras problemas durante la migración:

1. **Revisa los logs**: La nueva versión tiene mejor logging
2. **Verifica la configuración**: `GlobalConfig.isInitialized`
3. **Tests**: Ejecuta tests en entorno aislado
4. **Issues**: Reporta problemas en [GitHub Issues](https://github.com/betuko37/online_offline/issues)

---

## 🎯 Resumen

- ✅ **Compatibilidad total**: Tu código actual sigue funcionando
- 🚀 **Nuevas posibilidades**: Servicios modulares opcionales
- 🧪 **Tests**: Sin cambios necesarios
- 📈 **Beneficios**: Mejor arquitectura, más flexibilidad, fácil testing

**La migración es opcional pero recomendada para aprovechar las nuevas capacidades modulares.**
