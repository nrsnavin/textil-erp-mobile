import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/production_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_drawer.dart';

class CutOrdersScreen extends ConsumerWidget {
  const CutOrdersScreen({super.key});

  static const _statuses = ['PLANNED', 'CUTTING', 'COMPLETED', 'CANCELLED'];

  static Color _statusColor(String status) {
    switch (status) {
      case 'PLANNED':   return AppColors.info;
      case 'CUTTING':   return AppColors.warning;
      case 'COMPLETED': return AppColors.success;
      case 'CANCELLED': return AppColors.error;
      default:          return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cutAsync = ref.watch(cutOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cut Orders')),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async => ref.invalidate(cutOrdersProvider),
        child: cutAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: AppColors.error)),
          ),
          data: (d) {
            final items = (d['data'] as List<dynamic>?) ?? [];
            if (items.isEmpty) {
              return const Center(
                child: Text('No cut orders yet', style: TextStyle(color: AppColors.textTertiary)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final co = items[i] as Map<String, dynamic>;
                final status   = co['status'] as String? ?? '';
                final cutNum   = co['cutOrderNumber'] as String? ?? '';
                final style    = co['styleCode'] as String? ?? '';
                final planned  = co['plannedQty'] ?? 0;
                final cut      = co['cutQty'] ?? 0;
                final progress = planned > 0 ? (cut / planned).clamp(0.0, 1.0) : 0.0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(cutNum,
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
                          Text('Planned: $planned', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                          const SizedBox(width: 16),
                          Text('Cut: $cut', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                        ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.toDouble(),
                            backgroundColor: AppColors.border,
                            color: _statusColor(status),
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
