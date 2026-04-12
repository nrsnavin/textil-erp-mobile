import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:textile_erp_mobile/core/database/daos/sync_queue_dao.dart';

void sqfliteTestInit() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

Future<Database> createTestDb() async {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sync_queue (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id       TEXT    NOT NULL UNIQUE,
            endpoint        TEXT    NOT NULL,
            method          TEXT    NOT NULL,
            body            TEXT,
            priority        INTEGER NOT NULL DEFAULT 1,
            status          INTEGER NOT NULL DEFAULT 0,
            retry_count     INTEGER NOT NULL DEFAULT 0,
            max_retries     INTEGER NOT NULL DEFAULT 5,
            next_retry_at   TEXT,
            error_message   TEXT,
            created_at      TEXT    NOT NULL,
            updated_at      TEXT    NOT NULL,
            synced_at       TEXT
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_sq_status_priority_created
          ON sync_queue (status, priority DESC, created_at ASC)
        ''');
        await db.execute('''
          CREATE INDEX idx_sq_client_id
          ON sync_queue (client_id)
        ''');
        await db.execute('''
          CREATE INDEX idx_sq_next_retry
          ON sync_queue (status, next_retry_at)
        ''');
      },
    ),
  );
}

SyncQueueEntry _entry(String clientId, {
  SyncPriority priority = SyncPriority.normal,
  DateTime? createdAt,
  int maxRetries = 5,
}) => SyncQueueEntry(
  clientId: clientId,
  endpoint: '/api/v1/buyers',
  method: 'POST',
  body: {'name': 'Test'},
  priority: priority,
  maxRetries: maxRetries,
  createdAt: createdAt,
);

void main() {
  sqfliteTestInit();

  late Database db;
  late SyncQueueDao dao;

  setUp(() async {
    db = await createTestDb();
    dao = SyncQueueDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncQueueDao', () {
    // ── Enqueue ──────────────────────────────────────────────────────────

    test('enqueue inserts entry with correct priority', () async {
      await dao.enqueue(_entry('e1', priority: SyncPriority.critical));
      await dao.enqueue(_entry('e2', priority: SyncPriority.low));
      await dao.enqueue(_entry('e3', priority: SyncPriority.normal));

      final ready = await dao.getReady();
      expect(ready.length, 3);
      // Critical first, then normal, then low
      expect(ready[0].clientId, 'e1');
      expect(ready[0].priority, SyncPriority.critical);
      expect(ready[1].clientId, 'e3');
      expect(ready[2].clientId, 'e2');
    });

    test('enqueue ignores duplicate clientId', () async {
      await dao.enqueue(_entry('dup'));
      await dao.enqueue(_entry('dup'));

      final ready = await dao.getReady();
      expect(ready.length, 1);
    });

    test('enqueueBatch inserts multiple entries atomically', () async {
      final entries = List.generate(10, (i) =>
        _entry('batch-$i', createdAt: DateTime(2024, 1, 1, 0, 0, i)));
      await dao.enqueueBatch(entries);

      final ready = await dao.getReady();
      expect(ready.length, 10);
    });

    // ── Priority ordering ────────────────────────────────────────────────

    test('getReady returns entries ordered by priority DESC, created_at ASC', () async {
      await dao.enqueue(_entry('low-old', priority: SyncPriority.low,
          createdAt: DateTime(2024, 1, 1)));
      await dao.enqueue(_entry('normal-old', priority: SyncPriority.normal,
          createdAt: DateTime(2024, 1, 1)));
      await dao.enqueue(_entry('critical-new', priority: SyncPriority.critical,
          createdAt: DateTime(2024, 1, 2)));
      await dao.enqueue(_entry('high-old', priority: SyncPriority.high,
          createdAt: DateTime(2024, 1, 1)));
      await dao.enqueue(_entry('normal-new', priority: SyncPriority.normal,
          createdAt: DateTime(2024, 1, 2)));

      final ready = await dao.getReady();
      expect(ready[0].clientId, 'critical-new'); // Highest priority
      expect(ready[1].clientId, 'high-old');
      expect(ready[2].clientId, 'normal-old');   // Same priority, older first
      expect(ready[3].clientId, 'normal-new');
      expect(ready[4].clientId, 'low-old');
    });

    // ── Atomic claim ─────────────────────────────────────────────────────

    test('claimBatch atomically transitions pending -> syncing', () async {
      for (int i = 0; i < 10; i++) {
        await dao.enqueue(_entry('claim-$i',
            createdAt: DateTime(2024, 1, 1, 0, 0, i)));
      }

      final batch1 = await dao.claimBatch(limit: 5);
      expect(batch1.length, 5);
      expect(batch1.every((e) => e.status == QueueStatus.syncing), true);

      final batch2 = await dao.claimBatch(limit: 5);
      expect(batch2.length, 5);

      // No more pending
      final batch3 = await dao.claimBatch(limit: 5);
      expect(batch3.length, 0);
    });

    test('claimBatch respects priority ordering', () async {
      await dao.enqueue(_entry('low', priority: SyncPriority.low));
      await dao.enqueue(_entry('critical', priority: SyncPriority.critical));
      await dao.enqueue(_entry('normal', priority: SyncPriority.normal));

      final batch = await dao.claimBatch(limit: 2);
      expect(batch.length, 2);
      expect(batch[0].clientId, 'critical');
      expect(batch[1].clientId, 'normal');

      // Low priority still pending
      final batch2 = await dao.claimBatch(limit: 2);
      expect(batch2.length, 1);
      expect(batch2[0].clientId, 'low');
    });

    // ── Mark synced ──────────────────────────────────────────────────────

    test('markSynced deletes entries from queue', () async {
      await dao.enqueue(_entry('s1'));
      await dao.enqueue(_entry('s2'));
      await dao.enqueue(_entry('s3'));

      await dao.markSynced(['s1', 's3']);

      final ready = await dao.getReady();
      expect(ready.length, 1);
      expect(ready[0].clientId, 's2');
    });

    // ── Exponential backoff ──────────────────────────────────────────────

    test('markFailed schedules exponential backoff retry', () async {
      await dao.enqueue(_entry('backoff'));
      await dao.claimBatch(limit: 1);

      // First failure: retry in 2s
      await dao.markFailed(['backoff'], 'Error 1');
      var counts = await dao.getCounts();
      expect(counts[QueueStatus.pending], 1);

      // The entry should have next_retry_at set in the future
      final rows = await db.query('sync_queue', where: 'client_id = ?', whereArgs: ['backoff']);
      final entry = SyncQueueEntry.fromMap(rows.first);
      expect(entry.retryCount, 1);
      expect(entry.nextRetryAt, isNotNull);
      expect(entry.errorMessage, 'Error 1');
    });

    test('markFailed moves to dead after max retries', () async {
      await dao.enqueue(_entry('dead', maxRetries: 3));

      for (int i = 0; i < 3; i++) {
        await dao.claimBatch(limit: 1);
        await dao.markFailed(['dead'], 'Error $i');
        if (i < 2) {
          // Reset next_retry_at to allow immediate claim for test
          await db.rawUpdate(
            'UPDATE sync_queue SET next_retry_at = NULL WHERE client_id = ?',
            ['dead'],
          );
        }
      }

      final counts = await dao.getCounts();
      expect(counts[QueueStatus.dead], 1);
      expect(counts[QueueStatus.pending], 0);
    });

    test('backoff intervals increase exponentially', () async {
      await dao.enqueue(_entry('exp'));

      // Simulate multiple failures and check backoff growth
      for (int retry = 0; retry < 4; retry++) {
        await db.rawUpdate(
          'UPDATE sync_queue SET next_retry_at = NULL WHERE client_id = ?',
          ['exp'],
        );
        await dao.claimBatch(limit: 1);
        final before = DateTime.now();
        await dao.markFailed(['exp'], 'Error');

        final rows = await db.query('sync_queue',
            where: 'client_id = ?', whereArgs: ['exp']);
        final entry = SyncQueueEntry.fromMap(rows.first);

        if (entry.nextRetryAt != null) {
          final delay = entry.nextRetryAt!.difference(before);
          // Each retry should have increasing delay
          // retry 0→1: ~2s, 1→2: ~4s, 2→3: ~8s, 3→4: ~16s
          final expectedMin = Duration(seconds: (1 << (retry + 1)) * 2 - 1);
          expect(delay >= expectedMin, true,
            reason: 'Retry ${retry + 1}: delay $delay should be >= $expectedMin');
        }
      }
    });

    test('claimBatch skips entries in backoff window', () async {
      await dao.enqueue(_entry('in-backoff'));
      await dao.claimBatch(limit: 1);
      await dao.markFailed(['in-backoff'], 'Error');

      // Entry is in backoff (next_retry_at is in the future)
      final immediate = await dao.claimBatch(limit: 1);
      expect(immediate.length, 0, reason: 'Should not claim entry in backoff window');

      // Simulate backoff elapsed by setting next_retry_at to the past
      await db.rawUpdate(
        'UPDATE sync_queue SET next_retry_at = ? WHERE client_id = ?',
        [DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String(), 'in-backoff'],
      );

      final afterBackoff = await dao.claimBatch(limit: 1);
      expect(afterBackoff.length, 1);
    });

    // ── Crash recovery ───────────────────────────────────────────────────

    test('recoverStuck resets syncing -> pending', () async {
      await dao.enqueue(_entry('stuck-1'));
      await dao.enqueue(_entry('stuck-2'));
      await dao.claimBatch(limit: 10);

      final recovered = await dao.recoverStuck();
      expect(recovered, 2);

      final ready = await dao.getReady();
      expect(ready.length, 2);
    });

    // ── Dead letter queue ────────────────────────────────────────────────

    test('getDeadLetters returns only dead entries', () async {
      await dao.enqueue(_entry('alive'));
      await dao.enqueue(_entry('dead-1', maxRetries: 1));
      await dao.enqueue(_entry('dead-2', maxRetries: 1));

      // Kill dead-1 and dead-2
      await dao.claimBatch(limit: 3);
      await dao.markFailed(['dead-1', 'dead-2'], 'Fatal');

      final deadLetters = await dao.getDeadLetters();
      expect(deadLetters.length, 2);
      expect(deadLetters.every((e) => e.status == QueueStatus.dead), true);
    });

    test('retryDeadLetters resets dead -> pending with fresh retries', () async {
      await dao.enqueue(_entry('revive', maxRetries: 1));
      await dao.claimBatch(limit: 1);
      await dao.markFailed(['revive'], 'Error');

      var counts = await dao.getCounts();
      expect(counts[QueueStatus.dead], 1);

      await dao.retryDeadLetters();

      counts = await dao.getCounts();
      expect(counts[QueueStatus.dead], 0);
      expect(counts[QueueStatus.pending], 1);

      // Should have fresh retry count
      final ready = await dao.getReady();
      expect(ready[0].retryCount, 0);
    });

    // ── Counts ───────────────────────────────────────────────────────────

    test('getCounts returns accurate breakdown', () async {
      await dao.enqueue(_entry('p1'));
      await dao.enqueue(_entry('p2'));
      await dao.enqueue(_entry('p3'));

      await dao.claimBatch(limit: 1);

      final counts = await dao.getCounts();
      expect(counts[QueueStatus.pending], 2);
      expect(counts[QueueStatus.syncing], 1);
    });

    test('getPendingCount includes pending + syncing', () async {
      await dao.enqueue(_entry('x1'));
      await dao.enqueue(_entry('x2'));
      await dao.claimBatch(limit: 1);

      final count = await dao.getPendingCount();
      expect(count, 2); // 1 pending + 1 syncing
    });

    // ── Prune ────────────────────────────────────────────────────────────

    test('prune removes old dead entries', () async {
      await dao.enqueue(_entry('old-dead', maxRetries: 1));
      await dao.claimBatch(limit: 1);
      await dao.markFailed(['old-dead'], 'Error');

      // Manually backdate
      await db.rawUpdate(
        'UPDATE sync_queue SET updated_at = ? WHERE client_id = ?',
        [DateTime.now().subtract(const Duration(days: 10)).toIso8601String(), 'old-dead'],
      );

      final pruned = await dao.prune(days: 7);
      expect(pruned, 1);

      final counts = await dao.getCounts();
      expect(counts[QueueStatus.dead], 0);
    });

    // ── Edge cases ───────────────────────────────────────────────────────

    test('markSynced with empty list is no-op', () async {
      await dao.markSynced([]);
      // Should not throw
    });

    test('markFailed with empty list is no-op', () async {
      await dao.markFailed([], 'Error');
      // Should not throw
    });

    test('claimBatch returns empty list when no pending entries', () async {
      final batch = await dao.claimBatch(limit: 10);
      expect(batch, isEmpty);
    });

    test('concurrent enqueue + claim does not lose entries', () async {
      // Simulate concurrent operations
      final futures = <Future>[];

      for (int i = 0; i < 20; i++) {
        futures.add(dao.enqueue(_entry('concurrent-$i',
            createdAt: DateTime(2024, 1, 1, 0, 0, i))));
      }
      await Future.wait(futures);

      // Claim all in batches
      var totalClaimed = 0;
      while (true) {
        final batch = await dao.claimBatch(limit: 7);
        if (batch.isEmpty) break;
        totalClaimed += batch.length;
        await dao.markSynced(batch.map((e) => e.clientId).toList());
      }

      expect(totalClaimed, 20);
      expect(await dao.getPendingCount(), 0);
    });

    test('mixed priority batch claim respects ordering', () async {
      // Enqueue in random priority order
      await dao.enqueue(_entry('low-1', priority: SyncPriority.low,
          createdAt: DateTime(2024, 1, 1)));
      await dao.enqueue(_entry('critical-1', priority: SyncPriority.critical,
          createdAt: DateTime(2024, 1, 2)));
      await dao.enqueue(_entry('high-1', priority: SyncPriority.high,
          createdAt: DateTime(2024, 1, 1)));
      await dao.enqueue(_entry('normal-1', priority: SyncPriority.normal,
          createdAt: DateTime(2024, 1, 1)));
      await dao.enqueue(_entry('critical-2', priority: SyncPriority.critical,
          createdAt: DateTime(2024, 1, 1)));

      // Claim 3 — should get both criticals (older first) + high
      final batch = await dao.claimBatch(limit: 3);
      expect(batch[0].clientId, 'critical-2'); // critical, older date
      expect(batch[1].clientId, 'critical-1'); // critical, newer date
      expect(batch[2].clientId, 'high-1');     // high priority
    });

    test('large batch enqueue and sync (100 entries)', () async {
      final entries = List.generate(100, (i) => _entry('large-$i',
          createdAt: DateTime(2024, 1, 1, 0, i ~/ 60, i % 60)));
      await dao.enqueueBatch(entries);

      expect(await dao.getPendingCount(), 100);

      var synced = 0;
      while (true) {
        final batch = await dao.claimBatch(limit: 50);
        if (batch.isEmpty) break;
        await dao.markSynced(batch.map((e) => e.clientId).toList());
        synced += batch.length;
      }

      expect(synced, 100);
      expect(await dao.getPendingCount(), 0);
    });
  });
}
