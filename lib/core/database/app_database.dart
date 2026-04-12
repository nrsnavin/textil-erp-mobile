import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'daos/sync_queue_dao.dart';
import 'daos/orders_dao.dart';
import 'daos/inventory_dao.dart';

/// Central SQLite database for offline-first data.
///
/// Uses Drift-compatible table definitions with raw sqflite for
/// zero-codegen setup. Each table has a typed DAO that provides
/// compile-time-safe queries. Migrate to Drift by replacing table
/// definitions with `@DataClassName` annotated classes.
///
/// ## Tables
///
/// | Table            | Purpose                                |
/// |------------------|----------------------------------------|
/// | sync_queue       | Offline mutation queue with priority   |
/// | cached_orders    | Local order cache for offline reads    |
/// | cached_inventory | Local stock balance cache              |
///
/// ## Schema versioning
///
/// Version 1: Original sync_queue.db (mutations table)
/// Version 2: Unified app_database.db with all tables
class AppDatabase {
  static const _dbName = 'app_database.db';
  static const _version = 2;

  Database? _db;
  final Completer<void> _initCompleter = Completer<void>();
  bool _initialized = false;

  late final SyncQueueDao syncQueue;
  late final OrdersDao orders;
  late final InventoryDao inventory;

  /// Singleton
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();

  /// For testing: inject a pre-opened database.
  AppDatabase.forTesting(Database db) {
    _db = db;
    _initialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
    syncQueue = SyncQueueDao(db);
    orders = OrdersDao(db);
    inventory = InventoryDao(db);
  }

  Database get db {
    assert(_initialized, 'AppDatabase not initialized. Call initialize() first.');
    return _db!;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbName);

    _db = await openDatabase(
      path,
      version: _version,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    syncQueue = SyncQueueDao(_db!);
    orders = OrdersDao(_db!);
    inventory = InventoryDao(_db!);

    _initialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
  }

  Future<void> waitForInit() => _initCompleter.future;

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA journal_mode=WAL');
    await db.execute('PRAGMA synchronous=NORMAL');
    await db.execute('PRAGMA foreign_keys=ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createSyncQueueTable(db);
    await _createCachedOrdersTable(db);
    await _createCachedInventoryTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrating from v1 (sync_queue.db had a separate 'mutations' table).
      // This is a fresh db so just create all tables.
      await _createSyncQueueTable(db);
      await _createCachedOrdersTable(db);
      await _createCachedInventoryTable(db);
    }
  }

  // ── Table creation ───────────────────────────────────────────────────────

  Future<void> _createSyncQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
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
      CREATE INDEX IF NOT EXISTS idx_sq_status_priority_created
      ON sync_queue (status, priority DESC, created_at ASC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sq_client_id
      ON sync_queue (client_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sq_next_retry
      ON sync_queue (status, next_retry_at)
    ''');
  }

  Future<void> _createCachedOrdersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_orders (
        id              TEXT    PRIMARY KEY,
        po_number       TEXT    NOT NULL,
        buyer_id        TEXT    NOT NULL,
        buyer_json      TEXT,
        status          TEXT    NOT NULL DEFAULT 'DRAFT',
        delivery_date   TEXT    NOT NULL,
        season          TEXT,
        remarks         TEXT,
        total_qty       INTEGER NOT NULL DEFAULT 0,
        total_styles    INTEGER NOT NULL DEFAULT 0,
        data_json       TEXT    NOT NULL,
        cached_at       TEXT    NOT NULL,
        etag            TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_co_status
      ON cached_orders (status)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_co_po_number
      ON cached_orders (po_number)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_co_cached_at
      ON cached_orders (cached_at)
    ''');
  }

  Future<void> _createCachedInventoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_inventory (
        id              TEXT    PRIMARY KEY,
        item_id         TEXT    NOT NULL,
        item_json       TEXT,
        location        TEXT    NOT NULL DEFAULT 'MAIN',
        on_hand         REAL    NOT NULL DEFAULT 0,
        reserved        REAL    NOT NULL DEFAULT 0,
        available       REAL    NOT NULL DEFAULT 0,
        data_json       TEXT    NOT NULL,
        cached_at       TEXT    NOT NULL,
        etag            TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_ci_item_location
      ON cached_inventory (item_id, location)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_ci_cached_at
      ON cached_inventory (cached_at)
    ''');
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Clear all cached data (orders + inventory). Preserves sync queue.
  Future<void> clearCache() async {
    await _db?.delete('cached_orders');
    await _db?.delete('cached_inventory');
  }

  /// Nuke everything (for logout).
  Future<void> clearAll() async {
    await _db?.delete('sync_queue');
    await _db?.delete('cached_orders');
    await _db?.delete('cached_inventory');
  }
}
