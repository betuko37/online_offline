import 'package:flutter_test/flutter_test.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() {
  group('LocalStorage Tests', () {
    late LocalStorage storage;

    setUp(() async {
      storage = LocalStorage(boxName: 'test_box_${DateTime.now().millisecondsSinceEpoch}');
      await storage.initialize();
    });

    tearDown(() async {
      await storage.clear();
      await storage.close();
    });

    test('should initialize successfully', () async {
      final testStorage = LocalStorage(boxName: 'init_test');
      await testStorage.initialize();
      await testStorage.close();
    });

    test('should save and retrieve data', () async {
      final testData = {'name': 'John', 'age': 30, 'active': true};
      
      await storage.save('user1', testData);
      final retrieved = await storage.get('user1');
      
      expect(retrieved, isNotNull);
      expect(retrieved!['name'], 'John');
      expect(retrieved['age'], 30);
      expect(retrieved['active'], true);
    });

    test('should return null for non-existent key', () async {
      final result = await storage.get('non_existent_key');
      expect(result, isNull);
    });

    test('should save multiple items and get all', () async {
      await storage.save('item1', {'id': 1, 'name': 'Item 1'});
      await storage.save('item2', {'id': 2, 'name': 'Item 2'});
      await storage.save('item3', {'id': 3, 'name': 'Item 3'});

      final allItems = await storage.getAll();
      expect(allItems.length, 3);
      
      final names = allItems.map((item) => item['name']).toList();
      expect(names, contains('Item 1'));
      expect(names, contains('Item 2'));
      expect(names, contains('Item 3'));
    });

    test('should get all keys', () async {
      await storage.save('key1', {'data': 'value1'});
      await storage.save('key2', {'data': 'value2'});

      final keys = await storage.getKeys();
      expect(keys.length, 2);
      expect(keys, contains('key1'));
      expect(keys, contains('key2'));
    });

    test('should delete items', () async {
      await storage.save('to_delete', {'data': 'test'});
      
      bool exists = await storage.contains('to_delete');
      expect(exists, true);

      await storage.delete('to_delete');
      
      exists = await storage.contains('to_delete');
      expect(exists, false);
    });

    test('should clear all data', () async {
      await storage.save('item1', {'data': 'test1'});
      await storage.save('item2', {'data': 'test2'});

      int length = await storage.length();
      expect(length, 2);

      await storage.clear();

      length = await storage.length();
      expect(length, 0);
    });

    test('should filter data with where clause', () async {
      await storage.save('user1', {'name': 'John', 'age': 25, 'active': true});
      await storage.save('user2', {'name': 'Jane', 'age': 17, 'active': true});
      await storage.save('user3', {'name': 'Bob', 'age': 30, 'active': false});

      // Filtrar usuarios adultos (>= 18)
      final adults = await storage.where((item) => item['age'] >= 18);
      expect(adults.length, 2);

      // Filtrar usuarios activos
      final active = await storage.where((item) => item['active'] == true);
      expect(active.length, 2);

      // Filtrar usuarios adultos activos
      final activeAdults = await storage.where((item) => 
        item['age'] >= 18 && item['active'] == true);
      expect(activeAdults.length, 1);
      expect(activeAdults.first['name'], 'John');
    });

    test('should handle complex data structures', () async {
      final complexData = {
        'user': {
          'id': 123,
          'profile': {
            'name': 'John Doe',
            'email': 'john@example.com',
            'preferences': {
              'theme': 'dark',
              'notifications': true,
            }
          }
        },
        'posts': [
          {'id': 1, 'title': 'First Post'},
          {'id': 2, 'title': 'Second Post'},
        ],
        'metadata': {
          'created_at': '2025-09-14T10:00:00Z',
          'version': '2.0.0',
        }
      };

      await storage.save('complex_data', complexData);
      final retrieved = await storage.get('complex_data');

      expect(retrieved, isNotNull);
      expect(retrieved!['user']['id'], 123);
      expect(retrieved['user']['profile']['name'], 'John Doe');
      expect(retrieved['posts'].length, 2);
      expect(retrieved['posts'][0]['title'], 'First Post');
      expect(retrieved['metadata']['version'], '2.0.0');
    });

    test('should check if key exists', () async {
      await storage.save('test_key', {'data': 'test'});

      bool exists = await storage.contains('test_key');
      expect(exists, true);

      exists = await storage.contains('non_existent');
      expect(exists, false);
    });

    test('should return correct length', () async {
      int length = await storage.length();
      expect(length, 0);

      await storage.save('item1', {'data': 'test1'});
      length = await storage.length();
      expect(length, 1);

      await storage.save('item2', {'data': 'test2'});
      length = await storage.length();
      expect(length, 2);

      await storage.delete('item1');
      length = await storage.length();
      expect(length, 1);
    });
  });
}