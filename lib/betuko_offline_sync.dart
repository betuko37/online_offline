/// Betuko Offline Sync - Ultra-simple offline-first package for Flutter
///
/// ## Quick Start
///
/// ```dart
/// // 1. Configure once at app start
/// GlobalConfig.init(
///   baseUrl: 'https://your-api.com',
///   token: 'your-token',
/// );
///
/// // 2. Create a manager
/// final reports = OnlineOfflineManager(
///   boxName: 'reports',
///   endpoint: '/api/reports',
/// );
///
/// // 3. Use it!
/// final data = await reports.get();     // Always returns local data (instant)
/// await reports.save({'title': 'New'}); // Save locally
/// await OnlineOfflineManager.syncAll(); // Sync when user wants
/// ```
///
/// ## Key Concepts
///
/// - `get()` always returns local data instantly
/// - `syncAll()` syncs all managers with server
/// - User controls when to sync
///
/// ## Check Sync Status
///
/// ```dart
/// final data = await reports.getFullData();
/// print('Synced: ${data.syncedCount}');
/// print('Pending: ${data.pendingCount}');
/// ```
library;

// Main manager - This is all you need
export 'src/online_offline_manager.dart';

// Global configuration
export 'src/config/global_config.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ADVANCED (optional)
// ═══════════════════════════════════════════════════════════════════════════

// HTTP client
export 'src/api/api_client.dart';

// Local storage
export 'src/storage/local_storage.dart';

// Sync service
export 'src/sync/sync_service.dart';

// Connectivity service
export 'src/connectivity/connectivity_service.dart';

// Sync status enum
export 'src/models/sync_status.dart';

// Hive utilities
export 'src/utils/hive_utils.dart';

// Cache manager
export 'src/cache/cache_manager.dart';
