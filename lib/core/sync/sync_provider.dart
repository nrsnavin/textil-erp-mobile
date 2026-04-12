import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../database/app_database.dart';
import '../database/daos/sync_queue_dao.dart';
import '../repository/orders_repository.dart';
import '../repository/inventory_repository.dart';
import '../storage/secure_storage.dart';
import 'connectivity_monitor.dart';
import 'sync_queue_service.dart';
import 'background_sync.dart';

// Re-export for backward compatibility
export 'sync_queue_service.dart' show SyncStatus, SyncPhase;

const _uuid = Uuid();
const _defaultBaseUrl = 'http://10.0.2.2:3008';

// ── Database provider ───────────────────────────────────────────────────

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

// ── Legacy MutationDb provider (backward compat) ────────────────────────

final mutationDbProvider = Provider<AppDatabase>((ref) {
  return ref.watch(appDatabaseProvider);
});

// ── Sync Queue Service provider ─────────────────────────────────────────

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final connectivity = ref.watch(connectivityMonitorProvider);
  final storage = ref.watch(secureStorageProvider);

  final service = SyncQueueService(
    dao: db.syncQueue,
    connectivity: connectivity,
    getBaseUrl: () => _defaultBaseUrl,
    getAccessToken: () => storage.getAccessToken(),
  );

  ref.onDispose(() => service.dispose());
  return service;
});

// Legacy alias
final syncEngineProvider = Provider<SyncQueueService>((ref) {
  return ref.watch(syncQueueServiceProvider);
});

// ── Background sync scheduler ───────────────────────────────────────────

final backgroundSyncProvider = Provider<BackgroundSyncScheduler>((ref) {
  final service = ref.watch(syncQueueServiceProvider);

  final scheduler = BackgroundSyncScheduler(
    config: const BackgroundSyncConfig(),
    onSync: () => service.flush(),
  );

  ref.onDispose(() => scheduler.dispose());
  return scheduler;
});

// ── Sync Status stream ──────────────────────────────────────────────────

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncQueueServiceProvider);
  return service.statusStream;
});

final currentSyncStatusProvider = Provider<SyncStatus>((ref) {
  final asyncStatus = ref.watch(syncStatusProvider);
  return asyncStatus.when(
    data: (status) => status,
    loading: () => const SyncStatus(),
    error: (_, __) => const SyncStatus(phase: SyncPhase.error),
  );
});

final pendingMutationCountProvider = Provider<int>((ref) {
  final status = ref.watch(currentSyncStatusProvider);
  return status.pendingCount + status.syncingCount;
});

// ── Offline mutation helper ─────────────────────────────────────────────

/// Helper class that wraps API calls with offline support.
/// When online, calls the API directly. When offline, enqueues
/// the mutation for later sync.
class OfflineMutationHelper {
  final ApiClient _api;
  final SyncQueueService _syncService;
  final ConnectivityMonitor _connectivity;

  OfflineMutationHelper({
    required ApiClient api,
    required SyncQueueService syncService,
    required ConnectivityMonitor connectivity,
  })  : _api = api,
        _syncService = syncService,
        _connectivity = connectivity;

  /// Execute a mutation. If online, calls the API directly.
  /// If offline, enqueues for later sync.
  ///
  /// Returns the API response data if online, or null if queued.
  Future<Map<String, dynamic>?> mutate({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    SyncPriority priority = SyncPriority.normal,
  }) async {
    if (_connectivity.isOnline) {
      try {
        final response = await _callApi(endpoint, method, body);
        return response;
      } catch (e) {
        // API call failed — enqueue for retry
        await _syncService.enqueue(
          endpoint: endpoint,
          method: method,
          body: body,
          priority: priority,
        );
        return null;
      }
    }

    // Offline: enqueue the mutation
    await _syncService.enqueue(
      endpoint: endpoint,
      method: method,
      body: body,
      priority: priority,
    );
    return null;
  }

  Future<Map<String, dynamic>?> _callApi(
    String endpoint,
    String method,
    Map<String, dynamic>? body,
  ) async {
    final response = switch (method) {
      'POST' => await _api.post(endpoint, data: body),
      'PATCH' => await _api.patch(endpoint, data: body),
      'PUT' => await _api.put(endpoint, data: body),
      'DELETE' => await _api.delete(endpoint),
      _ => throw ArgumentError('Unsupported method: $method'),
    };
    return response.data as Map<String, dynamic>?;
  }
}

final offlineMutationHelperProvider = Provider<OfflineMutationHelper>((ref) {
  return OfflineMutationHelper(
    api: ref.watch(apiClientProvider),
    syncService: ref.watch(syncQueueServiceProvider),
    connectivity: ref.watch(connectivityMonitorProvider),
  );
});

// ── Repository providers ────────────────────────────────────────────────

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(
    api: ref.watch(apiClientProvider),
    dao: ref.watch(appDatabaseProvider).orders,
    connectivity: ref.watch(connectivityMonitorProvider),
  );
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(
    api: ref.watch(apiClientProvider),
    dao: ref.watch(appDatabaseProvider).inventory,
    connectivity: ref.watch(connectivityMonitorProvider),
  );
});
