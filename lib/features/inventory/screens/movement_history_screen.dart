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
            Text('${widget.itemName} • ${widget.location}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Entry type filter chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              error:   (e, _) => Center(child: Text('Error: $e')),
              data:    (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.history, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No movements recorded yet', style: TextStyle(color: Colors.grey)),
                    ]),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(movementHistoryProvider(_filter)),
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _MovementTile(entry: entries[i]),
                  ),
                );
              },
            ),
          ),

          // Pagination
          _Pagination(page: _page, onPrev: _page > 1 ? () => setState(() => _page--) : null,
              onNext: () => setState(() => _page++)),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final dynamic entry; // StockLedgerEntry
  const _MovementTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final qty    = entry.qty as double;
    final isIn   = qty > 0;
    final color  = ledgerEntryColor(entry.entryType as String);
    final dt     = DateTime.tryParse(entry.createdAt as String? ?? '') ?? DateTime.now();
    final fmt    = DateFormat('dd MMM yy, HH:mm');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isIn ? Icons.add_circle_outline : Icons.remove_circle_outline,
          color: color,
          size: 22,
        ),
      ),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            ledgerEntryLabel(entry.entryType as String),
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
          ),
        ),
        const Spacer(),
        Text(
          '${isIn ? '+' : ''}${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isIn ? const Color(0xFF389E0D) : const Color(0xFFCF1322),
          ),
        ),
      ]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 2),
        Row(children: [
          Text('Balance: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Text(
            (entry.balanceQty as double).toStringAsFixed(0),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (entry.refType != null) ...[
            const SizedBox(width: 8),
            Text('${entry.refType}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
          ],
        ]),
        if (entry.remarks != null)
          Text(entry.remarks as String,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        Text(fmt.format(dt), style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
      ]),
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
    final c = color ?? const Color(0xFF1F3864);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? c : c.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withAlpha(selected ? 255 : 80)),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : c,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  final int page;
  final VoidCallback? onPrev;
  final VoidCallback  onNext;

  const _Pagination({required this.page, this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
      Text('Page $page', style: const TextStyle(fontWeight: FontWeight.w600)),
      IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
    ]),
  );
}
