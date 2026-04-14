import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/production_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_drawer.dart';

class WipRecordsScreen extends ConsumerWidget {
  const WipRecordsScreen({super.key});

  static Color _stageColor(String stage) {
    switch (stage) {
      case 'CUTTING':   return AppColors.info;
      case 'SEWING':    return AppColors.warning;
      case 'FINISHING':  return AppColors.accent;
      case 'PACKING':   return AppColors.success;
      default:          return AppColors.textTertiary;
    }
  }

  static IconData _stageIcon(String stage) {
    switch (stage) {
      case 'CUTTING':   return Icons.content_cut_rounded;
      case 'SEWING':    return Icons.checkroom_rounded;
      case 'FINISHING':  return Icons.auto_fix_high_rounded;
      case 'PACKING':   return Icons.inventory_2_rounded;
      default:          return Icons.pending_actions_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wipAsync = ref.watch(wipRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('WIP Tracking')),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async => ref.invalidate(wipRecordsProvider),
        child: wipAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: AppColors.error)),
          ),
          data: (d) {
            final items = (d['data'] as List<dynamic>?) ?? [];
            if (items.isEmpty) {
              return const Center(
                child: Text('No WIP records yet', style: TextStyle(color: AppColors.textTertiary)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final wip = items[i] as Map<String, dynamic>;
                final stage    = wip['stage'] as String? ?? '';
                final style    = wip['styleCode'] as String? ?? '';
                final inputQ   = wip['inputQty'] ?? 0;
                final outputQ  = wip['outputQty'] ?? 0;
                final rejectQ  = wip['rejectQty'] ?? 0;
                final progress = inputQ > 0 ? (outputQ / inputQ).clamp(0.0, 1.0) : 0.0;
                final pct      = (progress * 100).toStringAsFixed(0);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(_stageIcon(stage), color: _stageColor(stage), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(stage,
                              style: TextStyle(fontWeight: FontWeight.w600, color: _stageColor(stage), fontSize: 14)),
                          ),
                          Text('$pct%',
                            style: TextStyle(fontWeight: FontWeight.w700, color: _stageColor(stage), fontSize: 14)),
                        ]),
                        const SizedBox(height: 8),
                        Text('Style: $style', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 6),
                        Row(children: [
                          _WipStat(label: 'Input', value: '$inputQ', color: AppColors.textPrimary),
                          const SizedBox(width: 16),
                          _WipStat(label: 'Output', value: '$outputQ', color: AppColors.success),
                          const SizedBox(width: 16),
                          _WipStat(label: 'Reject', value: '$rejectQ', color: AppColors.error),
                        ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.toDouble(),
                            backgroundColor: AppColors.border,
                            color: _stageColor(stage),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _WipStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _WipStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    ],
  );
}
