import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'mutation.dart';
import 'mutation_db.dart';
import 'connectivity_monitor.dart';

/// Sync engine state exposed to the UI via Riverpod.
enum SyncPhase { idle, syncing, error }

class SyncStatus {
  final SyncPhase phase;
  final int pendingCount;
  final int syncingCount;
  final int failedCount;
  final int totalFlushed;   // Mutations flushed in current batch
  final int batchSize;      // Total mutations in current batch
  final String? lastError;
  final DateTime? lastSyncAt;

  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.syncingCount = 0,
    this.failedCount = 0,
    this.totalFlushed = 0,
    this.batchSize = 0,
    this.lastError,
    this.lastSyncAt,
  });

  bool get hasPending => pendingCount > 0 || syncingCount > 0;
  bool get isAllSynced => pendingCount == 0 && syncingCount == 0 && failedCount == 0;

  SyncStatus copyWith({
    SyncPhase? phase,
    int? pendingCount,
    int? syncingCount,
    int? failedCount,
    int? totalFlushed,
    int? batchSize,
    String? lastError,
    DateTime? lastSyncAt,
  }) {
    return SyncStatus(
      phase: phase ?? this.phase,
      pendingCount: pendingCount ?? this.pendingCount,
      syncingCount: syncingCount ?? this.syncingCount,
      failedCount: failedCount ?? this.failedCount,
      totalFlushed: totalFlushed ?? this.totalFlushed,
      batchSize: batchSize ?? this.batchSize,
      lastError: lastError ?? this.lastError,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

/// Result from the flush isolate.
class FlushResult {
  final int syncedCount;
  final List<String> syncedClientIds;
  final List<String> failedClientIds;
  final String? error;

  FlushResult({
    required this.syncedCount,
    required this.syncedClientIds,
    required this.failedClientIds,
    this.error,
  });
}

// ── SyncEngine ────────────────────────────────────────────────────────────

/// Orchestrates offline mutation sync using Dart Isolates.
///
/// ## Concurrency bugs fixed (the subtle issues):
///
/// 1. **Double-flush prevention**: Uses [_flushLock] Completer to ensure
///    only one flush runs at a time. If connectivity changes fire rapidly
///    (WiFi toggle), subsequent flush requests wait for the current one.
///
/// 2. **Atomic claim**: [MutationDb.claimBatch] uses a SQLite transaction
///    to atomically SELECT + UPDATE status to "syncing". This prevents
///    two flush calls from picking up the same mutations.
///
/// 3. **Crash recovery**: On startup, [recoverFromCrash] resets any
///    mutations stuck in "syncing" state back to "pending". This handles
///    the case where the app was killed while mutations were being sent.
///    The server's idempotency (clientId dedup) ensures no duplicates
///    even if the mutation was actually delivered before the crash.
///
/// 4. **Isolate lifecycle**: Uses [Isolate.run] for one-shot network work.
///    The isolate exits after the HTTP call completes. This avoids
///    long-lived isolate state and port-leak issues.
///
/// 5. **Server-side idempotency**: Each mutation carries a client-generated
///    UUID. The server's /api/v1/sync/push endpoint deduplicates by clientId.
///    Even if a mutation is sent twice, the server returns "duplicate".
///
/// 6. **Debounced connectivity**: Network transitions can fire rapidly.
///    The engine debounces flush triggers by 1.5s to let the connection
///    stabilize. This prevents wasted HTTP attempts on flaky networks.
class SyncEngine {
  final MutationDb _db;
  final ConnectivityMonitor _connectivity;
  final String Function() _getBaseUrl;
  final Future<String?> Function() _getAccessToken;

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = const SyncStatus();

  /// Lock to prevent concurrent flushes.
  Completer<void>? _flushLock;

  /// Debounce timer for connectivity-triggered flushes.
  Timer? _debounceTimer;

  StreamSubscription? _connectivitySub;

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get currentStatus => _currentStatus;

  SyncEngine({
    required MutationDb db,
    required ConnectivityMonitor connectivity,
    required String Function() getBaseUrl,
    required Future<String?> Function() getAccessToken,
  })  : _db = db,
        _connectivity = connectivity,
        _getBaseUrl = getBaseUrl,
        _getAccessToken = getAccessToken;

  /// Initialize the sync engine.
  /// - Recovers stuck mutations from a previous crash
  /// - Starts listening for connectivity changes
  /// - Triggers an initial flush if online with pending work
  Future<void> initialize() async {
    // ── CRASH RECOVERY ──
    // Reset mutations stuck in "syncing" from a previous app kill.
    // These were claimed for sending when the app was killed.
    // Server idempotency (clientId) handles the case where they
    // were actually delivered — the server returns "duplicate".
    final recovered = await _db.recoverStuckMutations();
    if (recovered > 0) {
      debugPrint('[SyncEngine] Recovered $recovered stuck mutations');
    }

    await _refreshCounts();

    // Listen for connectivity changes to auto-trigger flush.
    _connectivitySub = _connectivity.statusStream.listen((status) {
      if (status == NetworkStatus.online) {
        // ── DEBOUNCE ──
        // Connectivity can flip WiFi→mobile→WiFi rapidly.
        // Wait 1.5s for the connection to stabilize.
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
          flush();
        });
      }
    });

    // Initial flush if online and there are pending mutations.
    if (_connectivity.isOnline && _currentStatus.hasPending) {
      flush();
    }
  }

  /// Enqueue a mutation for offline sync.
  /// Called from the main thread when user performs a create/update/delete.
  Future<void> enqueue(Mutation mutation) async {
    await _db.enqueue(mutation);
    await _refreshCounts();

    if (_connectivity.isOnline) {
      flush();
    }
  }

  /// Trigger a flush of pending mutations to the server.
  ///
  /// ## Double-flush prevention:
  /// If a flush is already in progress, this awaits its completion
  /// then checks if there's remaining work. The [_flushLock] Completer
  /// serializes all concurrent callers.
  Future<void> flush() async {
    // ── DOUBLE-FLUSH GUARD ──
    // If another flush is running, wait for it.
    if (_flushLock != null && !_flushLock!.isCompleted) {
      await _flushLock!.future;
      // Check if there's still work after the previous flush.
      final remaining = await _db.getPendingCount();
      if (remaining == 0) return;
    }

    _flushLock = Completer<void>();

    try {
      await _doFlush();
    } finally {
      if (!_flushLock!.isCompleted) {
        _flushLock!.complete();
      }
    }
  }

  /// Core flush logic. Claims a batch, sends via isolate, processes results.
  Future<void> _doFlush() async {
    if (!_connectivity.isOnline) return;

    final token = await _getAccessToken();
    if (token == null) return;

    // ── ATOMIC CLAIM ──
    // SQLite transaction: SELECT pending → UPDATE to syncing.
    // Even if two flush() calls slip through the Completer lock
    // (theoretically impossible, but defense-in-depth), the DB
    // transaction ensures each mutation is claimed only once.
    final batch = await _db.claimBatch(limit: 50);
    if (batch.isEmpty) {
      await _refreshCounts();
      return;
    }

    _emitStatus(_currentStatus.copyWith(
      phase: SyncPhase.syncing,
      syncingCount: batch.length,
      batchSize: batch.length,
      totalFlushed: 0,
    ));

    try {
      // Run the HTTP call in a separate isolate so the UI stays fluid.
      // Isolate.run() spawns a short-lived isolate that exits when done.
      final result = await Isolate.run(() => _flushToServer(
        baseUrl: _getBaseUrl(),
        accessToken: token,
        mutations: batch.map((m) => m.toSyncPayload()).toList(),
      ));

      // ── PROCESS RESULTS ON MAIN ISOLATE ──
      // All DB writes happen here, not in the network isolate.
      // This avoids SQLite write contention between isolates.
      if (result.syncedClientIds.isNotEmpty) {
        await _db.markSynced(result.syncedClientIds);
      }
      if (result.failedClientIds.isNotEmpty) {
        await _db.markFailed(
          result.failedClientIds,
          result.error ?? 'Server error',
        );
      }

      await _refreshCounts();

      // If there are more pending mutations, schedule the next batch.
      // Uses Timer to avoid deep recursion and allow the UI to breathe.
      if (_currentStatus.pendingCount > 0 && _connectivity.isOnline) {
        Timer(const Duration(milliseconds: 100), () => flush());
      }
    } catch (e) {
      debugPrint('[SyncEngine] Flush error: $e');

      // On error, mark claimed mutations as failed (increments retry count).
      // After 5 retries they stay in "failed" state for manual inspection.
      final clientIds = batch.map((m) => m.clientId).toList();
      await _db.markFailed(clientIds, e.toString());
      await _refreshCounts();

      _emitStatus(_currentStatus.copyWith(
        phase: SyncPhase.error,
        lastError: e.toString(),
      ));
    }
  }

  /// Refresh mutation counts from DB and emit updated status.
  Future<void> _refreshCounts() async {
    final counts = await _db.getCounts();
    final pending = counts[MutationStatus.pending] ?? 0;
    final syncing = counts[MutationStatus.syncing] ?? 0;
    final failed = counts[MutationStatus.failed] ?? 0;

    final phase = syncing > 0
        ? SyncPhase.syncing
        : (failed > 0 ? SyncPhase.error : SyncPhase.idle);

    _emitStatus(SyncStatus(
      phase: phase,
      pendingCount: pending,
      syncingCount: syncing,
      failedCount: failed,
      lastSyncAt: (pending == 0 && syncing == 0 && failed == 0)
          ? DateTime.now()
          : _currentStatus.lastSyncAt,
    ));
  }

  void _emitStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  void dispose() {
    _debounceTimer?.cancel();
    _connectivitySub?.cancel();
    _statusController.close();
  }
}

