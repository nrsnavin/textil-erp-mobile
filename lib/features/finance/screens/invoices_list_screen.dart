import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_drawer.dart';
import 'finance_dashboard_screen.dart' show invoiceStatusColor;

class InvoicesListScreen extends ConsumerStatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  ConsumerState<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends ConsumerState<InvoicesListScreen> {
  InvoiceFilter _filter = const InvoiceFilter(type: 'SALES');

  static const _statuses = ['DRAFT', 'SENT', 'PARTIAL', 'PAID', 'OVERDUE', 'CANCELLED'];

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider(_filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () => context.go('/finance/invoices/create'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Type Toggle ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _TypeToggle(
                  label: 'SALES',
                  selected: _filter.type == 'SALES',
                  onTap: () => setState(() => _filter = _filter.copyWith(type: 'SALES', page: 1)),
                ),
                const SizedBox(width: 8),
                _TypeToggle(
                  label: 'PURCHASE',
                  selected: _filter.type == 'PURCHASE',
                  onTap: () => setState(() => _filter = _filter.copyWith(type: 'PURCHASE', page: 1)),
                ),
              ],
            ),
          ),

          // ── Status Filter Chips ──
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _StatusChip(
                  label: 'All',
                  selected: _filter.status == null,
                  color: AppColors.textSecondary,
                  onTap: () => setState(() => _filter = _filter.copyWith(status: null, page: 1)),
                ),
                const SizedBox(width: 6),
                ..._statuses.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _StatusChip(
                    label: s,
                    selected: _filter.status == s,
                    color: invoiceStatusColor(s),
                    onTap: () => setState(() => _filter = _filter.copyWith(status: s, page: 1)),
                  ),
                )),
              ],
            ),
          ),

          // ── List ──
          Expanded(
            child: invoicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
              data: (page) {
                final invoices = (page['data'] as List<dynamic>?) ?? [];
                if (invoices.isEmpty) {
                  return const Center(child: Text('No invoices found', style: TextStyle(color: AppColors.textTertiary)));
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async => ref.invalidate(invoicesProvider(_filter)),
                  child: ListView.builder(
                    itemCount: invoices.length,
                    itemBuilder: (_, i) => _InvoiceTile(
                      invoice: invoices[i] as Map<String, dynamic>,
                      onTap: () => context.go('/finance/invoices/${invoices[i]['id']}'),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Pager ──
          _Pager(
            meta: invoicesAsync.value?['meta'],
            page: _filter.page,
            onPrev: _filter.page > 1 ? () => setState(() => _filter = _filter.copyWith(page: _filter.page - 1)) : null,
            onNext: () => setState(() => _filter = _filter.copyWith(page: _filter.page + 1)),
          ),
        ],
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onTap;
  const _InvoiceTile({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = invoice['status'] as String? ?? 'DRAFT';
    final color = invoiceStatusColor(status);
    final dueDate = DateTime.tryParse(invoice['dueDate'] as String? ?? '');
    final fmt = DateFormat('dd MMM yyyy');
    final numFmt = NumberFormat('#,##0.00');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(
                invoice['invoiceNo'] as String? ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              invoice['buyerName'] as String? ?? '-',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                dueDate != null ? fmt.format(dueDate) : '-',
                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              const Spacer(),
              Text(
                numFmt.format(invoice['total'] ?? 0),
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeToggle({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent.withAlpha(30) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? AppColors.accent.withAlpha(80) : AppColors.border),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12,
        color: selected ? AppColors.accent : AppColors.textTertiary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      )),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? color.withAlpha(30) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? color.withAlpha(80) : AppColors.border),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 11,
        color: selected ? color : AppColors.textTertiary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      )),
    ),
  );
}

class _Pager extends StatelessWidget {
  final dynamic meta;
  final int page;
  final VoidCallback? onPrev;
  final VoidCallback onNext;
  const _Pager({this.meta, required this.page, this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final total = (meta as Map<String, dynamic>?)?['total'] ?? 0;
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 22), onPressed: onPrev),
        Text('Page $page', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
        if (total > 0)
          Text('  of $total', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        IconButton(icon: const Icon(Icons.chevron_right_rounded, size: 22), onPressed: onNext),
      ]),
    );
  }
}
