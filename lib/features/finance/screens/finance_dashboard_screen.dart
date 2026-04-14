import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_drawer.dart';

class FinanceDashboardScreen extends ConsumerWidget {
  const FinanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arAsync    = ref.watch(arSummaryProvider);
    final apAsync    = ref.watch(apSummaryProvider);
    final agingAsync = ref.watch(agingProvider);
    final recentAsync = ref.watch(invoicesProvider(const InvoiceFilter(page: 1, limit: 5)));
    final fmt = NumberFormat.compact();

    return Scaffold(
      appBar: AppBar(title: const Text('Finance')),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(arSummaryProvider);
          ref.invalidate(apSummaryProvider);
          ref.invalidate(agingProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── AR / AP Summary Cards ──
            Row(
              children: [
                Expanded(
                  child: arAsync.when(
                    loading: () => _SummaryCard.loading(label: 'Receivable'),
                    error: (e, _) => _SummaryCard(label: 'Receivable', value: '-', sub: 'Error', color: AppColors.error),
                    data: (ar) => _SummaryCard(
                      label: 'Total Receivable',
                      value: fmt.format(ar['totalReceivable'] ?? 0),
                      sub: '${ar['overdueCount'] ?? 0} overdue',
                      color: AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: apAsync.when(
                    loading: () => _SummaryCard.loading(label: 'Payable'),
                    error: (e, _) => _SummaryCard(label: 'Payable', value: '-', sub: 'Error', color: AppColors.error),
                    data: (ap) => _SummaryCard(
                      label: 'Total Payable',
                      value: fmt.format(ap['totalPayable'] ?? 0),
                      sub: '${ap['overdueCount'] ?? 0} overdue',
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Aging Buckets ──
            const Text('Aging Buckets', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15)),
            const SizedBox(height: 10),
            agingAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.error)),
              data: (aging) {
                final buckets = aging['buckets'] as List<dynamic>? ?? [];
                if (buckets.isEmpty) {
                  return const Text('No aging data', style: TextStyle(color: AppColors.textTertiary));
                }
                return Row(
                  children: buckets.map<Widget>((b) {
                    final bucket = b as Map<String, dynamic>;
                    return Expanded(
                      child: _AgingBucket(
                        label: bucket['label'] as String? ?? '',
                        amount: (bucket['amount'] ?? 0).toDouble(),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Quick Actions ──
            const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.receipt_long_outlined,
                    label: 'Create Invoice',
                    onTap: () => context.go('/finance/invoices/create'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.payment_outlined,
                    label: 'Record Payment',
                    onTap: () => context.go('/finance/payments/record'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Recent Invoices ──
            Row(
              children: [
                const Text('Recent Invoices', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go('/finance/invoices'),
                  child: const Text('View All', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            recentAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.error)),
              data: (page) {
                final invoices = (page['data'] as List<dynamic>?) ?? [];
                if (invoices.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No invoices yet', style: TextStyle(color: AppColors.textTertiary))),
                  );
                }
                return Column(
                  children: invoices.map<Widget>((inv) {
                    final invoice = inv as Map<String, dynamic>;
                    final status = invoice['status'] as String? ?? 'DRAFT';
                    final color = invoiceStatusColor(status);
                    return Card(
                      child: ListTile(
                        dense: true,
                        title: Text(
                          invoice['invoiceNo'] as String? ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                        ),
                        subtitle: Text(
                          invoice['buyerName'] as String? ?? '-',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              fmt.format(invoice['total'] ?? 0),
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withAlpha(18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        onTap: () => context.go('/finance/invoices/${invoice['id']}'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Color invoiceStatusColor(String status) => switch (status) {
  'SENT'      => const Color(0xFF60A5FA),
  'PARTIAL'   => const Color(0xFFFBBF24),
  'PAID'      => const Color(0xFF4ADE80),
  'OVERDUE'   => const Color(0xFFF87171),
  'CANCELLED' => const Color(0xFF6B7280),
  _           => const Color(0xFF8B8B95), // DRAFT
};

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color  color;
  final bool   loading;

  const _SummaryCard({required this.label, required this.value, required this.sub, required this.color, this.loading = false});

  _SummaryCard.loading({required this.label}) : value = '', sub = '', color = AppColors.textTertiary, loading = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: loading
          ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ]),
    );
  }
}

class _AgingBucket extends StatelessWidget {
  final String label;
  final double amount;

  const _AgingBucket({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(fmt.format(amount), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
