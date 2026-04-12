import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/daos/sync_queue_dao.dart';
import 'connectivity_monitor.dart';

const _uuid = Uuid();

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

/// Sync engine state for the UI.
enum SyncPhase { idle, syncing, error }

class SyncStatus {
  final SyncPhase phase;
  final int pendingCount;
  final int syncingCount;
  final int failedCount;
  final int deadCount;
  final int totalFlushed;
  final int batchSize;
  final String? lastError;
  final DateTime? lastSyncAt;

  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.syncingCount = 0,
    this.failedCount = 0,
    this.deadCount = 0,
    this.totalFlushed = 0,
    this.batchSize = 0,
    this.lastError,
    this.lastSyncAt,
  });

  bool get hasPending => pendingCount > 0 || syncingCount > 0;
  bool get isAllSynced => pendingCount == 0 && syncingCount == 0 && failedCount == 0 && deadCount == 0;

  SyncStatus copyWith({
    SyncPhase? phase,
    int? pendingCount,
    int? syncingCount,
    int? failedCount,
    int? deadCount,
    int? totalFlushed,
    int? batchSize,
    String? lastError,
    DateTime? lastSyncAt,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    pendingCount: pendingCount ?? this.pendingCount,
    syncingCount: syncingCount ?? this.syncingCount,
    failedCount: failedCount ?? this.failedCount,
    deadCount: deadCount ?? this.deadCount,
    totalFlushed: totalFlushed ?? this.totalFlushed,
    batchSize: batchSize ?? this.batchSize,
    lastError: lastError ?? this.lastError,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
  );
}

// ── SyncQueueService ──────────────────────────────────────────────────────

/// Orchestrates offline mutation sync with priority, exponential backoff,
/// and Dart Isolate-based network I/O.
///
/// ## Features over the original SyncEngine:
///
/// 1. **Priority ordering**: Critical mutations sync before normal ones
/// 2. **Exponential backoff**: Failed mutations wait 2s → 4s → 8s → 16s → 32s
/// 3. **Dead-letter queue**: After max retries, mutations move to dead state
/// 4. **Backoff-aware claiming**: Only claims mutations past their retry window
/// 5. **Background sync support**: Designed to work with workmanager
///
/// ## Concurrency safety (preserved from SyncEngine):
///
/// 1. Completer lock prevents concurrent flushes
/// 2. Atomic SQLite transaction prevents double-pickup
/// 3. Crash recovery resets stuck "syncing" → "pending"
/// 4. Server-side clientId dedup prevents server duplicates
/// 5. Debounced connectivity prevents rapid-fire flush attempts
class SyncQueueService {
  final SyncQueueDao _dao;
  final ConnectivityMonitor _connectivity;
  final String Function() _getBaseUrl;
  final Future<String?> Function() _getAccessToken;

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = const SyncStatus();

  Completer<void>? _flushLock;
  Timer? _debounceTimer;
  Timer? _backoffTimer;
  StreamSubscription? _connectivitySub;

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get currentStatus => _currentStatus;

  SyncQueueService({
    required SyncQueueDao dao,
    required ConnectivityMonitor connectivity,
    required String Function() getBaseUrl,
    required Future<String?> Function() getAccessToken,
  })  : _dao = dao,
        _connectivity = connectivity,
        _getBaseUrl = getBaseUrl,
        _getAccessToken = getAccessToken;

