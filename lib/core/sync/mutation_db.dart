import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'mutation.dart';

/// SQLite-backed mutation queue with crash-safe guarantees.
///
/// Key design decisions:
/// - WAL mode for concurrent read/write (isolate reads while main thread writes)
/// - Mutations ordered by created_at ASC to preserve user intent
/// - Status column uses integer enum for fast filtering
/// - `client_id` has a UNIQUE constraint to prevent duplicate enqueue
///   (covers the case where the app restarts mid-enqueue)
class MutationDb {
  static const _dbName = 'sync_queue.db';
  static const _tableName = 'mutations';
  static const _version = 1;

  Database? _db;
  final Completer<void> _initCompleter = Completer<void>();
  bool _initialized = false;

  /// Singleton access. Call [initialize] before using any other method.
  static final MutationDb instance = MutationDb._();
  MutationDb._();

  /// For testing: injectable constructor that accepts a pre-opened database.
  MutationDb.forTesting(Database db) {
    _db = db;
    _initialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbName);
    _db = await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onConfigure: (db) async {
        // WAL mode: allows concurrent reads from isolate while main thread writes
        await db.execute('PRAGMA journal_mode=WAL');
        // Synchronous NORMAL: good balance of durability vs performance
        await db.execute('PRAGMA synchronous=NORMAL');
      },
    );
    _initialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
  }

  Future<void> _waitForInit() => _initCompleter.future;

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id     TEXT    NOT NULL UNIQUE,
        endpoint      TEXT    NOT NULL,
        method        TEXT    NOT NULL,
        body          TEXT,
        status        INTEGER NOT NULL DEFAULT 0,
        retry_count   INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        created_at    TEXT    NOT NULL,
        synced_at     TEXT
      )
    ''');
    // Index for the hot query: fetch pending mutations in order
    await db.execute('''
      CREATE INDEX idx_mutations_status_created
      ON $_tableName (status, created_at ASC)
    ''');
    // Index for dedup lookups by client_id
    await db.execute('''
      CREATE INDEX idx_mutations_client_id
      ON $_tableName (client_id)
    ''');
  }

  /// Enqueue a new mutation. Returns the inserted row ID.
  /// If a mutation with the same clientId already exists, this is a no-op
  /// (INSERT OR IGNORE) to prevent duplicates from app restart.
  Future<int> enqueue(Mutation mutation) async {
    await _waitForInit();
    return _db!.insert(
      _tableName,
      mutation.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Get all pending mutations ordered by creation time.
  /// This is the read path used by the sync isolate.
  Future<List<Mutation>> getPending({int limit = 100}) async {
    await _waitForInit();
    final rows = await _db!.query(
      _tableName,
      where: 'status = ?',
      whereArgs: [MutationStatus.pending.index],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(Mutation.fromMap).toList();
  }

  /// Atomically claim a batch of pending mutations for syncing.
  /// This prevents double-flush: once claimed, no other isolate can pick them up.
  ///
  /// Returns the claimed mutations. Uses a transaction to ensure atomicity.
  Future<List<Mutation>> claimBatch({int limit = 50}) async {
    await _waitForInit();
    return _db!.transaction((txn) async {
      // Select pending mutations
      final rows = await txn.query(
        _tableName,
        where: 'status = ?',
        whereArgs: [MutationStatus.pending.index],
        orderBy: 'created_at ASC',
        limit: limit,
      );

      if (rows.isEmpty) return <Mutation>[];

      final mutations = rows.map(Mutation.fromMap).toList();
      final ids = mutations.map((m) => m.id).toList();

      // Atomically mark them as syncing
      await txn.rawUpdate(
        'UPDATE $_tableName SET status = ? WHERE id IN (${ids.join(",")})',
        [MutationStatus.syncing.index],
      );

      return mutations.map((m) => m.copyWith(status: MutationStatus.syncing)).toList();
    });
  }

  /// Mark mutations as synced (server acknowledged).
  /// Deletes them from the queue to keep it lean.
  Future<void> markSynced(List<String> clientIds) async {
    await _waitForInit();
    if (clientIds.isEmpty) return;
    final placeholders = clientIds.map((_) => '?').join(',');
    await _db!.delete(
      _tableName,
      where: 'client_id IN ($placeholders)',
      whereArgs: clientIds,
    );
  }

  /// Mark mutations as failed. Increments retry count.
  /// After 5 retries, mutations stay in failed state for manual inspection.
  Future<void> markFailed(List<String> clientIds, String error) async {
    await _waitForInit();
    if (clientIds.isEmpty) return;
    final placeholders = clientIds.map((_) => '?').join(',');
    await _db!.rawUpdate(
      '''UPDATE $_tableName
         SET status = CASE
               WHEN retry_count >= 4 THEN ${MutationStatus.failed.index}
               ELSE ${MutationStatus.pending.index}
             END,
             retry_count = retry_count + 1,
             error_message = ?
         WHERE client_id IN ($placeholders)''',
      [error, ...clientIds],
    );
  }

  /// Reset any mutations stuck in "syncing" state back to "pending".
  /// This handles the crash-during-sync scenario: on app restart,
  /// we reset any in-flight mutations so they get retried.
  ///
  /// CRITICAL for preventing data loss: if the app was killed while
  /// mutations were being sent, they could be stuck in "syncing" forever.
  Future<int> recoverStuckMutations() async {
    await _waitForInit();
    return _db!.rawUpdate(
      'UPDATE $_tableName SET status = ? WHERE status = ?',
      [MutationStatus.pending.index, MutationStatus.syncing.index],
    );
  }

  /// Count mutations by status. Used by the SyncStatusBar.
  Future<Map<MutationStatus, int>> getCounts() async {
    await _waitForInit();
    final rows = await _db!.rawQuery(
      'SELECT status, COUNT(*) as cnt FROM $_tableName GROUP BY status',
    );
    final counts = <MutationStatus, int>{};
    for (final status in MutationStatus.values) {
      counts[status] = 0;
    }
    for (final row in rows) {
      final status = MutationStatus.values[row['status'] as int];
      counts[status] = row['cnt'] as int;
    }
    return counts;
  }

  /// Total pending + syncing count (mutations not yet confirmed by server).
  Future<int> getPendingCount() async {
    await _waitForInit();
    final result = await _db!.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_tableName WHERE status IN (?, ?)',
      [MutationStatus.pending.index, MutationStatus.syncing.index],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get the database path for the sync isolate.
  /// The isolate needs to open its own connection to the same database.
  Future<String> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, _dbName);
  }

  /// Delete all mutations (for testing / logout).
  Future<void> clearAll() async {
    await _waitForInit();
    await _db!.delete(_tableName);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
