import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/grn_provider.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search GRN number...',
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
                    color: s == 'POSTED' ? AppColors.success : AppColors.warning,
                    onTap: () => setState(() => _filter = _filter.copyWith(status: s, page: 1)),
                  ),
                )),
              ],
            ),
          ),
          Expanded(
            child: grnsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
              data:    (page) {
                if (page.data.isEmpty) {
                  return const Center(child: Text('No GRNs found', style: TextStyle(color: AppColors.textTertiary)));
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
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
          _Pager(
            page: _filter.page,
            onPrev: _filter.page > 1
                ? () => setState(() => _filter = _filter.copyWith(page: _filter.page - 1))
                : null,
            onNext: () => setState(() => _filter = _filter.copyWith(page: _filter.page + 1)),
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
    final statusColor = isPosted ? AppColors.success : AppColors.warning;
    final fmt = DateFormat('dd MMM yyyy');
    final receivedDate = DateTime.tryParse(grn.grnDate);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(grn.grnNumber, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(grn.status,
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
              ),
            ]),
            if (grn.supplier != null) ...[
              const SizedBox(height: 8),
              Text(grn.supplier!.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(receivedDate != null ? fmt.format(receivedDate) : '-',
                  style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              const Spacer(),
              Text('${grn.lines.length} line${grn.lines.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
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
  final int page;
  final VoidCallback? onPrev;
  final VoidCallback onNext;
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
