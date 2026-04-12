import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/buyers_provider.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_drawer.dart';

class BuyersListScreen extends ConsumerStatefulWidget {
  const BuyersListScreen({super.key});

  @override
  ConsumerState<BuyersListScreen> createState() => _BuyersListScreenState();
}

class _BuyersListScreenState extends ConsumerState<BuyersListScreen> {
  int _page = 1;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final params = BuyerFilter(page: _page, search: _search.isNotEmpty ? _search : null);
    final buyersAsync = ref.watch(buyersProvider(params));

    return Scaffold(
      appBar: AppBar(title: const Text('Buyers')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search buyers...',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() { _search = v; _page = 1; }),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: buyersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
              data:    (resp) {
                if (resp.data.isEmpty) {
                  return const Center(child: Text('No buyers found', style: TextStyle(color: AppColors.textTertiary)));
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async => ref.invalidate(buyersProvider(params)),
                  child: ListView.builder(
                    itemCount: resp.data.length,
                    itemBuilder: (_, i) => _BuyerTile(buyer: resp.data[i]),
                  ),
                );
              },
            ),
          ),
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

class _BuyerTile extends StatelessWidget {
  final Buyer buyer;
  const _BuyerTile({required this.buyer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  buyer.name[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(buyer.name, style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
                  ),
                  if (buyer.segment != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Seg ${buyer.segment}',
                          style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                    ),
                ]),
                const SizedBox(height: 4),
                Text('${buyer.country}  ·  ${buyer.currency}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (buyer.email != null)
                  Text(buyer.email!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              ]),
            ),
            const SizedBox(width: 10),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: buyer.isActive ? AppColors.success : AppColors.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
          ]),
        ),
      ),
    );
  }
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
