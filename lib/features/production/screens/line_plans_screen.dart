import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/production_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_drawer.dart';

class LinePlansScreen extends ConsumerWidget {
  const LinePlansScreen({super.key});

  static Color _efficiencyColor(double? eff) {
    if (eff == null) return AppColors.textTertiary;
    if (eff >= 90) return AppColors.success;
    if (eff >= 70) return AppColors.warning;
    return AppColors.error;
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'SCHEDULED': return AppColors.info;
      case 'RUNNING':   return AppColors.warning;
      case 'COMPLETED': return AppColors.success;
      case 'CANCELLED': return AppColors.error;
      default:          return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lineAsync = ref.watch(linePlansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Line Plans')),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async => ref.invalidate(linePlansProvider),
        child: lineAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: AppColors.error)),
          ),
          data: (d) {
            final items = (d['data'] as List<dynamic>?) ?? [];
            if (items.isEmpty) {
              return const Center(
                child: Text('No line plans yet', style: TextStyle(color: AppColors.textTertiary)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final lp = items[i] as Map<String, dynamic>;
                final status   = lp['status'] as String? ?? '';
                final lineNum  = lp['lineNumber'] as String? ?? '';
                final style    = lp['styleCode'] as String? ?? '';
                final target   = lp['targetQty'] ?? 0;
                final achieved = lp['achievedQty'] ?? 0;
                final reject   = lp['rejectQty'] ?? 0;
                final eff      = lp['efficiency'] as num?;
                final effPct   = eff?.toDouble();
                final progress = target > 0 ? (achieved / target).clamp(0.0, 1.0) : 0.0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(lineNum,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(status,
                              style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text('Style: $style', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text('Target: $target', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                          const SizedBox(width: 12),
                          Text('Achieved: $achieved', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                          const SizedBox(width: 12),
                          Text('Reject: $reject', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                        ]),
                        const SizedBox(height: 4),
                        if (effPct != null)
                          Text(
                            'Efficiency: ${effPct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: _efficiencyColor(effPct),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.toDouble(),
                            backgroundColor: AppColors.border,
                            color: _efficiencyColor(effPct),
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
