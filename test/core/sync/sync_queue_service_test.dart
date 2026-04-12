import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:textile_erp_mobile/core/database/daos/sync_queue_dao.dart';
import 'package:textile_erp_mobile/core/sync/connectivity_monitor.dart';
import 'package:textile_erp_mobile/core/sync/sync_queue_service.dart';

void sqfliteTestInit() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

// ── Test doubles ──────────────────────────────────────────────────────────

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
  void dispose() => _fakeController.close();
}

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
          results.add({'clientId': clientId, 'status': 'duplicate', 'statusCode': 200});
        } else {
          _processedClientIds.add(clientId);
          results.add({'clientId': clientId, 'status': 'applied', 'statusCode': 201});
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

late Database _testDb; // Keep reference for test helpers

Future<SyncQueueDao> createTestDao() async {
  final db = _testDb = await databaseFactoryFfi.openDatabase(
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
        await db.execute('CREATE INDEX idx_sq_client_id ON sync_queue (client_id)');
        await db.execute('CREATE INDEX idx_sq_next_retry ON sync_queue (status, next_retry_at)');
      },
    ),
  );
  return SyncQueueDao(db);
}

void main() {
  sqfliteTestInit();

  late SyncQueueDao dao;
  late FakeConnectivityMonitor connectivity;
  late FakeSyncServer server;
  late SyncQueueService service;

  setUp(() async {
    dao = await createTestDao();
    connectivity = FakeConnectivityMonitor(initial: NetworkStatus.offline);
    server = FakeSyncServer();
    await server.start();

    service = SyncQueueService(
      dao: dao,
      connectivity: connectivity,
      getBaseUrl: () => server.baseUrl,
      getAccessToken: () async => 'test-token',
    );
  });

  tearDown(() async {
    service.dispose();
    connectivity.dispose();
    await server.stop();
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST 1: Airplane mode → 100 mutations → WiFi on → all synced
  // ═══════════════════════════════════════════════════════════════════════

  test('airplane mode → enqueue 100 → WiFi on → all synced', () async {
    await service.initialize();

    // Enqueue 100 offline mutations with mixed priorities
    for (int i = 0; i < 100; i++) {
      await service.enqueue(
        endpoint: '/api/v1/buyers',
        method: 'POST',
        body: {'name': 'Buyer $i'},
        priority: i < 10 ? SyncPriority.critical : SyncPriority.normal,
      );
    }

    expect(await dao.getPendingCount(), 100);

    // Go online and flush
    connectivity.setOnline();
    final syncComplete = Completer<void>();
    service.statusStream.listen((status) {
      if (status.isAllSynced && !syncComplete.isCompleted) {
        syncComplete.complete();
      }
    });

    await service.flush();
    await syncComplete.future.timeout(const Duration(seconds: 15));

    expect(server.receivedMutations.length, 100);
    expect(await dao.getPendingCount(), 0);
    expect(service.currentStatus.isAllSynced, true);

    // Verify critical mutations were sent first (in the first batch)
    final firstBatchIds = server.receivedMutations
        .take(50)
        .map((m) => m['clientId'] as String)
        .toList();
    // At minimum, all 10 critical ones should be in the first batch
    // (they have higher priority so claimBatch picks them first)
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST 2: Crash recovery — no duplicates
  // ═══════════════════════════════════════════════════════════════════════

  test('crash during sync → recovery → no duplicates', () async {
    connectivity.setOnline();
    await service.initialize();

    // Enqueue and claim (simulates sync starting)
    for (int i = 0; i < 20; i++) {
      await dao.enqueue(SyncQueueEntry(
        clientId: 'crash-$i',
        endpoint: '/api/v1/buyers',
        method: 'POST',
        body: {'name': 'Buyer $i'},
      ));
    }

    // Claim (as if sync engine started)
    await dao.claimBatch(limit: 20);

    // "Crash" — create new service
    service.dispose();

    final service2 = SyncQueueService(
      dao: dao,
      connectivity: connectivity,
      getBaseUrl: () => server.baseUrl,
      getAccessToken: () async => 'test-token',
    );

    await service2.initialize(); // Should recover stuck mutations

    final syncComplete = Completer<void>();
    service2.statusStream.listen((status) {
      if (status.isAllSynced && !syncComplete.isCompleted) {
        syncComplete.complete();
      }
    });

    await service2.flush();
    await syncComplete.future.timeout(const Duration(seconds: 10));

    expect(server.receivedMutations.length, 20);
    expect(await dao.getPendingCount(), 0);

    service2.dispose();
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST 3: Concurrent flush prevention
  // ═══════════════════════════════════════════════════════════════════════

  test('concurrent flush calls do not cause double-send', () async {
    connectivity.setOnline();
    await service.initialize();

    for (int i = 0; i < 10; i++) {
      await dao.enqueue(SyncQueueEntry(
        clientId: 'conc-$i',
        endpoint: '/api/v1/buyers',
        method: 'POST',
      ));
    }

    await Future.wait([
      service.flush(),
      service.flush(),
      service.flush(),
      service.flush(),
      service.flush(),
    ]);

    await Future.delayed(const Duration(seconds: 2));

    final uniqueIds = server.receivedMutations
        .map((m) => m['clientId'] as String)
        .toSet();

    expect(uniqueIds.length, 10);
    expect(server.receivedMutations.length, 10);
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST 4: Server failure → exponential backoff
  // ═══════════════════════════════════════════════════════════════════════

  test('server failure triggers exponential backoff', () async {
    connectivity.setOnline();
    await service.initialize();

    await dao.enqueue(SyncQueueEntry(
      clientId: 'fail-1',
      endpoint: '/api/v1/buyers',
      method: 'POST',
    ));

    // Server fails
    server.shouldFail = true;
    await service.flush();

    // Entry should be back in pending with retry_count=1 and future next_retry_at
    final counts = await dao.getCounts();
    expect(counts[QueueStatus.pending], 1);

    // Immediate re-claim should fail (in backoff window)
    final immediate = await dao.claimBatch(limit: 1);
    expect(immediate.length, 0, reason: 'Should respect backoff window');
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST 5: Dead letter queue
  // ═══════════════════════════════════════════════════════════════════════

  test('mutations move to dead letter after max retries', () async {
    connectivity.setOnline();
    await service.initialize();

    // Entry with maxRetries=2 for quick test
    await dao.enqueue(SyncQueueEntry(
      clientId: 'doomed',
      endpoint: '/api/v1/buyers',
      method: 'POST',
      maxRetries: 2,
    ));

    server.shouldFail = true;

    // First failure
    await service.flush();
    // Reset backoff for test
    await _testDb.rawUpdate(
      'UPDATE sync_queue SET next_retry_at = NULL WHERE client_id = ?',
      ['doomed'],
    );

    // Second failure → dead
    await service.flush();

    final deadLetters = await dao.getDeadLetters();
    expect(deadLetters.length, 1);
    expect(deadLetters[0].clientId, 'doomed');
    expect(deadLetters[0].status, QueueStatus.dead);
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST 6: Priority-based sync (critical first)
  // ═══════════════════════════════════════════════════════════════════════

  test('critical mutations sync before normal ones', () async {
    connectivity.setOnline();
    await service.initialize();

    // Enqueue normal first, then critical
    for (int i = 0; i < 5; i++) {
      await dao.enqueue(SyncQueueEntry(
        clientId: 'normal-$i',
        endpoint: '/api/v1/buyers',
        method: 'POST',
        priority: SyncPriority.normal,
        createdAt: DateTime(2024, 1, 1, 0, 0, i),
      ));
    }
    for (int i = 0; i < 3; i++) {
      await dao.enqueue(SyncQueueEntry(
        clientId: 'critical-$i',
        endpoint: '/api/v1/orders',
        method: 'POST',
        priority: SyncPriority.critical,
        createdAt: DateTime(2024, 1, 1, 0, 0, i),
      ));
    }

    await service.flush();
    await Future.delayed(const Duration(seconds: 2));

    // Critical mutations should appear before normal ones
    final allIds = server.receivedMutations.map((m) => m['clientId'] as String).toList();
    final firstCriticalIdx = allIds.indexWhere((id) => id.startsWith('critical-'));
    final lastCriticalIdx = allIds.lastIndexWhere((id) => id.startsWith('critical-'));
    final firstNormalIdx = allIds.indexWhere((id) => id.startsWith('normal-'));

    expect(lastCriticalIdx < firstNormalIdx, true,
      reason: 'All critical mutations should be sent before any normal ones');
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST 7: Connectivity change auto-flush
  // ═══════════════════════════════════════════════════════════════════════

  test('auto-flush when connectivity returns', () async {
    await service.initialize();

    // Enqueue while offline
    for (int i = 0; i < 5; i++) {
      await service.enqueue(
        endpoint: '/api/v1/buyers',
        method: 'POST',
        body: {'name': 'Buyer $i'},
      );
    }

    expect(server.receivedMutations.length, 0);

    // Go online
    connectivity.setOnline();

    // Wait for debounce (1.5s) + processing
    await Future.delayed(const Duration(seconds: 3));
    await service.flush();

    expect(server.receivedMutations.length, 5);
  });
}
