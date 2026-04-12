import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/connectivity_monitor.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_provider.dart';
import '../../core/theme/app_theme.dart';

/// Pixel-perfect sync status bar for dark theme.
///
/// ## States and visual treatment:
///
/// | State             | Background          | Icon       | Text                  |
/// |-------------------|---------------------|------------|-----------------------|
/// | All synced        | success/8           | check      | "All changes synced"  |
/// | Offline + pending | warning/8           | cloud_off  | "12 changes pending"  |
/// | Syncing           | primary/8           | sync       | "Syncing 3 of 12..."  |
/// | Error             | error/8             | error      | "Sync failed · Retry" |
/// | Offline (idle)    | border              | wifi_off   | "Offline"             |
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

    final visual = _resolveVisual(syncStatus, isOffline);

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
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
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
                _buildIcon(visual),
                const SizedBox(width: 10),
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
                if (visual.showProgress) ...[
                  const SizedBox(width: 8),
                  _buildProgressPill(syncStatus),
                ],
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
        color: AppColors.primary.withAlpha(30),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: AppColors.primary,
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
          borderRadius: BorderRadius.circular(6),
          color: AppColors.error.withAlpha(30),
          border: Border.all(color: AppColors.error.withAlpha(60)),
        ),
        child: const Text(
          'Retry',
          style: TextStyle(
            color: AppColors.error,
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
        iconColor: AppColors.primary,
        backgroundColor: AppColors.primary.withAlpha(8),
        textColor: AppColors.primary,
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
        iconColor: AppColors.error,
        backgroundColor: AppColors.error.withAlpha(8),
        textColor: AppColors.error,
        text: '$count sync ${count == 1 ? 'error' : 'errors'}',
        showRetry: true,
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
        iconColor: AppColors.warning,
        backgroundColor: AppColors.warning.withAlpha(8),
        textColor: AppColors.warning,
        text: '$count ${count == 1 ? 'change' : 'changes'} pending',
      );
    }

    // Priority 4: Offline (no pending)
    if (isOffline) {
      return _SyncVisual(
        icon: Icons.wifi_off_rounded,
        iconColor: AppColors.textTertiary,
        backgroundColor: AppColors.border.withAlpha(40),
        textColor: AppColors.textTertiary,
        text: 'Offline',
      );
    }

    // Priority 5: Online with pending mutations (queued but not yet syncing)
    if (syncStatus.pendingCount > 0) {
      final count = syncStatus.pendingCount;
      return _SyncVisual(
        icon: Icons.cloud_upload_outlined,
        iconColor: AppColors.primary,
        backgroundColor: AppColors.primary.withAlpha(8),
        textColor: AppColors.primary,
        text: 'Uploading $count ${count == 1 ? 'change' : 'changes'}...',
        spinning: true,
      );
    }

    // Priority 6: All synced
    return _SyncVisual(
      icon: Icons.cloud_done_rounded,
      iconColor: AppColors.success,
      backgroundColor: AppColors.success.withAlpha(8),
      textColor: AppColors.success,
      text: 'All changes synced',
    );
  }
}

class _SyncVisual {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color textColor;
  final String text;
  final bool spinning;
  final bool showProgress;
  final bool showRetry;
  final void Function(WidgetRef ref)? onTap;

  _SyncVisual({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.textColor,
    required this.text,
    this.spinning = false,
    this.showProgress = false,
    this.showRetry = false,
    this.onTap,
  });
}
