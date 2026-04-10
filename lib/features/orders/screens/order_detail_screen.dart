import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/orders_provider.dart';
import '../../../core/theme/app_theme.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (order) {
          final color = orderStatusColor(order.status);
          final delivDate = DateTime.tryParse(order.deliveryDate);
          final fmt = DateFormat('dd MMMM yyyy');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(order.poNumber,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      _Badge(label: order.status.replaceAll('_', ' '), color: color),
                    ]),
                    if (order.buyer != null) ...[
                      const SizedBox(height: 6),
                      Text(order.buyer!.name,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
                      Text('${order.buyer!.country} · ${order.buyer!.currency}',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ]),
                ),
              ),

              // Info rows
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    _Row('Delivery Date', delivDate != null ? fmt.format(delivDate) : '—'),
                    _Row('Season',  order.season  ?? '—'),
                    _Row('Total Qty', '${order.totalQty} pcs'),
                    _Row('Styles',  order.totalStyles.toString()),
                    if (order.remarks != null) _Row('Remarks', order.remarks!),
                  ]),
                ),
              ),

              // Status timeline
              const SizedBox(height: 8),
              const Text('Status Timeline',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _StatusTimeline(currentStatus: order.status),
            ]),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
    ]),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(26),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withAlpha(80)),
    ),
    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
  );
}

class _StatusTimeline extends StatelessWidget {
  final String currentStatus;
  const _StatusTimeline({required this.currentStatus});

  static const _steps = ['DRAFT','CONFIRMED','IN_PRODUCTION','QC_PASSED','DISPATCHED'];

  @override
  Widget build(BuildContext context) {
    final isCancelled = currentStatus == 'CANCELLED';
    final currentIdx  = _steps.indexOf(currentStatus);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isCancelled
            ? Row(children: [
                const Icon(Icons.cancel, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Order Cancelled', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ])
            : Column(
                children: List.generate(_steps.length, (i) {
                  final done   = i <= currentIdx;
                  final active = i == currentIdx;
                  final color  = done ? orderStatusColor(_steps[i]) : Colors.grey.shade300;

                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Column(children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: done ? color : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 2),
                        ),
                        child: done
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                      if (i < _steps.length - 1)
                        Container(width: 2, height: 24, color: done ? color : Colors.grey.shade200),
                    ]),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _steps[i].replaceAll('_', ' '),
                        style: TextStyle(
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          color: done ? Colors.black87 : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ]);
                }),
              ),
      ),
    );
  }
}
