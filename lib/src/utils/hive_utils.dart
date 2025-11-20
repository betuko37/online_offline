import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../storage/local_storage.dart';

/// Utilidades para gestionar boxes Hive
class HiveUtils {
  HiveUtils._();

  /// Obtiene una lista de todas las boxes Hive abiertas
  /// 
  /// Retorna una lista con los nombres de todas las boxes que están actualmente abiertas
  /// Útil para debugging y para resetear todas las boxes
  static List<String> getOpenBoxes() {
    // Hive no expone directamente una lista de boxes abiertas
    // Necesitamos usar un enfoque diferente: intentar acceder a boxes conocidas
    // o usar reflexión si está disponible
    
    // Por ahora, retornamos una lista vacía ya que Hive no tiene una API pública
    // para listar todas las boxes abiertas
    // En su lugar, usaremos un método alternativo
    return [];
  }

  /// Obtiene información de todas las boxes Hive abiertas
  /// 
  /// Este método detecta automáticamente todas las boxes:
  /// 1. Boxes registradas por LocalStorage (las que se abrieron a través de OnlineOfflineManager)
  /// 2. Boxes abiertas actualmente en Hive
  /// 3. Boxes encontradas en el sistema de archivos
  /// 4. La caja de caché `_cache_metadata`
  /// 
  /// Ya no necesitas proporcionar los nombres manualmente.
  static Future<List<HiveBoxInfo>> getAllOpenBoxesInfo({
    List<String>? knownBoxNames,
  }) async {
    final List<HiveBoxInfo> boxesInfo = [];
    final Set<String> processedBoxes = {}; // Para evitar duplicados
    
    // Paso 1: Obtener boxes registradas por LocalStorage
    final registeredBoxes = LocalStorage.registeredBoxes;
    
    // Paso 2: Obtener boxes del sistema de archivos
    final fileSystemBoxes = await _getBoxesFromFileSystem();
    
    // Paso 3: Combinar todas las fuentes
    final allBoxNames = <String>{}
      ..addAll(registeredBoxes)
      ..addAll(fileSystemBoxes)
      ..addAll(knownBoxNames ?? [])
      ..add('_cache_metadata'); // Siempre incluir caché
    
    // Paso 4: Verificar cada box
    for (final boxName in allBoxNames) {
      if (processedBoxes.contains(boxName)) continue;
      processedBoxes.add(boxName);
      
      if (Hive.isBoxOpen(boxName)) {
        try {
          final box = Hive.box(boxName);
          boxesInfo.add(HiveBoxInfo(
            name: boxName,
            isOpen: true,
            recordCount: box.length,
          ));
        } catch (e) {
          boxesInfo.add(HiveBoxInfo(
            name: boxName,
            isOpen: true,
            recordCount: 0,
            error: e.toString(),
          ));
        }
      } else {
        // Verificar si existe en el sistema de archivos aunque no esté abierta
        final exists = await _boxExistsOnDisk(boxName);
        boxesInfo.add(HiveBoxInfo(
          name: boxName,
          isOpen: false,
          recordCount: 0,
          existsOnDisk: exists,
        ));
      }
    }
    
    return boxesInfo;
  }
  
  /// Obtiene boxes desde el sistema de archivos
  static Future<Set<String>> _getBoxesFromFileSystem() async {
    final Set<String> boxes = {};
    
    try {
      // Obtener directorio de aplicación
      final appDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory('${appDir.path}/hive');
      
      if (await hiveDir.exists()) {
        // Buscar archivos .hive y .lock
        await for (final entity in hiveDir.list()) {
          if (entity is File) {
            final fileName = entity.path.split('/').last;
            // Los archivos de Hive tienen extensión .hive o .lock
            if (fileName.endsWith('.hive') || fileName.endsWith('.lock')) {
              // Extraer nombre de la box (sin extensión)
              final boxName = fileName.replaceAll('.hive', '').replaceAll('.lock', '');
              if (boxName.isNotEmpty) {
                boxes.add(boxName);
              }
            }
          }
        }
      }
    } catch (e) {
      // Si hay error al leer el sistema de archivos, continuar sin esas boxes
      print('⚠️ Error al leer boxes del sistema de archivos: $e');
    }
    
    return boxes;
  }
  
