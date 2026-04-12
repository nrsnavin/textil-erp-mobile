/// Offline sync infrastructure for the Textile ERP mobile app.
///
/// ## Architecture
///
/// ```
///   User action (create/update/delete)
///         │
///         ▼
///   OfflineMutationHelper
///    ├── Online? → API call (direct)
///    └── Offline? → MutationDb.enqueue()
///                         │
///                         ▼
///                   SQLite queue (WAL mode)
///                         │
///                   ┌─────┴─────┐
///                   │ SyncEngine │ ← ConnectivityMonitor (online event)
///                   └─────┬─────┘
///                         │
///              MutationDb.claimBatch() ← Atomic transaction
///                         │
///                  ┌──────┴───────┐
///                  │ Isolate.run()│ ← Network I/O off main thread
///                  └──────┬───────┘
///                         │
///              POST /api/v1/sync/push
///              (batched, idempotent by clientId)
///                         │
///                    ┌────┴────┐
///                    │ Results │
///                    └────┬────┘
///                         │
///           ┌─────────────┼─────────────┐
///           │             │             │
///      "applied"    "duplicate"     "error"
///      markSynced   markSynced   markFailed
///      (delete)     (delete)     (retry later)
/// ```
///
/// ## Concurrency safety
///
/// 1. **Double-flush**: Completer lock prevents concurrent flushes
/// 2. **Atomic claim**: SQLite transaction prevents double-pickup
/// 3. **Crash recovery**: On startup, stuck "syncing" → "pending"
/// 4. **Server idempotency**: clientId UUID prevents server-side duplicates
/// 5. **Debounced connectivity**: 1.5s debounce on network transitions
library;

export 'mutation.dart';
export 'mutation_db.dart';
export 'connectivity_monitor.dart';
export 'sync_engine.dart';
export 'sync_provider.dart';
