# Changelog

Todos los cambios notables de este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2025-09-07

### 🐛 Corrección Crítica
- **ConnectivityService**: Corregido para funcionar correctamente en dispositivos reales
- **Detección de Test**: Mejorada la detección de entornos de test vs dispositivos reales
- **Conectividad Real**: Ahora detecta correctamente la conectividad en emuladores y dispositivos físicos

---

## [1.0.1] - 2025-09-07

### 🔧 Mejoras y Correcciones
- **ConnectivityService**: Mejorado para funcionar en entornos de test
- **Tests**: Todos los 36 tests pasan exitosamente
- **Documentación**: README actualizado y más directo
- **Inicialización Automática**: Hive se inicializa automáticamente
- **Compatibilidad**: Mejor compatibilidad con diferentes entornos

---

## [1.0.0] - 2025-09-07

### 🚀 Primera Versión Pública
- **Nombre del paquete**: `betuko_offline_sync` - Librería Flutter offline-first
- **LICENSE**: Archivo de licencia MIT agregado
- **Validación completa**: Todos los errores de pub.dev resueltos
- **Documentación**: README completo con ejemplos prácticos
- **Tests**: 36 tests pasando exitosamente
- **Arquitectura simplificada**: Fácil de usar y mantener

### ✨ Agregado
- **OnlineOfflineManager**: Gestor principal simplificado
- **LocalStorageService**: Almacenamiento local automático con Hive
- **ConnectivityService**: Detección de conectividad en tiempo real
- **SyncService**: Sincronización automática bidireccional
- **ApiClient**: Cliente HTTP integrado para comunicación con servidor
- **GlobalConfig**: Configuración global de baseUrl y token
- **Streams Reactivos**: UI que se actualiza automáticamente
- **Autosync Siempre Activado**: Sincronización automática por defecto
- **Inicialización Automática de Hive**: Sin configuración manual
- **Tests Completos**: Cobertura completa de funcionalidades

### 🔧 Características Técnicas
- **Offline-First**: Funciona completamente sin conexión
- **Sincronización Automática**: Se activa cuando hay internet
- **Configuración Global**: baseUrl y token se configuran una sola vez
- **Hive Automático**: Se inicializa automáticamente cuando se necesita
- **Streams Reactivos**: UI se actualiza automáticamente con cambios
- **Manejo de Errores**: Sistema robusto de manejo de errores
- **Compatibilidad con Tests**: Funciona en entornos de test sin plugins
- **PostgreSQL Ready**: Optimizado para bases de datos PostgreSQL

### 🛡️ Sincronización Inteligente
- **Sincronización Automática**: En save(), getAll(), delete()
- **Detección de Internet**: Sincroniza cuando se detecta conexión
- **Reintentos Automáticos**: Si falla, reintenta automáticamente
- **Conflictos Resueltos**: El servidor siempre tiene prioridad
- **Metadatos de Sincronización**: _local_id y _synced_at incluidos

### 📱 Compatibilidad
- **Flutter**: >=3.10.0
- **Dart**: >=3.0.0
- **Android**: API 21+
- **iOS**: 11.0+
- **Web**: Compatible
- **Desktop**: Windows, macOS, Linux

### 🧪 Testing
- **Cobertura**: 36 tests pasando exitosamente
- **Tests Unitarios**: Todos los componentes principales
- **Tests de Integración**: Flujos completos de sincronización
- **Tests de Conectividad**: Manejo de estados offline/online
- **Tests de Hive**: Inicialización automática verificada
- **Tests de API**: Comunicación con servidor verificada

### 📚 Documentación
- **README Completo**: Guía de instalación y uso
- **Ejemplos Prácticos**: Casos de uso reales con código
- **API Reference**: Documentación completa de métodos
- **Configuración del Backend**: Ejemplos en Node.js + Prisma
- **Streams Reactivos**: Ejemplos de UI automática
- **Troubleshooting**: Solución de problemas comunes

### 🔄 Dependencias
- **hive**: ^2.2.3 - Base de datos local
- **hive_flutter**: ^1.1.0 - Integración con Flutter
- **http**: ^1.2.0 - Requests HTTP
- **connectivity_plus**: ^6.0.5 - Detección de conectividad
- **flutter**: ^3.10.0 - Framework Flutter

### 🚀 Rendimiento
- **Inicialización Rápida**: <100ms en dispositivos modernos
- **Sincronización Eficiente**: Solo datos modificados
- **Memoria Optimizada**: Gestión eficiente de recursos
- **Batería Amigable**: Sincronización inteligente
- **Hive Automático**: Sin configuración manual

### 🎯 Casos de Uso
- **Apps de Campo**: Agricultura, construcción, ventas móviles
- **Apps Empresariales**: CRM, inventarios, gestión de empleados
- **Apps Médicas**: Consultas, expedientes, datos críticos
- **Apps de Ventas**: E-commerce, catálogos offline
- **Formularios Offline**: Captura de datos sin conexión
- **Inventario**: Control de stock offline

### 🔧 Uso Simplificado
- **3 Líneas para Empezar**: Crear manager, preparar datos, guardar
- **Configuración Global**: Solo una vez en main()
- **Autosync Automático**: No necesitas programar sincronización
- **UI Reactiva**: Streams automáticos para actualización
- **Backend Compatible**: Funciona con cualquier API REST

---

## [0.0.1] - 2025-09-07

### 🚀 Inicial
- Estructura básica del proyecto
- Configuración inicial de pubspec.yaml
- Setup básico de testing
- Estructura de directorios