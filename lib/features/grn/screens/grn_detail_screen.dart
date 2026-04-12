import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/grn_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

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
        error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
        data:    (grn) {
          final isPosted = grn.status == 'POSTED';
          final statusColor = isPosted ? AppColors.success : AppColors.warning;
          final fmt = DateFormat('dd MMMM yyyy');
          final receivedDate = DateTime.tryParse(grn.grnDate);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(grn.grnNumber, style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(grn.status,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                    ]),
                    if (grn.supplier != null) ...[
                      const SizedBox(height: 10),
                      Text(grn.supplier!.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                    ],
                    const SizedBox(height: 10),
                    _InfoRow(Icons.calendar_today_outlined,
                        receivedDate != null ? fmt.format(receivedDate) : '-'),
                    const SizedBox(height: 4),
                    _InfoRow(Icons.location_on_outlined, grn.location),
                  ]),
                ),
              ),

              // Lines
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Items (${grn.lines.length})', style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 8),
              ...grn.lines.map((line) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      line.item?.name ?? line.itemId,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                    ),
                    if (line.item != null)
                      Text(line.item!.code,
                          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _LineInfo('Ordered', '${line.qty} ${line.item?.unit ?? ''}'),
                      const SizedBox(width: 24),
                      _LineInfo('Accepted',
                          line.acceptedQty != null
                              ? '${line.acceptedQty} ${line.item?.unit ?? ''}'
                              : '-'),
                      const SizedBox(width: 24),
                      _LineInfo('Rate', line.rate.toString()),
                    ]),
                  ]),
                ),
              )),

              // Post GRN button (only for DRAFT)
              if (!isPosted) ...[
                const SizedBox(height: 20),
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
          SnackBar(
            content: const Text('GRN posted successfully'),
            backgroundColor: AppColors.success.withAlpha(200),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.error.withAlpha(200),
          ),
        );
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: AppColors.textTertiary),
    const SizedBox(width: 6),
    Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
  ]);
}

class _LineInfo extends StatelessWidget {
  final String label;
  final String value;
  const _LineInfo(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
    const SizedBox(height: 2),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
  ]);
}