  /// Verifica si una box existe en el disco
  static Future<bool> _boxExistsOnDisk(String boxName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final hiveFile = File('${appDir.path}/hive/$boxName.hive');
      return await hiveFile.exists();
    } catch (e) {
      return false;
    }
  }

  /// Cierra todas las boxes Hive abiertas
  /// 
  /// Cierra todas las boxes que están actualmente abiertas
  /// Detecta automáticamente todas las boxes abiertas
  static Future<void> closeAllBoxes() async {
    // Obtener todas las boxes abiertas automáticamente
    final boxesInfo = await getAllOpenBoxesInfo();
    final boxesToClose = boxesInfo
        .where((box) => box.isOpen)
        .map((box) => box.name)
        .toList();
    
    // Cerrar todas las boxes
    for (final boxName in boxesToClose) {
      if (Hive.isBoxOpen(boxName)) {
        try {
          final box = Hive.box(boxName);
          await box.close();
          print('✅ Caja "$boxName" cerrada');
        } catch (e) {
          print('⚠️ Error al cerrar caja "$boxName": $e');
        }
      }
    }
  }

  /// Elimina todas las boxes Hive del disco
  /// 
  /// Detecta automáticamente todas las boxes y las elimina del disco
  /// También limpia la caja de caché completa
  static Future<void> deleteAllBoxes({
    bool includeCacheBox = true,
  }) async {
    // Obtener todas las boxes automáticamente
    final boxesInfo = await getAllOpenBoxesInfo();
    final allBoxNames = boxesInfo.map((box) => box.name).toSet().toList();
    
    print('🗑️ Eliminando ${allBoxNames.length} caja(s) del disco...');
    
    // Cerrar todas las boxes primero
    await closeAllBoxes();
    
    // Eliminar todas las boxes
    for (final boxName in allBoxNames) {
      // Si no queremos incluir caché, saltarla
      if (!includeCacheBox && boxName == '_cache_metadata') {
        continue;
      }
      
      try {
        await Hive.deleteBoxFromDisk(boxName);
        print('✅ Caja "$boxName" eliminada del disco');
      } catch (e) {
        print('⚠️ Error al eliminar caja "$boxName": $e');
      }
    }
    
    print('✅ Eliminación de cajas completada');
  }

  /// Resetea completamente todas las boxes Hive
  /// 
  /// Detecta automáticamente todas las boxes y las resetea:
  /// 1. Cierra todas las boxes abiertas
  /// 2. Limpia el contenido de todas las boxes
  /// 3. Elimina todas las boxes del disco
  /// 4. Limpia la caja de caché completa
  /// 
  /// Útil para un reset completo de la aplicación
  static Future<void> resetAllBoxes({
    bool includeCacheBox = true,
  }) async {
    print('🔄 Iniciando reset completo de todas las boxes...');
    
    // Obtener todas las boxes automáticamente
    final boxesInfo = await getAllOpenBoxesInfo();
    final allBoxNames = boxesInfo.map((box) => box.name).toSet().toList();
    
    // Paso 1: Cerrar todas las boxes
    await closeAllBoxes();
    
    // Paso 2: Limpiar contenido de boxes antes de eliminar
    for (final boxName in allBoxNames) {
      // Si no queremos incluir caché, saltarla
      if (!includeCacheBox && boxName == '_cache_metadata') {
        continue;
      }
      
      try {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          await box.clear();
          print('✅ Contenido de "$boxName" limpiado');
        }
      } catch (e) {
        print('⚠️ Error al limpiar caja "$boxName": $e');
      }
    }
    
    // Paso 3: Eliminar todas las boxes del disco
    await deleteAllBoxes(includeCacheBox: includeCacheBox);
    
    print('✅ Reset completo de todas las boxes finalizado');
  }
}

/// Información de una caja Hive
class HiveBoxInfo {
  final String name;
  final bool isOpen;
  final int recordCount;
  final String? error;
  final bool? existsOnDisk;

  HiveBoxInfo({
    required this.name,
    required this.isOpen,
    required this.recordCount,
    this.error,
    this.existsOnDisk,
  });

  @override
  String toString() {
    if (error != null) {
      return 'HiveBoxInfo(name: $name, isOpen: $isOpen, error: $error)';
    }
    final diskInfo = existsOnDisk != null 
        ? (existsOnDisk! ? ', existsOnDisk: true' : ', existsOnDisk: false')
        : '';
    return 'HiveBoxInfo(name: $name, isOpen: $isOpen, recordCount: $recordCount$diskInfo)';
  }
}

