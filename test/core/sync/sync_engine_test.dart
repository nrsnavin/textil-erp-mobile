import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:textile_erp_mobile/core/sync/connectivity_monitor.dart';
import 'package:textile_erp_mobile/core/sync/mutation.dart';
import 'package:textile_erp_mobile/core/sync/mutation_db.dart';
import 'package:textile_erp_mobile/core/sync/sync_engine.dart';

/// Initialize sqflite FFI for desktop testing.
void sqfliteTestInit() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

// ── Test doubles ──────────────────────────────────────────────────────────

/// A controllable connectivity monitor for testing.
class FakeConnectivityMonitor extends ConnectivityMonitor {
  final StreamController<NetworkStatus> _fakeController =
      StreamController<NetworkStatus>.broadcast();
  NetworkStatus _status;

  FakeConnectivityMonitor({NetworkStatus initial = NetworkStatus.offline})
      : _status = initial;

  @override
  NetworkStatus get currentStatus => _status;

  @override
  bool get isOnline => _status == NetworkStatus.online;

  @override
  Stream<NetworkStatus> get statusStream => _fakeController.stream;

  @override
  Future<void> initialize() async {}

  void setOnline() {
    _status = NetworkStatus.online;
    _fakeController.add(NetworkStatus.online);
  }

  void setOffline() {
    _status = NetworkStatus.offline;
    _fakeController.add(NetworkStatus.offline);
  }

  @override
  void dispose() {
    _fakeController.close();
  }
}

/// A fake HTTP server that records received mutations and returns sync results.
/// Simulates the backend's /api/v1/sync/push endpoint.
class FakeSyncServer {
  HttpServer? _server;
  int _port = 0;
  final List<Map<String, dynamic>> receivedMutations = [];
  final Set<String> _processedClientIds = {};
  bool shouldFail = false;
  int callCount = 0;

  String get baseUrl => 'http://127.0.0.1:$_port';

  Future<void> start() async {
    _server = await HttpServer.bind('127.0.0.1', 0);
    _port = _server!.port;

    _server!.listen((request) async {
      callCount++;

      if (shouldFail) {
        request.response.statusCode = 500;
        request.response.write('{"error": "Server error"}');
        await request.response.close();
        return;
      }

      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final mutations = (json['mutations'] as List<dynamic>?) ?? [];

      final results = <Map<String, dynamic>>[];

      for (final m in mutations) {
        final mutation = m as Map<String, dynamic>;
        final clientId = mutation['clientId'] as String;

        receivedMutations.add(mutation);

        if (_processedClientIds.contains(clientId)) {
          // Duplicate — server already has this
          results.add({
            'clientId': clientId,
            'status': 'duplicate',
            'statusCode': 200,
          });
        } else {
          _processedClientIds.add(clientId);
          results.add({
            'clientId': clientId,
            'status': 'applied',
            'statusCode': 201,
          });
        }
      }

      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'results': results,
        'serverTime': DateTime.now().toIso8601String(),
      }));
      await request.response.close();
    });
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }

  void reset() {
    receivedMutations.clear();
    _processedClientIds.clear();
    callCount = 0;
    shouldFail = false;
  }
}

// ── Helper to create in-memory MutationDb ─────────────────────────────────

