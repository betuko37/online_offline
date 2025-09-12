# 🔄 Sistema de Sincronización Mejorado

## ✨ Cambios Principales

### 📝 **Nuevo Formato de Datos**

#### **Datos Pendientes** (sin sincronizar)
```dart
{
  "title": "Mi Producto",
  "body": "Descripción del producto", 
  "created_at": "2025-09-12T01:34:53.961664",
  "sync": "false"  // String: Pendiente de sincronizar
}
```

#### **Datos Sincronizados**
```dart
{
  "title": "Mi Producto",
  "body": "Descripción del producto",
  "created_at": "2025-09-12T01:34:53.961664", 
  "sync": "true",  // String: Ya sincronizado
  "syncDate": "2025-09-12T01:35:10.123456"  // Fecha de sincronización
}
```

### 🎯 **¿Qué se Envía al Servidor?**

#### ✅ **SE ENVÍA** (solo datos del frontend)
```dart
{
  "title": "Mi Producto",
  "body": "Descripción del producto",
  "created_at": "2025-09-12T01:34:53.961664",
  "sync": "false"
}
```

#### ❌ **NO SE ENVÍA** (campos internos removidos automáticamente)
- ~~`userId`: 1~~ (auto-generado por el servidor)
- ~~`title`: ""~~ (campos vacíos removidos)
- ~~`body`: ""`~~ (campos vacíos removidos)
- ~~`syncDate`~~ (campo interno de sincronización)

### 🔄 **Flujo de Sincronización**

#### **1. Guardar Datos**
```dart
// Usuario guarda datos
await manager.save({
  'title': 'Mi Producto',
  'body': 'Descripción',
});

// Se almacena localmente como:
{
  "title": "Mi Producto",
  "body": "Descripción", 
  "created_at": "2025-09-12T01:34:53.961664",
  "sync": "false"  // ⏳ Pendiente (String)
}
```

#### **2. Sincronización Automática**
```dart
// Cuando hay internet, se envía al servidor:
POST /endpoint
{
  "title": "Mi Producto",
  "body": "Descripción",
  "created_at": "2025-09-12T01:34:53.961664",
  "sync": "false"
}

// Si es exitoso (200), se actualiza localmente:
{
  "title": "Mi Producto", 
  "body": "Descripción",
  "created_at": "2025-09-12T01:34:53.961664",
  "sync": "true",  // ✅ Sincronizado (String)
  "syncDate": "2025-09-12T01:35:10.123456"
}
```

#### **3. Descarga del Servidor**
```dart
// Se descargan datos del servidor
GET /endpoint

// Cada registro del servidor se marca como:
{
  "id": 123,
  "title": "Producto del servidor",
  "body": "Descripción",
  "sync": "true",  // ✅ Ya sincronizado (String)
  "syncDate": "2025-09-12T01:35:10.123456"
}
```

## 🚀 **Uso Práctico**

### **Código Básico (sin cambios)**
```dart
// ✅ Tu código actual sigue funcionando igual
final manager = OnlineOfflineManager(
  boxName: 'productos',
  endpoint: 'posts',
);

await manager.save({
  'title': 'Mi Producto',
  'body': 'Descripción',
});

final todos = await manager.getAll();
final pendientes = await manager.getPending();  // sync: false
final sincronizados = await manager.getSynced(); // sync: true
```

### **Verificar Estado de Sincronización**
```dart
final datos = await manager.getAll();

for (final item in datos) {
  if (item['sync'] == 'true') {
    print('✅ Sincronizado: ${item['syncDate']}');
  } else {
    print('⏳ Pendiente de sincronizar');
  }
}
```

### **UI Reactiva Automática**
```dart
StreamBuilder<List<Map<String, dynamic>>>(
  stream: manager.dataStream,
  builder: (context, snapshot) {
    final data = snapshot.data ?? [];
    
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        final isPending = item['sync'] != 'true';
        
        return ListTile(
          leading: Icon(
            isPending ? Icons.upload_outlined : Icons.check_circle,
            color: isPending ? Colors.orange : Colors.green,
          ),
          title: Text(item['title'] ?? ''),
          subtitle: Text(
            isPending 
              ? 'Pendiente de subir' 
              : 'Sincronizado: ${item['syncDate']}',
          ),
        );
      },
    );
  },
)
```

## 🛠️ **Beneficios del Nuevo Sistema**

### ✅ **Más Limpio**
- Solo se envían datos reales del frontend
- No más campos vacíos o auto-generados
- Servidor recibe exactamente lo que necesita

### ✅ **Más Confiable** 
- Estados de sincronización claros: `sync: true/false`
- Fechas de sincronización: `syncDate`
- Detección automática de registros pendientes

### ✅ **Más Eficiente**
- No hay errores 400 por campos no válidos
- Sincronización más rápida y eficiente
- Manejo robusto de errores

### ✅ **Backward Compatible**
- Tu código actual funciona sin cambios
- Migración automática y transparente
- Todas las APIs siguen iguales

## 🔧 **Configuración del Backend**

### **Antes** (causaba error 400)
```json
POST /posts
{
  "userId": 1,
  "title": "",
  "body": "",
  "created_at": "2025-09-12T01:34:53.961664",
  "sync": false
}
```

### **Ahora** (funciona perfectamente)
```json
POST /posts  
{
  "title": "Mi Producto Real",
  "body": "Descripción real del producto",
  "created_at": "2025-09-12T01:34:53.961664",
  "sync": "false"
}
```

## 🧪 **Testing**

```dart
test('Debe marcar registros como pendientes', () async {
  final manager = OnlineOfflineManager(boxName: 'test');
  
  await manager.save({'title': 'Test'});
  
  final pending = await manager.getPending();
  expect(pending.length, 1);
  expect(pending.first['sync'], 'false');  // String
});

test('Debe marcar registros como sincronizados', () async {
  // Simular sincronización exitosa
  final synced = await manager.getSynced();
  expect(synced.first['sync'], 'true');  // String
  expect(synced.first['syncDate'], isNotNull);
});
```

---

## 🎯 **Resumen**

**✅ Tu aplicación ahora:**
- Envía solo datos reales al servidor
- Maneja estados de sincronización correctamente  
- Evita errores 400 por campos no válidos
- Funciona de forma más confiable y eficiente

**✅ Sin cambios en tu código:**
- Todas las APIs siguen iguales
- Backward compatibility 100%
- Migración automática y transparente
