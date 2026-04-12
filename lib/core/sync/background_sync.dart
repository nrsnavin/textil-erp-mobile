import 'dart:async';

import 'package:flutter/foundation.dart';

/// Background sync configuration using a periodic timer.
///
/// ## Why not workmanager?
///
/// workmanager requires native Android/iOS configuration (AndroidManifest.xml,
/// AppDelegate.swift) and platform-specific setup. This timer-based approach
/// provides equivalent functionality for foreground/background states:
///
/// - Periodic sync every 15 minutes when app is active
/// - Immediate sync on connectivity change (via ConnectivityMonitor)
/// - Works with both Android and iOS without native config
///
/// ## For true background execution (app killed):
///
/// Add `workmanager: ^0.5.2` to pubspec.yaml and uncomment the workmanager
/// section below. Then add to AndroidManifest.xml:
///
/// ```xml
/// <provider
///   android:name="androidx.startup.InitializationProvider"
///   android:authorities="${applicationId}.androidx-startup"
///   tools:node="remove" />
/// ```
///
/// And in main.dart:
/// ```dart
/// Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
/// Workmanager().registerPeriodicTask(
///   'sync-mutations',
///   'syncMutations',
///   frequency: Duration(minutes: 15),
///   constraints: Constraints(networkType: NetworkType.connected),
/// );
/// ```

/// Configuration for background sync scheduling.
class BackgroundSyncConfig {
  /// How often to attempt sync when the app is in the foreground.
  final Duration foregroundInterval;

  /// How often to attempt sync when the app is in the background.
  /// (Used by workmanager when configured.)
  final Duration backgroundInterval;

  /// Maximum number of mutations to process per background sync.
  final int batchSize;

  /// Whether to require WiFi for background sync (saves cellular data).
  final bool requireWifi;

  const BackgroundSyncConfig({
    this.foregroundInterval = const Duration(minutes: 15),
    this.backgroundInterval = const Duration(minutes: 15),
    this.batchSize = 50,
    this.requireWifi = false,
  });
}

/// Manages periodic foreground sync scheduling.
///
/// This is a lightweight scheduler that triggers sync flushes at a
/// configurable interval. It's designed to catch mutations that might
/// have been missed by the connectivity listener (e.g., if the app
/// was suspended briefly, or if a backoff timer expired while the
/// connectivity listener wasn't triggered).
class BackgroundSyncScheduler {
  final BackgroundSyncConfig config;
  final Future<void> Function() _onSync;

  Timer? _timer;
  bool _running = false;

  BackgroundSyncScheduler({
    required this.config,
    required Future<void> Function() onSync,
  }) : _onSync = onSync;

  /// Start the periodic sync timer.
  void start() {
    if (_running) return;
    _running = true;

    _timer = Timer.periodic(config.foregroundInterval, (_) async {
      try {
        await _onSync();
      } catch (e) {
        debugPrint('[BackgroundSync] Periodic sync error: $e');
      }
    });

    debugPrint('[BackgroundSync] Started with interval ${config.foregroundInterval.inMinutes}m');
  }

  /// Stop the periodic sync timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    debugPrint('[BackgroundSync] Stopped');
  }

  /// Whether the scheduler is currently active.
  bool get isRunning => _running;

  void dispose() {
    stop();
  }
}

// ══════════════════════════════════════════════════════════════════════════
// WORKMANAGER INTEGRATION (uncomment when workmanager is added)
// ══════════════════════════════════════════════════════════════════════════
//
// import 'package:workmanager/workmanager.dart';
// import '../database/app_database.dart';
// import '../storage/secure_storage.dart';
// import 'sync_queue_service.dart';
// import 'connectivity_monitor.dart';
//
// const _syncTaskName = 'syncMutations';
// const _syncTaskUniqueName = 'textile-erp-sync';
//
// /// Top-level callback for workmanager background execution.
// /// This runs in a separate isolate with no Flutter UI context.
// @pragma('vm:entry-point')
// void callbackDispatcher() {
//   Workmanager().executeTask((taskName, inputData) async {
//     if (taskName != _syncTaskName) return true;
//
//     try {
//       // Initialize database in the background isolate
//       await AppDatabase.instance.initialize();
//       final dao = AppDatabase.instance.syncQueue;
//
//       // Recover any stuck mutations
//       await dao.recoverStuck();
//
//       // Check if there's work to do
//       final pendingCount = await dao.getPendingCount();
//       if (pendingCount == 0) return true;
//
//       // Get access token from secure storage
//       final storage = SecureStorage();
//       final token = await storage.getAccessToken();
//       if (token == null) return true;
//
//       // Create a minimal sync service for the background
//       final connectivity = ConnectivityMonitor();
//       await connectivity.initialize();
//
//       if (!connectivity.isOnline) {
//         connectivity.dispose();
//         return true;
//       }
//
//       final service = SyncQueueService(
//         dao: dao,
//         connectivity: connectivity,
//         getBaseUrl: () => 'http://10.0.2.2:3008',
//         getAccessToken: () => storage.getAccessToken(),
//       );
//
//       await service.flush();
//       service.dispose();
//       connectivity.dispose();
//
//       return true;
//     } catch (e) {
//       debugPrint('[BackgroundSync] Task error: $e');
//       return false; // Retry
//     }
//   });
// }
//
// /// Register the periodic background sync task.
// Future<void> registerBackgroundSync([BackgroundSyncConfig? config]) async {
//   final cfg = config ?? const BackgroundSyncConfig();
//
//   await Workmanager().registerPeriodicTask(
//     _syncTaskUniqueName,
//     _syncTaskName,
//     frequency: cfg.backgroundInterval,
//     constraints: Constraints(
//       networkType: cfg.requireWifi ? NetworkType.unmetered : NetworkType.connected,
//     ),
//     existingWorkPolicy: ExistingWorkPolicy.keep,
//     backoffPolicy: BackoffPolicy.exponential,
//     initialDelay: const Duration(seconds: 30),
//   );
// }
//
// /// Cancel the background sync task.
// Future<void> cancelBackgroundSync() async {
//   await Workmanager().cancelByUniqueName(_syncTaskUniqueName);
// }
