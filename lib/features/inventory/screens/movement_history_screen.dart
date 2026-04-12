import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/inventory_provider.dart';
import '../../../core/theme/app_theme.dart';

class MovementHistoryScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String itemName;
  final String location;

  const MovementHistoryScreen({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.location,
  });

  @override
  ConsumerState<MovementHistoryScreen> createState() => _MovementHistoryScreenState();
}

class _MovementHistoryScreenState extends ConsumerState<MovementHistoryScreen> {
  int _page = 1;
  String? _entryTypeFilter;

  MovementFilter get _filter => MovementFilter(
    itemId:    widget.itemId,
    location:  widget.location,
    entryType: _entryTypeFilter,
    page:      _page,
  );

  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(movementHistoryProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Movement History', style: TextStyle(fontSize: 16)),
            Text('${widget.itemName}  ·  ${widget.location}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textTertiary)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Entry type filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _FilterChip(label: 'All', selected: _entryTypeFilter == null,
                    onTap: () => setState(() { _entryTypeFilter = null; _page = 1; })),
                const SizedBox(width: 6),
                for (final type in ['GRN_IN','OPENING_STOCK','ISSUE_TO_PROD','RETURN_FROM_PROD','ADJUSTMENT','TRANSFER_IN','TRANSFER_OUT'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: ledgerEntryLabel(type),
                      selected: _entryTypeFilter == type,
                      color: ledgerEntryColor(type),
                      onTap: () => setState(() { _entryTypeFilter = type; _page = 1; }),
                    ),
                  ),
              ],
            ),
          ),

          // List
          Expanded(
            child: movementsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
              data:    (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.history_rounded, size: 48, color: AppColors.textTertiary),
                      const SizedBox(height: 8),
                      const Text('No movements recorded yet', style: TextStyle(color: AppColors.textTertiary)),
                    ]),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async => ref.invalidate(movementHistoryProvider(_filter)),
                  child: ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (_, i) => _MovementTile(entry: entries[i]),
                  ),
                );
              },
            ),
          ),

          // Pagination
          _Pager(
            page: _page,
            onPrev: _page > 1 ? () => setState(() => _page--) : null,
            onNext: () => setState(() => _page++),
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final dynamic entry;
  const _MovementTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final qty    = entry.qty as double;
    final isIn   = qty > 0;
    final color  = ledgerEntryColor(entry.entryType as String);
    final dt     = DateTime.tryParse(entry.createdAt as String? ?? '') ?? DateTime.now();
    final fmt    = DateFormat('dd MMM yy, HH:mm');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isIn ? Icons.add_circle_outline : Icons.remove_circle_outline,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withAlpha(18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ledgerEntryLabel(entry.entryType as String),
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${isIn ? '+' : ''}${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isIn ? AppColors.success : AppColors.error,
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Text('Balance: ', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  Text(
                    (entry.balanceQty as double).toStringAsFixed(0),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  if (entry.refType != null) ...[
                    const SizedBox(width: 8),
                    Text('${entry.refType}', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                  ],
                ]),
                if (entry.remarks != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(entry.remarks as String,
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                  ),
                Text(fmt.format(dt), style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String   label;
  final bool     selected;
  final Color?   color;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? c.withAlpha(80) : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? c : AppColors.textTertiary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            )),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  final int page;
  final VoidCallback? onPrev;
  final VoidCallback  onNext;

  const _Pager({required this.page, this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(children: [
      IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 22), onPressed: onPrev),
      Text('Page $page', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
      IconButton(icon: const Icon(Icons.chevron_right_rounded, size: 22), onPressed: onNext),
    ]),
  );
}
