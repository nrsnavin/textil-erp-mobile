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
        error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
        data:    (order) {
          final color = orderStatusColor(order.status);
          final delivDate = DateTime.tryParse(order.deliveryDate);
          final fmt = DateFormat('dd MMMM yyyy');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(order.poNumber, style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withAlpha(18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(order.status.replaceAll('_', ' '),
                            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                    ]),
                    if (order.buyer != null) ...[
                      const SizedBox(height: 10),
                      Text(order.buyer!.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                      Text('${order.buyer!.country}  ·  ${order.buyer!.currency}',
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                    ],
                  ]),
                ),
              ),

              // Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    _Row('Delivery Date', delivDate != null ? fmt.format(delivDate) : '-'),
                    _Row('Season', order.season ?? '-'),
                    _Row('Total Qty', '${order.totalQty} pcs'),
                    _Row('Styles', order.totalStyles.toString()),
                    if (order.remarks != null) _Row('Remarks', order.remarks!),
                  ]),
                ),
              ),

              // Timeline
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('Status Timeline', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
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
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary)),
    ]),
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
        padding: const EdgeInsets.all(20),
        child: isCancelled
            ? Row(children: [
                Icon(Icons.cancel_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: 10),
                const Text('Order Cancelled', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              ])
            : Column(
                children: List.generate(_steps.length, (i) {
                  final done   = i <= currentIdx;
                  final active = i == currentIdx;
                  final color  = done ? orderStatusColor(_steps[i]) : AppColors.border;

                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Column(children: [
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: done ? color.withAlpha(30) : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: done ? 2 : 1),
                        ),
                        child: done
                            ? Icon(Icons.check_rounded, size: 12, color: color)
                            : null,
                      ),
                      if (i < _steps.length - 1)
                        Container(width: 1.5, height: 22, color: done ? color.withAlpha(50) : AppColors.border),
                    ]),
                    const SizedBox(width: 14),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _steps[i].replaceAll('_', ' '),
                        style: TextStyle(
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          color: done ? AppColors.textPrimary : AppColors.textTertiary,
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
