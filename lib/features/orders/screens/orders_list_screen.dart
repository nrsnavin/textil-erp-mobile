import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/orders_provider.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_drawer.dart';

class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  OrderFilter _filter = const OrderFilter();

  static const _statuses = ['DRAFT','CONFIRMED','IN_PRODUCTION','QC_PASSED','DISPATCHED','CANCELLED'];

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider(_filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search by PO number...',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = _filter.copyWith(search: v, page: 1)),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _StatusChip(label: 'All', selected: _filter.status == null,
                    color: AppColors.textSecondary,
                    onTap: () => setState(() => _filter = _filter.copyWith(status: null, page: 1))),
                const SizedBox(width: 6),
                ..._statuses.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _StatusChip(
                    label: s.replaceAll('_', ' '),
                    selected: _filter.status == s,
                    color: orderStatusColor(s),
                    onTap: () => setState(() => _filter = _filter.copyWith(status: s, page: 1)),
                  ),
                )),
              ],
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
              data:    (page) {
                if (page.data.isEmpty) {
                  return const Center(child: Text('No orders found', style: TextStyle(color: AppColors.textTertiary)));
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async => ref.invalidate(ordersProvider(_filter)),
                  child: ListView.builder(
                    itemCount: page.data.length,
                    itemBuilder: (_, i) => _OrderTile(
                      order: page.data[i],
                      onTap: () => context.go('/orders/${page.data[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
          _Pager(
            meta: ordersAsync.value?.meta,
            page: _filter.page,
            onPrev: _filter.page > 1 ? () => setState(() => _filter = _filter.copyWith(page: _filter.page - 1)) : null,
            onNext: () => setState(() => _filter = _filter.copyWith(page: _filter.page + 1)),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const _OrderTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(order.status);
    final delivDate = DateTime.tryParse(order.deliveryDate);
    final fmt = DateFormat('dd MMM yyyy');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(order.poNumber, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.status.replaceAll('_', ' '),
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (order.buyer != null)
              Text(order.buyer!.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                delivDate != null ? fmt.format(delivDate) : '-',
                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              const Spacer(),
              Text(
                '${order.totalQty} pcs  ·  ${order.totalStyles} styles',
                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
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
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
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
    final total = meta?.total ?? 0;
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
