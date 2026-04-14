import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/production_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_drawer.dart';

class ProductionDashboardScreen extends ConsumerWidget {
  const ProductionDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cutAsync  = ref.watch(cutOrdersProvider);
    final lineAsync = ref.watch(linePlansProvider);
    final wipAsync  = ref.watch(wipRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Production')),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(cutOrdersProvider);
          ref.invalidate(linePlansProvider);
          ref.invalidate(wipRecordsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Summary Cards ──
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.content_cut_rounded,
                    label: 'Active Cut Orders',
                    value: cutAsync.when(
                      loading: () => '...',
                      error: (_, __) => '-',
                      data: (d) => '${(d['meta'] as Map<String, dynamic>?)?['total'] ?? 0}',
                    ),
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.linear_scale_rounded,
                    label: 'Lines Running',
                    value: lineAsync.when(
                      loading: () => '...',
                      error: (_, __) => '-',
                      data: (d) => '${(d['meta'] as Map<String, dynamic>?)?['total'] ?? 0}',
                    ),
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.pending_actions_rounded,
                    label: 'WIP Items',
                    value: wipAsync.when(
                      loading: () => '...',
                      error: (_, __) => '-',
                      data: (d) => '${(d['meta'] as Map<String, dynamic>?)?['total'] ?? 0}',
                    ),
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Production Status ──
            const Text('Production Status', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: cutAsync.when(
                loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.error, fontSize: 13)),
                data: (d) {
                  final items = (d['data'] as List<dynamic>?) ?? [];
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('No active production', style: TextStyle(color: AppColors.textTertiary))),
                    );
                  }
                  final active = items.where((i) {
                    final status = (i as Map<String, dynamic>)['status'] as String? ?? '';
                    return status == 'CUTTING' || status == 'PLANNED';
                  }).length;
                  final completed = items.where((i) {
                    final status = (i as Map<String, dynamic>)['status'] as String? ?? '';
                    return status == 'COMPLETED';
                  }).length;
                  return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _StatusStat(label: 'Active', count: active, color: AppColors.info),
                    _StatusStat(label: 'Completed', count: completed, color: AppColors.success),
                    _StatusStat(label: 'Total', count: items.length, color: AppColors.textSecondary),
                  ]);
                },
              ),
            ),

            const SizedBox(height: 24),

            // ── Quick Links ──
            const Text('Quick Links', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15)),
            const SizedBox(height: 10),
            _QuickLink(
              icon: Icons.content_cut_rounded,
              label: 'Cut Orders',
              subtitle: 'View and manage cut orders',
              onTap: () => context.go('/production/cut-orders'),
            ),
            _QuickLink(
              icon: Icons.linear_scale_rounded,
              label: 'Line Plans',
              subtitle: 'Sewing line assignments',
              onTap: () => context.go('/production/line-plans'),
            ),
            _QuickLink(
              icon: Icons.pending_actions_rounded,
              label: 'WIP Tracking',
              subtitle: 'Work-in-progress records',
              onTap: () => context.go('/production/wip'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _StatusStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusStat({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$count', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
  ]);
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickLink({required this.icon, required this.label, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 22),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
        onTap: onTap,
      ),
    );
  }
}
