import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../storage/secure_storage.dart';
import 'connectivity_monitor.dart';
import 'mutation.dart';
import 'mutation_db.dart';
import 'sync_engine.dart';

const _uuid = Uuid();
const _defaultBaseUrl = 'http://10.0.2.2:3008';

// ── Mutation DB provider ──────────────────────────────────────────────────

final mutationDbProvider = Provider<MutationDb>((ref) {
  return MutationDb.instance;
});

// ── Sync Engine provider ──────────────────────────────────────────────────

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(mutationDbProvider);
  final connectivity = ref.watch(connectivityMonitorProvider);
  final storage = ref.watch(secureStorageProvider);

  final engine = SyncEngine(
    db: db,
    connectivity: connectivity,
    getBaseUrl: () => _defaultBaseUrl,
    getAccessToken: () => storage.getAccessToken(),
  );

  ref.onDispose(() => engine.dispose());
  return engine;
});

// ── Sync Status stream provider ───────────────────────────────────────────

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.statusStream;
});

// ── Current sync status (synchronous snapshot) ────────────────────────────

final currentSyncStatusProvider = Provider<SyncStatus>((ref) {
  final asyncStatus = ref.watch(syncStatusProvider);
  return asyncStatus.when(
    data: (status) => status,
    loading: () => const SyncStatus(),
    error: (_, __) => const SyncStatus(phase: SyncPhase.error),
  );
});

// ── Pending count provider (for badge counts) ─────────────────────────────

final pendingMutationCountProvider = Provider<int>((ref) {
  final status = ref.watch(currentSyncStatusProvider);
  return status.pendingCount + status.syncingCount;
});

// ── Offline mutation helper ───────────────────────────────────────────────

/// Helper class that wraps API calls with offline support.
/// When online, it calls the API directly. When offline, it enqueues
/// the mutation for later sync and returns immediately.
class OfflineMutationHelper {
  final ApiClient _api;
  final SyncEngine _syncEngine;
  final ConnectivityMonitor _connectivity;

  OfflineMutationHelper({
    required ApiClient api,
    required SyncEngine syncEngine,
    required ConnectivityMonitor connectivity,
  })  : _api = api,
        _syncEngine = syncEngine,
        _connectivity = connectivity;

  /// Execute a mutation. If online, call the API directly.
  /// If offline, enqueue for later sync.
  ///
  /// Returns the API response data if online, or null if queued.
  Future<Map<String, dynamic>?> mutate({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
  }) async {
    final clientId = _uuid.v4();

    if (_connectivity.isOnline) {
      try {
        // Try the direct API call first
        final response = await _callApi(endpoint, method, body);
        return response;
      } catch (e) {
        // If the API call fails (network glitch), enqueue for retry
        await _syncEngine.enqueue(Mutation(
          clientId: clientId,
          endpoint: endpoint,
          method: method,
          body: body,
        ));
        return null;
      }
    }

    // Offline: enqueue the mutation
    await _syncEngine.enqueue(Mutation(
      clientId: clientId,
      endpoint: endpoint,
      method: method,
      body: body,
    ));
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
    syncEngine: ref.watch(syncEngineProvider),
    connectivity: ref.watch(connectivityMonitorProvider),
  );
});
