// ═══════════════════════════════════════════════════════════════════════════
// BETUKO OFFLINE SYNC - API SIMPLIFICADA
// ═══════════════════════════════════════════════════════════════════════════
//
// USO BÁSICO:
// 
// 1. Configurar (una vez):
//    GlobalConfig.init(baseUrl: 'https://api.com', token: 'tu-token');
//
// 2. Crear manager:
//    final manager = OnlineOfflineManager(boxName: 'datos', endpoint: '/api/datos');
//
// 3. Usar:
//    final datos = await manager.get();    // Siempre retorna datos locales
//    await manager.save({'key': 'value'}); // Guarda localmente
//    await OnlineOfflineManager.syncAll(); // Sincroniza con servidor
//
// ═══════════════════════════════════════════════════════════════════════════

// Gestor principal - Esto es todo lo que necesitas
export 'src/online_offline_manager.dart';

// Configuración global
export 'src/config/global_config.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SERVICIOS AVANZADOS (opcional)
// ═══════════════════════════════════════════════════════════════════════════

// Cliente HTTP
export 'src/api/api_client.dart';

// Almacenamiento local
export 'src/storage/local_storage.dart';

// Servicio de sincronización
export 'src/sync/sync_service.dart';

// Servicio de conectividad
export 'src/connectivity/connectivity_service.dart';

// Estados de sincronización
export 'src/models/sync_status.dart';

// Utilidades Hive
export 'src/utils/hive_utils.dart';

// Gestor de caché
export 'src/cache/cache_manager.dart';

