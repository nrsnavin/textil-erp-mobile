import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/connectivity_monitor.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_provider.dart';

/// Pixel-perfect sync status bar that drives user trust.
///
/// ## States and visual treatment:
///
/// | State             | Background | Icon       | Text                  |
/// |-------------------|------------|------------|-----------------------|
/// | All synced        | #E8F5E9   | check      | "All changes synced"  |
/// | Offline + pending | #FFF3E0   | cloud_off  | "12 changes pending"  |
/// | Syncing           | #E3F2FD   | sync       | "Syncing 3 of 12..."  |
/// | Error             | #FFEBEE   | error      | "Sync failed · Retry" |
/// | Offline (idle)    | #F5F5F5   | wifi_off   | "Offline"             |
///
/// The bar is 40px tall, uses smooth 300ms animated transitions between
/// states, and a subtle rotating animation on the sync icon during upload.
class SyncStatusBar extends ConsumerStatefulWidget {
  const SyncStatusBar({super.key});

  @override
  ConsumerState<SyncStatusBar> createState() => _SyncStatusBarState();
}

class _SyncStatusBarState extends ConsumerState<SyncStatusBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(currentSyncStatusProvider);
    final networkAsync = ref.watch(networkStatusProvider);
    final isOffline = networkAsync.when(
      data: (s) => s == NetworkStatus.offline,
      loading: () => false,
      error: (_, __) => false,
    );

    // Determine visual state
    final visual = _resolveVisual(syncStatus, isOffline);

    // Control spin animation
    if (visual.spinning) {
      if (!_spinController.isAnimating) _spinController.repeat();
    } else {
      _spinController.stop();
      _spinController.reset();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 40,
      decoration: BoxDecoration(
        color: visual.backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: visual.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: visual.onTap != null
              ? () => visual.onTap!(ref)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Icon with optional spin
                _buildIcon(visual),
                const SizedBox(width: 10),

                // Status text
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      visual.text,
                      key: ValueKey(visual.text),
                      style: TextStyle(
                        color: visual.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Progress indicator for syncing state
                if (visual.showProgress) ...[
                  const SizedBox(width: 8),
                  _buildProgressPill(syncStatus),
                ],

                // Retry button for error state
                if (visual.showRetry) ...[
                  const SizedBox(width: 8),
                  _buildRetryButton(visual),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(_SyncVisual visual) {
    if (visual.spinning) {
      return AnimatedBuilder(
        animation: _spinController,
        builder: (_, child) => Transform.rotate(
          angle: _spinController.value * 2 * math.pi,
          child: child,
        ),
        child: Icon(visual.icon, size: 18, color: visual.iconColor),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(
        visual.icon,
        key: ValueKey(visual.icon),
        size: 18,
        color: visual.iconColor,
      ),
    );
  }

  Widget _buildProgressPill(SyncStatus status) {
    final total = status.batchSize > 0 ? status.batchSize : 1;
    final progress = status.totalFlushed / total;

    return Container(
      width: 48,
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: const Color(0xFFBBDEFB),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: const Color(0xFF1565C0),
          ),
        ),
      ),
    );
  }

  Widget _buildRetryButton(_SyncVisual visual) {
    return GestureDetector(
      onTap: () => visual.onTap?.call(ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: visual.retryButtonColor,
        ),
        child: Text(
          'Retry',
          style: TextStyle(
            color: visual.retryTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  _SyncVisual _resolveVisual(SyncStatus syncStatus, bool isOffline) {
    // Priority 1: Actively syncing
    if (syncStatus.phase == SyncPhase.syncing) {
      final flushed = syncStatus.totalFlushed;
      final total = syncStatus.batchSize;
      return _SyncVisual(
        icon: Icons.sync_rounded,
        iconColor: const Color(0xFF1565C0),
        backgroundColor: const Color(0xFFE3F2FD),
        borderColor: const Color(0xFFBBDEFB),
        textColor: const Color(0xFF0D47A1),
        text: total > 0 ? 'Syncing $flushed of $total...' : 'Syncing...',
        spinning: true,
        showProgress: true,
      );
    }

    // Priority 2: Error with failed mutations
    if (syncStatus.failedCount > 0) {
      final count = syncStatus.failedCount;
      return _SyncVisual(
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFC62828),
        backgroundColor: const Color(0xFFFFEBEE),
        borderColor: const Color(0xFFEF9A9A),
        textColor: const Color(0xFFB71C1C),
        text: '$count sync ${count == 1 ? 'error' : 'errors'}',
        showRetry: true,
        retryButtonColor: const Color(0xFFC62828),
        retryTextColor: Colors.white,
        onTap: (ref) {
          ref.read(syncEngineProvider).flush();
        },
      );
    }

    // Priority 3: Offline with pending mutations
    if (isOffline && syncStatus.pendingCount > 0) {
      final count = syncStatus.pendingCount;
      return _SyncVisual(
        icon: Icons.cloud_off_rounded,
        iconColor: const Color(0xFFE65100),
        backgroundColor: const Color(0xFFFFF3E0),
        borderColor: const Color(0xFFFFCC80),
        textColor: const Color(0xFFBF360C),
        text: '$count ${count == 1 ? 'change' : 'changes'} pending',
      );
    }

    // Priority 4: Offline (no pending)
    if (isOffline) {
      return _SyncVisual(
        icon: Icons.wifi_off_rounded,
        iconColor: const Color(0xFF757575),
        backgroundColor: const Color(0xFFF5F5F5),
        borderColor: const Color(0xFFE0E0E0),
        textColor: const Color(0xFF616161),
        text: 'Offline',
      );
    }

    // Priority 5: Online with pending mutations (queued but not yet syncing)
    if (syncStatus.pendingCount > 0) {
      final count = syncStatus.pendingCount;
      return _SyncVisual(
        icon: Icons.cloud_upload_outlined,
        iconColor: const Color(0xFF1565C0),
        backgroundColor: const Color(0xFFE3F2FD),
        borderColor: const Color(0xFFBBDEFB),
        textColor: const Color(0xFF0D47A1),
        text: 'Uploading $count ${count == 1 ? 'change' : 'changes'}...',
        spinning: true,
      );
    }

    // Priority 6: All synced
    return _SyncVisual(
      icon: Icons.cloud_done_rounded,
      iconColor: const Color(0xFF2E7D32),
      backgroundColor: const Color(0xFFE8F5E9),
      borderColor: const Color(0xFFA5D6A7),
      textColor: const Color(0xFF1B5E20),
      text: 'All changes synced',
    );
  }
}

class _SyncVisual {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final String text;
  final bool spinning;
  final bool showProgress;
  final bool showRetry;
  final Color? retryButtonColor;
  final Color? retryTextColor;
  final void Function(WidgetRef ref)? onTap;

  _SyncVisual({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.text,
    this.spinning = false,
    this.showProgress = false,
    this.showRetry = false,
    this.retryButtonColor,
    this.retryTextColor,
    this.onTap,
  });
}
