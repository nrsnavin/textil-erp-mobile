import 'dart:convert';
import 'package:sqflite/sqflite.dart';

/// Priority levels for sync queue entries.
/// Higher value = higher priority = synced first.
enum SyncPriority {
  low(0),       // Background data refresh
  normal(1),    // Standard CRUD mutations
  high(2),      // User-initiated actions needing fast feedback
  critical(3);  // Payment, status transitions — must sync ASAP

  final int value;
  const SyncPriority(this.value);

  static SyncPriority fromValue(int v) => switch (v) {
    0 => SyncPriority.low,
    2 => SyncPriority.high,
    3 => SyncPriority.critical,
    _ => SyncPriority.normal,
  };
}

/// Status enum for sync queue entries.
enum QueueStatus {
  pending(0),
  syncing(1),
  synced(2),
  failed(3),
  dead(4);   // Exceeded max retries — needs manual intervention

  final int value;
  const QueueStatus(this.value);

  static QueueStatus fromValue(int v) => switch (v) {
    1 => QueueStatus.syncing,
    2 => QueueStatus.synced,
    3 => QueueStatus.failed,
    4 => QueueStatus.dead,
    _ => QueueStatus.pending,
  };
}

/// A single sync queue entry.
class SyncQueueEntry {
  final int? id;
  final String clientId;
  final String endpoint;
  final String method;
  final Map<String, dynamic>? body;
  final SyncPriority priority;
  final QueueStatus status;
  final int retryCount;
  final int maxRetries;
  final DateTime? nextRetryAt;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;

