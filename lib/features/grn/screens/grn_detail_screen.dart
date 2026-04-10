import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/grn_provider.dart';
import '../../../core/api/api_client.dart';

class GrnDetailScreen extends ConsumerWidget {
  final String grnId;
  const GrnDetailScreen({super.key, required this.grnId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grnAsync = ref.watch(grnDetailProvider(grnId));

    return Scaffold(
      appBar: AppBar(title: const Text('GRN Details')),
      body: grnAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (grn) {
          final isPosted = grn.status == 'POSTED';
          final statusColor = isPosted ? Colors.green : Colors.orange;
          final fmt = DateFormat('dd MMMM yyyy');
          final receivedDate = DateTime.tryParse(grn.grnDate);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(grn.grnNumber,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(26),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withAlpha(80)),
                        ),
                        child: Text(grn.status,
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ]),
                    if (grn.supplier != null) ...[
                      const SizedBox(height: 6),
                      Text(grn.supplier!.name,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
                    ],
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        receivedDate != null ? fmt.format(receivedDate) : '—',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(grn.location,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ]),
                  ]),
                ),
              ),

              // Lines
              const SizedBox(height: 8),
              Text('Items (${grn.lines.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...grn.lines.map((line) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      line.item?.name ?? line.itemId,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (line.item != null)
                      Text(line.item!.code,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    Row(children: [
                      _LineInfo('Ordered', '${line.qty} ${line.item?.unit ?? ''}'),
                      const SizedBox(width: 24),
                      _LineInfo('Accepted',
                          line.acceptedQty != null
                              ? '${line.acceptedQty} ${line.item?.unit ?? ''}'
                              : '—'),
                      const SizedBox(width: 24),
                      _LineInfo('Rate', line.rate.toString()),
                    ]),
                  ]),
                ),
              )),

              // Post GRN button (only for DRAFT)
              if (!isPosted) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _postGrn(context, ref),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Post GRN to Inventory'),
                  ),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }

  Future<void> _postGrn(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Post GRN'),
        content: const Text(
            'This will update inventory balances and cannot be undone. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Post')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/api/v1/grn/$grnId/post', data: {});
      ref.invalidate(grnDetailProvider(grnId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GRN posted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _LineInfo extends StatelessWidget {
  final String label;
  final String value;
  const _LineInfo(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    const SizedBox(height: 2),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
  ]);
}
