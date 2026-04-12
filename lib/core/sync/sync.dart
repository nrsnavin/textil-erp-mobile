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
///    └── Offline? → SyncQueueDao.enqueue()
///                         │
///                         ▼
///                   SQLite queue (WAL mode)
///                   Priority-ordered (critical > high > normal > low)
///                         │
///                   ┌─────┴──────────────┐
///                   │ SyncQueueService    │ ← ConnectivityMonitor (online event)
///                   │ + BackgroundSync    │ ← Timer (periodic 15m)
///                   └─────┬──────────────┘
///                         │
///              SyncQueueDao.claimBatch() ← Atomic transaction
///              (respects backoff window)
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
///      (delete)     (delete)     (exp backoff)
///                                  │
///                            retry_count++
///                            next_retry_at = now + 2^n * 2s
///                                  │
///                            ┌─────┴──────┐
///                            │ max retries │ → dead letter queue
///                            └────────────┘
/// ```
///
/// ## Concurrency safety
///
/// 1. **Double-flush**: Completer lock prevents concurrent flushes
/// 2. **Atomic claim**: SQLite transaction prevents double-pickup
/// 3. **Crash recovery**: On startup, stuck "syncing" → "pending"
/// 4. **Server idempotency**: clientId UUID prevents server-side duplicates
/// 5. **Debounced connectivity**: 1.5s debounce on network transitions
/// 6. **Backoff-aware claims**: Only picks up mutations past their retry window
///
/// ## Data caching (NetworkAwareRepository)
///
/// ```
///   NetworkAwareRepository.fetch()
///    ├── networkFirst:  API → cache on failure
///    ├── cacheFirst:    cache if fresh → API if stale
///    ├── staleWhileRevalidate: return cache → refresh background
///    ├── networkOnly:   API only
///    └── cacheOnly:     SQLite only (offline)
/// ```
library;

export 'connectivity_monitor.dart';
export 'sync_queue_service.dart';
export 'background_sync.dart';
export 'sync_provider.dart';