  /// Initialize: recover crashes, start connectivity listener, initial flush.
  Future<void> initialize() async {
    final recovered = await _dao.recoverStuck();
    if (recovered > 0) {
      debugPrint('[SyncQueue] Recovered $recovered stuck mutations');
    }

    await _refreshCounts();

    _connectivitySub = _connectivity.statusStream.listen((status) {
      if (status == NetworkStatus.online) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
          flush();
        });
      }
    });

    if (_connectivity.isOnline && _currentStatus.hasPending) {
      flush();
    }

    // Schedule periodic check for backoff-ready mutations
    _backoffTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_connectivity.isOnline && _currentStatus.pendingCount > 0) {
        flush();
      }
    });
  }

  /// Enqueue a mutation with optional priority.
  Future<void> enqueue({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    SyncPriority priority = SyncPriority.normal,
  }) async {
    await _dao.enqueue(SyncQueueEntry(
      clientId: _uuid.v4(),
      endpoint: endpoint,
      method: method,
      body: body,
      priority: priority,
    ));
    await _refreshCounts();

    if (_connectivity.isOnline) {
      flush();
    }
  }

  /// Flush pending mutations to server.
  Future<void> flush() async {
    if (_flushLock != null && !_flushLock!.isCompleted) {
      await _flushLock!.future;
      final remaining = await _dao.getPendingCount();
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

  Future<void> _doFlush() async {
    if (!_connectivity.isOnline) return;

    final token = await _getAccessToken();
    if (token == null) return;

    // Claim only mutations that are past their backoff window
    final batch = await _dao.claimBatch(limit: 50);
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
      final result = await Isolate.run(() => _flushToServer(
        baseUrl: _getBaseUrl(),
        accessToken: token,
        mutations: batch.map((e) => e.toSyncPayload()).toList(),
      ));

      if (result.syncedClientIds.isNotEmpty) {
        await _dao.markSynced(result.syncedClientIds);
      }
      if (result.failedClientIds.isNotEmpty) {
        await _dao.markFailed(
          result.failedClientIds,
          result.error ?? 'Server error',
        );
      }

      await _refreshCounts();

      // Schedule next batch if more pending
      if (_currentStatus.pendingCount > 0 && _connectivity.isOnline) {
        Timer(const Duration(milliseconds: 100), () => flush());
      }
    } catch (e) {
      debugPrint('[SyncQueue] Flush error: $e');

      final clientIds = batch.map((e) => e.clientId).toList();
      await _dao.markFailed(clientIds, e.toString());
      await _refreshCounts();

      _emitStatus(_currentStatus.copyWith(
        phase: SyncPhase.error,
        lastError: e.toString(),
      ));
    }
  }

  Future<void> _refreshCounts() async {
    final counts = await _dao.getCounts();
    final pending = counts[QueueStatus.pending] ?? 0;
    final syncing = counts[QueueStatus.syncing] ?? 0;
    final failed = counts[QueueStatus.failed] ?? 0;
    final dead = counts[QueueStatus.dead] ?? 0;

    final phase = syncing > 0
        ? SyncPhase.syncing
        : (dead > 0 || failed > 0 ? SyncPhase.error : SyncPhase.idle);

    _emitStatus(SyncStatus(
      phase: phase,
      pendingCount: pending,
      syncingCount: syncing,
      failedCount: failed,
      deadCount: dead,
      lastSyncAt: (pending == 0 && syncing == 0 && failed == 0 && dead == 0)
          ? DateTime.now()
          : _currentStatus.lastSyncAt,
    ));
  }

  void _emitStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  /// Get dead-letter entries for manual inspection.
  Future<List<SyncQueueEntry>> getDeadLetters() => _dao.getDeadLetters();

  /// Retry all dead-letter entries.
  Future<void> retryDeadLetters() async {
    await _dao.retryDeadLetters();
    await _refreshCounts();
    if (_connectivity.isOnline) flush();
  }

  void dispose() {
    _debounceTimer?.cancel();
    _backoffTimer?.cancel();
    _connectivitySub?.cancel();
    _statusController.close();
  }
}

// ── Isolate-safe flush function ───────────────────────────────────────────

Future<FlushResult> _flushToServer({
  required String baseUrl,
  required String accessToken,
  required List<Map<String, dynamic>> mutations,
}) async {
  if (mutations.isEmpty) {
    return FlushResult(syncedCount: 0, syncedClientIds: [], failedClientIds: []);
  }

  final client = HttpClient();
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