// ── Isolate-safe flush function ───────────────────────────────────────────
//
// This function runs inside Isolate.run(). It must be a top-level or
// static function. It uses dart:io HttpClient directly because:
// - Dio depends on Flutter engine initialization (not available in isolate)
// - dart:io is available in Flutter mobile isolates
// - The function is stateless — receives data in, returns data out.

Future<FlushResult> _flushToServer({
  required String baseUrl,
  required String accessToken,
  required List<Map<String, dynamic>> mutations,
}) async {
  if (mutations.isEmpty) {
    return FlushResult(
      syncedCount: 0,
      syncedClientIds: [],
      failedClientIds: [],
    );
  }

  final client = HttpClient();
  // 30s timeout for the entire batch
  client.connectionTimeout = const Duration(seconds: 30);

  try {
    final uri = Uri.parse('$baseUrl/api/v1/sync/push');
    final request = await client.postUrl(uri);

    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Authorization', 'Bearer $accessToken');
    request.write(jsonEncode({'mutations': mutations}));

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 400) {
      // Server error — mark all as failed for retry
      return FlushResult(
        syncedCount: 0,
        syncedClientIds: [],
        failedClientIds: mutations.map((m) => m['clientId'] as String).toList(),
        error: 'HTTP ${response.statusCode}: $body',
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final results = (json['results'] as List<dynamic>?) ?? [];

    final syncedIds = <String>[];
    final failedIds = <String>[];

    for (final r in results) {
      final result = r as Map<String, dynamic>;
      final clientId = result['clientId'] as String;
      final status = result['status'] as String;

      // Both "applied" and "duplicate" mean the server has it — safe to delete locally
      if (status == 'applied' || status == 'duplicate') {
        syncedIds.add(clientId);
      } else {
        failedIds.add(clientId);
      }
    }

    return FlushResult(
      syncedCount: syncedIds.length,
      syncedClientIds: syncedIds,
      failedClientIds: failedIds,
    );
  } on SocketException catch (e) {
    // Network unreachable — mark all for retry
    return FlushResult(
      syncedCount: 0,
      syncedClientIds: [],
      failedClientIds: mutations.map((m) => m['clientId'] as String).toList(),
      error: 'Network error: ${e.message}',
    );
  } catch (e) {
    return FlushResult(
      syncedCount: 0,
      syncedClientIds: [],
      failedClientIds: mutations.map((m) => m['clientId'] as String).toList(),
      error: e.toString(),
    );
  } finally {
    client.close();
  }
}
