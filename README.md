# Betuko Offline Sync

[![pub package](https://img.shields.io/pub/v/betuko_offline_sync.svg)](https://pub.dev/packages/betuko_offline_sync)
[![likes](https://img.shields.io/pub/likes/betuko_offline_sync)](https://pub.dev/packages/betuko_offline_sync/score)
[![popularity](https://img.shields.io/pub/popularity/betuko_offline_sync)](https://pub.dev/packages/betuko_offline_sync/score)

**Ultra-simple offline-first package for Flutter.** Your app always works, online or offline.

## ✨ Features

- 🚀 **Super Simple API** - Just `get()`, `save()`, `syncAll()`
- 📱 **Always Fast** - `get()` always returns local data instantly
- 🔄 **Manual Sync** - User decides when to sync with `syncAll()`
- ⚡ **Auto Sync** - Automatically syncs every 10 minutes when online
- 🔌 **Reconnection Sync** - Automatically syncs when internet connection is restored
- 💾 **Auto Storage** - Uses Hive for persistent local storage
- 📊 **Sync Status** - Know exactly what's synced and what's pending
- 🔧 **Debug Tools** - Built-in debugging and reset utilities

## 📦 Installation

```yaml
dependencies:
  betuko_offline_sync: ^3.1.0
```

```bash
flutter pub get
```

## 🚀 Quick Start

### 1. Configure (once at app start)

```dart
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() {
  GlobalConfig.init(
    baseUrl: 'https://your-api.com',
    token: 'your-auth-token',
  );
  runApp(MyApp());
}
```

### 2. Create a Manager

```dart
final reports = OnlineOfflineManager(
  boxName: 'reports',
  endpoint: '/api/reports',
);
```

### 3. Use It!

```dart
// Get data (ALWAYS returns local data - instant!)
final data = await reports.get();

// Save data (stored locally, synced later)
await reports.save({
  'title': 'My Report',
  'date': DateTime.now().toIso8601String(),
});

// Sync with server (when user wants fresh data)
await OnlineOfflineManager.syncAll();
```

## ⚡ Automatic Synchronization

The library automatically syncs your data in two scenarios:

### 1. Periodic Sync (Every 10 minutes)
When your app is online, `syncAll()` is automatically called every 10 minutes to keep your data fresh.

### 2. Reconnection Sync
When the app detects that internet connection is restored (from offline to online), it automatically triggers `syncAll()` to sync any pending data.

**No configuration needed!** This works automatically once you create your first `OnlineOfflineManager`.

```dart
// Just create managers - auto-sync starts automatically!
final reports = OnlineOfflineManager(
  boxName: 'reports',
  endpoint: '/api/reports',
);

// Auto-sync will:
// - Run every 10 minutes when online
// - Run immediately when connection is restored
```

You can still call `syncAll()` manually anytime you want to force a sync.

## 📖 API Reference

### Instance Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `get()` | `List<Map>` | All local data |
| `getSynced()` | `List<Map>` | Only synced data |
| `getPending()` | `List<Map>` | Only pending data |
| `getFullData()` | `FullSyncData` | All data + counts |
| `getSyncInfo()` | `SyncInfo` | Just counts |
| `save(Map data)` | `void` | Save locally |
| `delete(String id)` | `void` | Delete by ID |
| `clear()` | `void` | Clear all data |
| `reset()` | `void` | Clear data + cache |
| `dispose()` | `void` | Release resources |

### Static Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `syncAll()` | `Map<String, SyncResult>` | Sync all managers |
| `getAllSyncInfo()` | `Map<String, SyncInfo>` | Status of all managers |
| `resetAll()` | `void` | Reset everything |
| `debugInfo()` | `void` | Print debug info |
| `getAllBoxesInfo()` | `List<HiveBoxInfo>` | Hive boxes info |
| `getTotalRecordCount()` | `int` | Total records |
| `getTotalPendingCount()` | `int` | Total pending |
| `deleteAllBoxes()` | `void` | Delete from disk |

## 📊 Check Sync Status

### Per Manager

```dart
// Get full data with status
final data = await reports.getFullData();

print('Total: ${data.total}');
print('Synced: ${data.syncedCount}');
print('Pending: ${data.pendingCount}');
print('Percentage: ${data.syncPercentage}%');

// Access the actual data
for (final item in data.synced) {
  print('Synced: ${item['title']}');
}

for (final item in data.pending) {
  print('Pending: ${item['title']}');
}
```

### All Managers

```dart
final allStatus = await OnlineOfflineManager.getAllSyncInfo();

for (final entry in allStatus.entries) {
  print('${entry.key}: ${entry.value.synced}/${entry.value.total}');
}
```

## 🔧 Debug Tools

```dart
// Print complete debug info
await OnlineOfflineManager.debugInfo();

// Output:
// ═══════════════════════════════════════════════════════════
// 📊 DEBUG INFO - OnlineOfflineManager
// ═══════════════════════════════════════════════════════════
// 📦 Managers activos: 2
//    • reports: 150 registros (3 pendientes)
//    • users: 50 registros (0 pendientes)
// 💾 Boxes Hive:
//    • reports: 150 registros (abierta)
//    • users: 50 registros (abierta)
// ⚙️ GlobalConfig:
//    • Inicializado: true
//    • BaseURL: https://api.com
// ═══════════════════════════════════════════════════════════
```

## 🔄 Multiple Managers

```dart
// Create multiple managers
final reports = OnlineOfflineManager(
  boxName: 'reports',
  endpoint: '/api/reports',
);

final users = OnlineOfflineManager(
  boxName: 'users',
  endpoint: '/api/users',
);

final products = OnlineOfflineManager(
  boxName: 'products',
  endpoint: '/api/products',
);

// Sync ALL with one call
final results = await OnlineOfflineManager.syncAll();

for (final entry in results.entries) {
  if (entry.value.success) {
    print('✅ ${entry.key}: synced');
  } else {
    print('❌ ${entry.key}: ${entry.value.error}');
  }
}
```

## 🎯 Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() {
  GlobalConfig.init(
    baseUrl: 'https://api.example.com',
    token: 'your-token',
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final reports = OnlineOfflineManager(
    boxName: 'reports',
    endpoint: '/api/reports',
  );
  
  List<Map<String, dynamic>> data = [];
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final result = await reports.get();
    setState(() => data = result);
  }

  Future<void> _sync() async {
    setState(() => isSyncing = true);
    await OnlineOfflineManager.syncAll();
    await _loadData();
    setState(() => isSyncing = false);
  }

  Future<void> _addReport() async {
    await reports.save({
      'title': 'Report ${DateTime.now().millisecondsSinceEpoch}',
      'date': DateTime.now().toIso8601String(),
    });
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Offline-First App'),
          actions: [
            IconButton(
              icon: isSyncing 
                ? SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(color: Colors.white))
                : Icon(Icons.sync),
              onPressed: isSyncing ? null : _sync,
            ),
          ],
        ),
        body: ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) {
            final item = data[index];
            final isSynced = item['sync'] == 'true';
            
            return ListTile(
              title: Text(item['title'] ?? 'No title'),
              trailing: Icon(
                isSynced ? Icons.cloud_done : Icons.cloud_off,
                color: isSynced ? Colors.green : Colors.orange,
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addReport,
          child: Icon(Icons.add),
        ),
      ),
    );
  }

  @override
  void dispose() {
    reports.dispose();
    super.dispose();
  }
}
```

## 🔐 Update Token

```dart
// After login or token refresh
GlobalConfig.updateToken('new-token');
```

## 🗑️ Reset Everything

```dart
// Reset all data (useful for logout)
await OnlineOfflineManager.resetAll();

// Or delete all boxes from disk
await OnlineOfflineManager.deleteAllBoxes();
```

## 📋 Data Classes

### SyncInfo
```dart
class SyncInfo {
  int total;           // Total records
  int synced;          // Synced records
  int pending;         // Pending records
  double syncPercentage;  // 0-100
  bool isFullySynced;     // true if pending == 0
}
```

### FullSyncData
```dart
class FullSyncData {
  List<Map> all;      // All data
  List<Map> synced;   // Synced data
  List<Map> pending;  // Pending data
  int total;
  int syncedCount;
  int pendingCount;
  double syncPercentage;
  bool isFullySynced;
}
```

### SyncResult
```dart
class SyncResult {
  bool success;
  String? error;
}
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 👨‍💻 Author

**Betuko** - [GitHub](https://github.com/betuko37)

