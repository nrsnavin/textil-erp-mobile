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
          // Search + status filter
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by PO number…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = _filter.copyWith(search: v, page: 1)),
            ),
          ),
          // Status chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _StatusChip(label: 'All', selected: _filter.status == null,
                    color: Colors.blueGrey,
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

          // List
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('Error: $e')),
              data:    (page) {
                if (page.data.isEmpty) {
                  return const Center(child: Text('No orders found'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(ordersProvider(_filter)),
                  child: ListView.builder(
                    itemCount: page.data.length,
                    itemBuilder: (_, i) => _OrderTile(
                      order: page.data[i],
                      onTap:  () => context.go('/orders/${page.data[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),

          // Pagination
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
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(children: [
          Text(order.poNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withAlpha(80)),
            ),
            child: Text(order.status.replaceAll('_', ' '),
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 4),
          if (order.buyer != null)
            Text(order.buyer!.name, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(delivDate != null ? fmt.format(delivDate) : '—',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const Spacer(),
            Text('${order.totalQty} pcs · ${order.totalStyles} styles',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ]),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String   label;
  final bool     selected;
  final Color    color;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? color : color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(selected ? 255 : 80)),
      ),
      child: Text(label, style: TextStyle(
          fontSize: 12, color: selected ? Colors.white : color,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
    ),
  );
}

class _Pager extends StatelessWidget {
  final dynamic meta;
  final int page;
  final VoidCallback? onPrev;
  final VoidCallback  onNext;
  const _Pager({this.meta, required this.page, this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final total = meta?.total ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
        Text('Page $page', style: const TextStyle(fontWeight: FontWeight.w600)),
        if (total > 0) Text(' of $total items',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
      ]),
    );
  }
}