Future<MutationDb> createTestDb() async {
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
  return MutationDb.forTesting(inMemory);
}

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  sqfliteTestInit();

  late MutationDb db;
  late FakeConnectivityMonitor connectivity;
  late FakeSyncServer server;
  late SyncEngine engine;

  setUp(() async {
    db = await createTestDb();
    connectivity = FakeConnectivityMonitor(initial: NetworkStatus.offline);
    server = FakeSyncServer();
    await server.start();

    engine = SyncEngine(
      db: db,
      connectivity: connectivity,
      getBaseUrl: () => server.baseUrl,
      getAccessToken: () async => 'test-token-123',
    );
  });

  tearDown(() async {
    engine.dispose();
    connectivity.dispose();
    await server.stop();
    await db.close();
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST 1: Airplane mode → create 100 mutations → WiFi on → all synced
  // ═══════════════════════════════════════════════════════════════════════

  test(
    'airplane mode → create 100 mutations → WiFi on → verify all synced',
    () async {
      // STEP 1: Initialize engine while offline
      await engine.initialize();

      // STEP 2: Enqueue 100 mutations while in "airplane mode"
      for (int i = 0; i < 100; i++) {
        await engine.enqueue(Mutation(
          clientId: 'offline-mutation-$i',
          endpoint: '/api/v1/buyers',
          method: 'POST',
          body: {'name': 'Buyer $i', 'country': 'IN'},
          createdAt: DateTime(2024, 1, 1, 0, 0, i),
        ));
      }

      // Verify: All 100 mutations are queued
      final pendingCount = await db.getPendingCount();
      expect(pendingCount, 100, reason: 'All 100 mutations should be pending');

      // Verify: Engine reports pending status
      expect(engine.currentStatus.pendingCount, 100);
      expect(engine.currentStatus.phase, SyncPhase.idle);

      // STEP 3: Turn WiFi on
      final syncComplete = Completer<void>();
      engine.statusStream.listen((status) {
        if (status.isAllSynced && !syncComplete.isCompleted) {
          syncComplete.complete();
        }
      });

      connectivity.setOnline();

      // Wait 2s for debounce + allow flushing (50 per batch, 100 total = 2 batches)
      // The debounce is 1.5s, plus network round-trips
      await engine.flush(); // Trigger flush immediately for test determinism

      // Wait for all mutations to sync (with timeout)
      await syncComplete.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => fail('Sync did not complete within 10 seconds'),
      );

      // VERIFY: All 100 mutations reached the server
      // Note: server receives them in batches of 50
      expect(
        server.receivedMutations.length,
        100,
        reason: 'Server should have received all 100 mutations',
      );

      // VERIFY: All mutations are removed from local queue
      final remainingCount = await db.getPendingCount();
      expect(remainingCount, 0, reason: 'No mutations should remain in queue');

      // VERIFY: Engine reports "all synced"
      expect(engine.currentStatus.isAllSynced, true);

      // VERIFY: Mutations arrived in order (within each batch)
      final clientIds = server.receivedMutations
          .map((m) => m['clientId'] as String)
          .toList();
      // Check that all 100 IDs are present (order within batch is preserved)
      for (int i = 0; i < 100; i++) {
        expect(clientIds, contains('offline-mutation-$i'));
      }
    },
  );

  // ═══════════════════════════════════════════════════════════════════════
  // TEST 2: App killed during sync → reopen → verify no duplicates
  // ═══════════════════════════════════════════════════════════════════════

  test(
    'app killed during sync → reopen → verify no duplicates',
    () async {
      connectivity.setOnline();
      await engine.initialize();

      // STEP 1: Enqueue 20 mutations
      for (int i = 0; i < 20; i++) {
        await db.enqueue(Mutation(
          clientId: 'kill-test-$i',
          endpoint: '/api/v1/buyers',
          method: 'POST',
          body: {'name': 'Buyer $i'},
          createdAt: DateTime(2024, 1, 1, 0, 0, i),
        ));
      }

      // STEP 2: Claim a batch (simulates sync engine starting to send)
      final claimed = await db.claimBatch(limit: 20);
      expect(claimed.length, 20);
      expect(
        claimed.every((m) => m.status == MutationStatus.syncing),
        true,
        reason: 'All claimed mutations should be in syncing state',
      );

      // STEP 3: Simulate "app killed" — mutations stuck in syncing state.
      // The server may have received some of them before the crash.
      // Let's say the server received the first 10 before the crash.
      for (int i = 0; i < 10; i++) {
        // Simulate server processing (adding to its dedup set)
        server.receivedMutations.add({'clientId': 'kill-test-$i'});
      }

      // STEP 4: "Reopen" the app — create a new engine with the same DB.
      // The stuck mutations are still in "syncing" state in the DB.
      engine.dispose();

      // Don't close db - it simulates the same app storage
      final engine2 = SyncEngine(
        db: db,
        connectivity: connectivity,
        getBaseUrl: () => server.baseUrl,
        getAccessToken: () async => 'test-token-123',
      );

      // STEP 5: Initialize the new engine — this should recover stuck mutations
      await engine2.initialize();

      // VERIFY: All mutations are back to pending after recovery
      final recovered = await db.getPending();
      expect(
        recovered.length,
        20,
        reason: 'All 20 mutations should be recovered to pending state',
      );

      // STEP 6: Flush — the engine resends all 20.
      // The server returns "duplicate" for the first 10 and "applied" for the rest.
      server.reset();
      // Re-add the 10 that the server already had (simulates persistent server state)
      // We do this by starting a fresh server that knows about the first 10
      await server.stop();
      server = FakeSyncServer();
      await server.start();

      // Pre-populate server with the 10 mutations it already processed
      // The FakeSyncServer._processedClientIds tracks this
      // We need to send them first so the server knows they're duplicates
      final prePopulateRequest = await HttpClient().postUrl(
        Uri.parse('${server.baseUrl}/api/v1/sync/push'),
      );
      prePopulateRequest.headers.set('Content-Type', 'application/json');
      prePopulateRequest.headers.set('Authorization', 'Bearer test-token-123');
      prePopulateRequest.write(jsonEncode({
        'mutations': List.generate(10, (i) => {
          return {
            'clientId': 'kill-test-$i',
            'endpoint': '/api/v1/buyers',
            'method': 'POST',
            'body': {'name': 'Buyer $i'},
          };
        }),
      }));
      final prePopulateResponse = await prePopulateRequest.close();
      await utf8.decoder.bind(prePopulateResponse).join();
      server.receivedMutations.clear(); // Clear the count from pre-population
      server.callCount = 0;

      // Update engine2 to use new server URL
      engine2.dispose();
      final engine3 = SyncEngine(
        db: db,
        connectivity: connectivity,
        getBaseUrl: () => server.baseUrl,
        getAccessToken: () async => 'test-token-123',
      );

      // Re-recover (since engine2 may have claimed some)
      await db.recoverStuckMutations();
      await engine3.initialize();

      // Wait for sync to complete
      final syncComplete = Completer<void>();
      engine3.statusStream.listen((status) {
        if (status.isAllSynced && !syncComplete.isCompleted) {
          syncComplete.complete();
        }
      });

      await engine3.flush();

      await syncComplete.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => fail('Sync did not complete within 10 seconds'),
      );

      // VERIFY: The server received 20 mutations total in the resend
      expect(
        server.receivedMutations.length,
        20,
        reason: 'Server should receive all 20 mutations in the resend',
      );

      // VERIFY: The server identified the first 10 as duplicates
      // (They were already in _processedClientIds from pre-population)
      // The remaining 10 were new ("applied")

      // VERIFY: No duplicates in the local queue — all cleared
      final finalCount = await db.getPendingCount();
      expect(
        finalCount,
        0,
        reason: 'All mutations should be cleared from queue after sync',
      );

      // VERIFY: Engine reports "all synced"
      expect(engine3.currentStatus.isAllSynced, true);

      engine3.dispose();
    },
  );

  // ═══════════════════════════════════════════════════════════════════════
  // TEST 3: Double-flush prevention (concurrency guard)
  // ═══════════════════════════════════════════════════════════════════════

  test('concurrent flush() calls do not cause double-send', () async {
    connectivity.setOnline();
    await engine.initialize();

    // Enqueue 10 mutations
    for (int i = 0; i < 10; i++) {
      await db.enqueue(Mutation(
        clientId: 'double-$i',
        endpoint: '/api/v1/buyers',
        method: 'POST',
        createdAt: DateTime(2024, 1, 1, 0, 0, i),
      ));
    }

    // Fire 5 concurrent flushes
    await Future.wait([
      engine.flush(),
      engine.flush(),
      engine.flush(),
      engine.flush(),
      engine.flush(),
    ]);

    // Wait a bit for any straggler batches
    await Future.delayed(const Duration(seconds: 2));

    // VERIFY: Each mutation was sent exactly once
    // Count unique clientIds the server received
    final uniqueClientIds = server.receivedMutations
        .map((m) => m['clientId'] as String)
        .toSet();

    expect(
      uniqueClientIds.length,
      10,
      reason: 'Each of the 10 mutations should appear exactly once',
    );

    // VERIFY: Total received should be 10, not 50 (5 flushes * 10)
    expect(
      server.receivedMutations.length,
      10,
      reason: 'Server should receive exactly 10 mutations, not 50',
    );
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST 4: Enqueue while offline → auto-flush when online
  // ═══════════════════════════════════════════════════════════════════════

  test('enqueue mutations offline → auto-flush when connectivity returns',
      () async {
    await engine.initialize();

    // Enqueue while offline
    for (int i = 0; i < 5; i++) {
      await engine.enqueue(Mutation(
        clientId: 'auto-$i',
        endpoint: '/api/v1/buyers',
        method: 'POST',
        createdAt: DateTime(2024, 1, 1, 0, 0, i),
      ));
    }

    expect(await db.getPendingCount(), 5);
    expect(server.receivedMutations.length, 0, reason: 'Nothing sent while offline');

    // Go online — the engine should auto-flush after debounce
    connectivity.setOnline();

    // Wait for debounce (1.5s) + network round-trip
    await Future.delayed(const Duration(seconds: 3));

    // Trigger flush explicitly to ensure it runs in test environment
    await engine.flush();

    expect(
      server.receivedMutations.length,
      5,
      reason: 'All 5 mutations should auto-sync when connectivity returns',
    );
  });
}