  SyncQueueEntry({
    this.id,
    required this.clientId,
    required this.endpoint,
    required this.method,
    this.body,
    this.priority = SyncPriority.normal,
    this.status = QueueStatus.pending,
    this.retryCount = 0,
    this.maxRetries = 5,
    this.nextRetryAt,
    this.errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'client_id': clientId,
    'endpoint': endpoint,
    'method': method,
    'body': body != null ? jsonEncode(body) : null,
    'priority': priority.value,
    'status': status.value,
    'retry_count': retryCount,
    'max_retries': maxRetries,
    'next_retry_at': nextRetryAt?.toIso8601String(),
    'error_message': errorMessage,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'synced_at': syncedAt?.toIso8601String(),
  };

  factory SyncQueueEntry.fromMap(Map<String, dynamic> m) => SyncQueueEntry(
    id: m['id'] as int?,
    clientId: m['client_id'] as String,
    endpoint: m['endpoint'] as String,
    method: m['method'] as String,
    body: m['body'] != null ? jsonDecode(m['body'] as String) as Map<String, dynamic> : null,
    priority: SyncPriority.fromValue(m['priority'] as int? ?? 1),
    status: QueueStatus.fromValue(m['status'] as int? ?? 0),
    retryCount: m['retry_count'] as int? ?? 0,
    maxRetries: m['max_retries'] as int? ?? 5,
    nextRetryAt: m['next_retry_at'] != null ? DateTime.parse(m['next_retry_at'] as String) : null,
    errorMessage: m['error_message'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
    updatedAt: DateTime.parse(m['updated_at'] as String),
    syncedAt: m['synced_at'] != null ? DateTime.parse(m['synced_at'] as String) : null,
  );

  /// Serialize for the server's /api/v1/sync/push endpoint.
  Map<String, dynamic> toSyncPayload() => {
    'clientId': clientId,
    'endpoint': endpoint,
    'method': method,
    if (body != null) 'body': body,
  };

  SyncQueueEntry copyWith({
    int? id,
    QueueStatus? status,
    int? retryCount,
    DateTime? nextRetryAt,
    String? errorMessage,
    DateTime? updatedAt,
  }) => SyncQueueEntry(
    id: id ?? this.id,
    clientId: clientId,
    endpoint: endpoint,
    method: method,
    body: body,
    priority: priority,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    maxRetries: maxRetries,
    nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    errorMessage: errorMessage ?? this.errorMessage,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    syncedAt: syncedAt,
  );

  @override
  String toString() =>
      'SyncQueueEntry(id=$id, clientId=$clientId, $method $endpoint, '
      'priority=${priority.name}, status=${status.name}, retries=$retryCount)';
}

// ── DAO ────────────────────────────────────────────────────────────────────

/// Typed DAO for the sync_queue table.
///
/// Provides atomic batch claiming, priority-ordered retrieval,
/// exponential backoff scheduling, and dead-letter detection.
class SyncQueueDao {
  static const _table = 'sync_queue';
  final Database _db;

  SyncQueueDao(this._db);

  /// Enqueue a new mutation. INSERT OR IGNORE prevents duplicate clientIds.
  Future<int> enqueue(SyncQueueEntry entry) {
    return _db.insert(
      _table,
      entry.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Enqueue a batch of mutations in a single transaction.
  Future<void> enqueueBatch(List<SyncQueueEntry> entries) {
    return _db.transaction((txn) async {
      final batch = txn.batch();
      for (final entry in entries) {
        batch.insert(
          _table,
          entry.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Get entries ready to sync: pending + past their retry backoff window.
  /// Ordered by priority DESC (critical first), then created_at ASC (FIFO).
  Future<List<SyncQueueEntry>> getReady({int limit = 50}) async {
    final now = DateTime.now().toIso8601String();
    final rows = await _db.query(
      _table,
      where: 'status = ? AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [QueueStatus.pending.value, now],
      orderBy: 'priority DESC, created_at ASC',
      limit: limit,
    );
    return rows.map(SyncQueueEntry.fromMap).toList();
  }

  /// Atomically claim a batch for syncing.
  /// Uses a transaction to SELECT + UPDATE, preventing double-pickup.
  Future<List<SyncQueueEntry>> claimBatch({int limit = 50}) async {
    final now = DateTime.now().toIso8601String();
    return _db.transaction((txn) async {
      final rows = await txn.query(
        _table,
        where: 'status = ? AND (next_retry_at IS NULL OR next_retry_at <= ?)',
        whereArgs: [QueueStatus.pending.value, now],
        orderBy: 'priority DESC, created_at ASC',
        limit: limit,
      );

      if (rows.isEmpty) return <SyncQueueEntry>[];

      final entries = rows.map(SyncQueueEntry.fromMap).toList();
      final ids = entries.map((e) => e.id).toList();

      await txn.rawUpdate(
        'UPDATE $_table SET status = ?, updated_at = ? WHERE id IN (${ids.join(",")})',
        [QueueStatus.syncing.value, now],
      );

      return entries.map((e) => e.copyWith(status: QueueStatus.syncing)).toList();
    });
  }

  /// Mark entries as synced and delete them from the queue.
  Future<void> markSynced(List<String> clientIds) async {
    if (clientIds.isEmpty) return;
    final placeholders = clientIds.map((_) => '?').join(',');
    await _db.delete(
      _table,
      where: 'client_id IN ($placeholders)',
      whereArgs: clientIds,
    );
  }

  /// Mark entries as failed with exponential backoff scheduling.
  ///
  /// Backoff formula: `min(2^retryCount * 2, 300)` seconds.
  /// Retries: 2s → 4s → 8s → 16s → 32s → 64s → 128s → 256s → 300s (cap)
  ///
  /// After [maxRetries] (default 5), status moves to [QueueStatus.dead].
  Future<void> markFailed(List<String> clientIds, String error) async {
    if (clientIds.isEmpty) return;
    final now = DateTime.now();
    final placeholders = clientIds.map((_) => '?').join(',');

    // Two-phase: first read current state, then update with computed backoff
    await _db.transaction((txn) async {
      final rows = await txn.query(
        _table,
        columns: ['id', 'client_id', 'retry_count', 'max_retries'],
        where: 'client_id IN ($placeholders)',
        whereArgs: clientIds,
      );

      for (final row in rows) {
        final retryCount = (row['retry_count'] as int) + 1;
        final maxRetries = row['max_retries'] as int;
        final id = row['id'] as int;

        if (retryCount >= maxRetries) {
          // Dead letter — exceeded max retries
          await txn.update(
            _table,
            {
              'status': QueueStatus.dead.value,
              'retry_count': retryCount,
              'error_message': error,
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          // Schedule retry with exponential backoff
          final backoffSeconds = _backoffSeconds(retryCount);
          final nextRetry = now.add(Duration(seconds: backoffSeconds));

          await txn.update(
            _table,
            {
              'status': QueueStatus.pending.value,
              'retry_count': retryCount,
              'next_retry_at': nextRetry.toIso8601String(),
              'error_message': error,
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    });
  }

  /// Exponential backoff: min(2^retry * 2, 300) seconds.
  static int _backoffSeconds(int retryCount) {
    final seconds = (1 << retryCount) * 2; // 2, 4, 8, 16, 32, 64, ...
    return seconds > 300 ? 300 : seconds;
  }

  /// Recover mutations stuck in "syncing" state (crash recovery).
  Future<int> recoverStuck() async {
    return _db.rawUpdate(
      'UPDATE $_table SET status = ?, updated_at = ? WHERE status = ?',
      [QueueStatus.pending.value, DateTime.now().toIso8601String(), QueueStatus.syncing.value],
    );
  }

  /// Count entries by status.
  Future<Map<QueueStatus, int>> getCounts() async {
    final rows = await _db.rawQuery(
      'SELECT status, COUNT(*) as cnt FROM $_table GROUP BY status',
    );
    final counts = <QueueStatus, int>{};
    for (final s in QueueStatus.values) {
      counts[s] = 0;
    }
    for (final row in rows) {
      final status = QueueStatus.fromValue(row['status'] as int);
      counts[status] = row['cnt'] as int;
    }
    return counts;
  }

  /// Total actionable count (pending + syncing).
  Future<int> getPendingCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_table WHERE status IN (?, ?)',
      [QueueStatus.pending.value, QueueStatus.syncing.value],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get dead-letter entries for manual inspection/retry.
  Future<List<SyncQueueEntry>> getDeadLetters() async {
    final rows = await _db.query(
      _table,
      where: 'status = ?',
      whereArgs: [QueueStatus.dead.value],
      orderBy: 'created_at ASC',
    );
    return rows.map(SyncQueueEntry.fromMap).toList();
  }

  /// Retry dead-letter entries (reset to pending with fresh retry count).
  Future<int> retryDeadLetters([List<String>? clientIds]) async {
    if (clientIds != null && clientIds.isEmpty) return 0;
    final now = DateTime.now().toIso8601String();

    if (clientIds == null) {
      return _db.rawUpdate(
        'UPDATE $_table SET status = ?, retry_count = 0, next_retry_at = NULL, updated_at = ? WHERE status = ?',
        [QueueStatus.pending.value, now, QueueStatus.dead.value],
      );
    }

    final placeholders = clientIds.map((_) => '?').join(',');
    return _db.rawUpdate(
      'UPDATE $_table SET status = ?, retry_count = 0, next_retry_at = NULL, updated_at = ? '
      'WHERE status = ? AND client_id IN ($placeholders)',
      [QueueStatus.pending.value, now, QueueStatus.dead.value, ...clientIds],
    );
  }

  /// Prune synced/dead entries older than [days].
  Future<int> prune({int days = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    return _db.delete(
      _table,
      where: 'status IN (?, ?) AND updated_at < ?',
      whereArgs: [QueueStatus.synced.value, QueueStatus.dead.value, cutoff],
    );
  }

  /// Delete all entries (for testing / logout).
  Future<void> clearAll() async {
    await _db.delete(_table);
  }
}
