import 'package:betuko_offline_sync/betuko_offline_sync.dart';

/// Ejemplo de sincronización automática con timer
void main() async {
  print('🚀 Ejemplo de sincronización automática');
  
  // Configuración para datos que cambian frecuentemente
  final manager = OnlineOfflineManager(
    boxName: 'seasons',
    endpoint: 'https://api.ejemplo.com/seasons',
    syncConfig: SyncConfig.frequent, // Sincroniza cada minuto
  );
  
  print('\n📱 Obteniendo datos...');
  
  // Primera llamada - puede sincronizar si es necesario
  final data1 = await manager.getAllWithSync();
  print('Datos obtenidos: ${data1.length}');
  
  // Esperar un poco para simular el uso
  await Future.delayed(Duration(seconds: 30));
  
  // Segunda llamada - debería usar caché si no ha pasado 1 minuto
  final data2 = await manager.getAllWithSync();
  print('Datos obtenidos: ${data2.length}');
  
  // Esperar más tiempo para que se active el timer
  print('\n⏰ Esperando 2 minutos para que se active la sincronización automática...');
  await Future.delayed(Duration(minutes: 2));
  
  // Tercera llamada - debería sincronizar automáticamente
  final data3 = await manager.getAllWithSync();
  print('Datos obtenidos: ${data3.length}');
  
  // Limpiar recursos
  manager.dispose();
  
  print('\n✅ Ejemplo completado');
}

/// Ejemplo de uso en un servicio
class SeasonService {
  static final SeasonService _instance = SeasonService._internal();
  factory SeasonService() => _instance;
  SeasonService._internal();

  OnlineOfflineManager? _manager;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;

    try {
      _manager = OnlineOfflineManager(
        boxName: 'seasons',
        endpoint: 'apps/paletization/utilities/seasons',
        syncConfig: SyncConfig.frequent, // Sincroniza cada minuto automáticamente
      );
      _isInitialized = true;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllSeasons() async {
    try {
      if (!_isInitialized) {
        initialize();
      }

      if (_manager == null) {
        throw Exception('SeasonService no inicializado correctamente');
      }

      // Usar getAllWithSync() para activar la sincronización automática
      final rawData = await _manager!.getAllWithSync();

      return rawData.where((item) => item['isActive'] == true).toList();
    } catch (e) {
      throw Exception('Error al cargar temporadas: $e');
    }
  }

  void dispose() {
    _manager?.dispose();
    _isInitialized = false;
  }
}
