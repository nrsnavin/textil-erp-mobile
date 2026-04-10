import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/grn_provider.dart';
import '../../../core/models/models.dart';
import '../../../shared/widgets/app_drawer.dart';

class GrnListScreen extends ConsumerStatefulWidget {
  const GrnListScreen({super.key});

  @override
  ConsumerState<GrnListScreen> createState() => _GrnListScreenState();
}

class _GrnListScreenState extends ConsumerState<GrnListScreen> {
  GrnFilter _filter = const GrnFilter();

  static const _statuses = ['DRAFT', 'POSTED'];

  @override
  Widget build(BuildContext context) {
    final grnsAsync = ref.watch(grnsProvider(_filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Goods Received Notes')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search GRN number…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = _filter.copyWith(search: v, page: 1)),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _StatusChip(
                  label: 'All',
                  selected: _filter.status == null,
                  color: Colors.blueGrey,
                  onTap: () => setState(() => _filter = _filter.copyWith(status: null, page: 1)),
                ),
                const SizedBox(width: 6),
                ..._statuses.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _StatusChip(
                    label: s,
                    selected: _filter.status == s,
                    color: s == 'POSTED' ? Colors.green : Colors.orange,
                    onTap: () => setState(() => _filter = _filter.copyWith(status: s, page: 1)),
                  ),
                )),
              ],
            ),
          ),
          Expanded(
            child: grnsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('Error: $e')),
              data:    (page) {
                if (page.data.isEmpty) {
                  return const Center(child: Text('No GRNs found'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(grnsProvider(_filter)),
                  child: ListView.builder(
                    itemCount: page.data.length,
                    itemBuilder: (_, i) => _GrnTile(
                      grn: page.data[i],
                      onTap: () => context.go('/grn/${page.data[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _filter.page > 1
                    ? () => setState(() => _filter = _filter.copyWith(page: _filter.page - 1))
                    : null,
              ),
              Text('Page ${_filter.page}', style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _filter = _filter.copyWith(page: _filter.page + 1)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _GrnTile extends StatelessWidget {
  final Grn grn;
  final VoidCallback onTap;
  const _GrnTile({required this.grn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPosted = grn.status == 'POSTED';
    final statusColor = isPosted ? Colors.green : Colors.orange;
    final fmt = DateFormat('dd MMM yyyy');
    final receivedDate = DateTime.tryParse(grn.grnDate);

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(children: [
          Text(grn.grnNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(26),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withAlpha(80)),
            ),
            child: Text(grn.status,
                style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
          ),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 4),
          if (grn.supplier != null)
            Text(grn.supplier!.name, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(receivedDate != null ? fmt.format(receivedDate) : '—',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const Spacer(),
            Text('${grn.lines.length} line${grn.lines.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ]),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? color : color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(selected ? 255 : 80)),
      ),
      child: Text(label, style: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : color,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
    ),
  );
}
