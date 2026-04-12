import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:textile_erp_mobile/core/sync/mutation.dart';
import 'package:textile_erp_mobile/core/sync/mutation_db.dart';

/// Initialize sqflite_common_ffi for desktop testing.
void sqfliteTestInit() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

void main() {
  sqfliteTestInit();

  late MutationDb db;

  setUp(() async {
    // Use in-memory database for test isolation
    final inMemory = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE mutations (
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
          await db.execute('''
            CREATE INDEX idx_mutations_status_created
            ON mutations (status, created_at ASC)
          ''');
        },
      ),
    );
    db = MutationDb.forTesting(inMemory);
  });

  group('MutationDb', () {
    test('enqueue and getPending returns mutations in order', () async {
      for (int i = 0; i < 5; i++) {
        await db.enqueue(Mutation(
          clientId: 'test-$i',
          endpoint: '/api/v1/buyers',
          method: 'POST',
          body: {'name': 'Buyer $i'},
          createdAt: DateTime(2024, 1, 1, 0, 0, i),
        ));
      }

      final pending = await db.getPending();
      expect(pending.length, 5);
      expect(pending[0].clientId, 'test-0');
      expect(pending[4].clientId, 'test-4');
    });

    test('enqueue ignores duplicate clientId', () async {
      await db.enqueue(Mutation(
        clientId: 'dup-1',
        endpoint: '/api/v1/buyers',
        method: 'POST',
        body: {'name': 'First'},
      ));
      await db.enqueue(Mutation(
        clientId: 'dup-1',
        endpoint: '/api/v1/buyers',
        method: 'POST',
        body: {'name': 'Second'},
      ));

      final pending = await db.getPending();
      expect(pending.length, 1);
      expect(pending[0].body!['name'], 'First'); // First wins
    });

    test('claimBatch atomically transitions pending -> syncing', () async {
      for (int i = 0; i < 10; i++) {
        await db.enqueue(Mutation(
          clientId: 'claim-$i',
          endpoint: '/api/v1/buyers',
          method: 'POST',
          createdAt: DateTime(2024, 1, 1, 0, 0, i),
        ));
      }

      final batch = await db.claimBatch(limit: 5);
      expect(batch.length, 5);
      expect(batch.every((m) => m.status == MutationStatus.syncing), true);

      // Second claim should get the remaining 5
      final batch2 = await db.claimBatch(limit: 5);
      expect(batch2.length, 5);

      // No more pending
      final batch3 = await db.claimBatch(limit: 5);
      expect(batch3.length, 0);
    });

    test('markSynced deletes mutations from queue', () async {
      await db.enqueue(Mutation(
        clientId: 'synced-1',
        endpoint: '/api/v1/buyers',
        method: 'POST',
      ));
      await db.enqueue(Mutation(
        clientId: 'synced-2',
        endpoint: '/api/v1/buyers',
        method: 'POST',
      ));

      await db.markSynced(['synced-1']);

      final pending = await db.getPending();
      expect(pending.length, 1);
      expect(pending[0].clientId, 'synced-2');
    });

    test('markFailed increments retry count and resets to pending', () async {
      await db.enqueue(Mutation(
        clientId: 'fail-1',
        endpoint: '/api/v1/buyers',
        method: 'POST',
      ));

      // Claim and fail
      await db.claimBatch(limit: 1);
      await db.markFailed(['fail-1'], 'Network error');

      // Should be back to pending with retry_count = 1
      final pending = await db.getPending();
      expect(pending.length, 1);
      expect(pending[0].retryCount, 1);
      expect(pending[0].errorMessage, 'Network error');
    });

    test('markFailed moves to failed status after 5 retries', () async {
      await db.enqueue(Mutation(
        clientId: 'maxretry-1',
        endpoint: '/api/v1/buyers',
        method: 'POST',
      ));

      // Simulate 5 claim-fail cycles
      for (int i = 0; i < 5; i++) {
        await db.claimBatch(limit: 1);
        await db.markFailed(['maxretry-1'], 'Error $i');
        if (i < 4) {
          // recoverStuckMutations won't be needed since markFailed
          // resets to pending for first 4 failures
        }
      }

      // After 5 failures, should be in failed state
      final counts = await db.getCounts();
      expect(counts[MutationStatus.failed], 1);
      expect(counts[MutationStatus.pending], 0);
    });

    test('recoverStuckMutations resets syncing -> pending', () async {
      await db.enqueue(Mutation(
        clientId: 'stuck-1',
        endpoint: '/api/v1/buyers',
        method: 'POST',
      ));
      await db.enqueue(Mutation(
        clientId: 'stuck-2',
        endpoint: '/api/v1/buyers',
        method: 'POST',
      ));

      // Claim (sets to syncing)
      await db.claimBatch(limit: 10);

      // Simulate app crash - mutations stuck in syncing
      final recovered = await db.recoverStuckMutations();
      expect(recovered, 2);

      // Should be back to pending
      final pending = await db.getPending();
      expect(pending.length, 2);
    });

    test('getCounts returns correct breakdown by status', () async {
      for (int i = 0; i < 3; i++) {
        await db.enqueue(Mutation(
          clientId: 'count-$i',
          endpoint: '/api/v1/buyers',
          method: 'POST',
          createdAt: DateTime(2024, 1, 1, 0, 0, i),
        ));
      }

      // Claim 2, leave 1 pending
      await db.claimBatch(limit: 2);

      final counts = await db.getCounts();
      expect(counts[MutationStatus.pending], 1);
      expect(counts[MutationStatus.syncing], 2);
    });
  });
}
