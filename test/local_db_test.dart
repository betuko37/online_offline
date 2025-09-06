import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_offline_sync/flutter_offline_sync.dart';

void main() {
  group('Pruebas de LocalDB con múltiples tablas', () {
    test('debería crear LocalDB con nombre de base de datos', () {
      final localDB = LocalDB(databaseName: 'test_db');
      expect(localDB.databaseName, 'test_db');
    });

    test('debería verificar que no hay tablas inicialmente', () {
      final localDB = LocalDB(databaseName: 'test_db');
      expect(localDB.getTables().isEmpty, true);
    });

    test('debería verificar que una tabla no existe inicialmente', () {
      final localDB = LocalDB(databaseName: 'test_db');
      expect(localDB.tableExists('usuarios'), false);
    });

    test('debería retornar null para tabla inexistente', () {
      final localDB = LocalDB(databaseName: 'test_db');
      expect(localDB.get('usuarios', 'user_1'), null);
    });

    test('debería retornar mapa vacío para tabla inexistente', () {
      final localDB = LocalDB(databaseName: 'test_db');
      expect(localDB.getAll('usuarios').isEmpty, true);
    });

    test('debería retornar 0 para tamaño de tabla inexistente', () {
      final localDB = LocalDB(databaseName: 'test_db');
      expect(localDB.getTableSize('usuarios'), 0);
    });

    test('debería retornar false para clave inexistente', () {
      final localDB = LocalDB(databaseName: 'test_db');
      expect(localDB.containsKey('usuarios', 'user_1'), false);
    });

    test('debería retornar lista vacía para claves de tabla inexistente', () {
      final localDB = LocalDB(databaseName: 'test_db');
      expect(localDB.getKeys('usuarios').isEmpty, true);
    });

    test('debería retornar lista vacía para valores de tabla inexistente', () {
      final localDB = LocalDB(databaseName: 'test_db');
      expect(localDB.getValues('usuarios').isEmpty, true);
    });

  });
}
