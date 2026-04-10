import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/buyers_provider.dart';
import '../../../core/models/models.dart';
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
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search buyers…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() { _search = v; _page = 1; }),
            ),
          ),
          Expanded(
            child: buyersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('Error: $e')),
              data:    (resp) {
                if (resp.data.isEmpty) {
                  return const Center(child: Text('No buyers found'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(buyersProvider(params)),
                  child: ListView.builder(
                    itemCount: resp.data.length,
                    itemBuilder: (_, i) => _BuyerTile(buyer: resp.data[i]),
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
                onPressed: _page > 1 ? () => setState(() => _page--) : null,
              ),
              Text('Page $_page'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _page++),
              ),
            ]),
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
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1F3864).withAlpha(20),
          child: Text(buyer.name[0].toUpperCase(),
              style: const TextStyle(color: Color(0xFF1F3864), fontWeight: FontWeight.bold)),
        ),
        title: Row(children: [
          Text(buyer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (buyer.segment != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withAlpha(26),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Seg ${buyer.segment}',
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            ),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 2),
          Text('${buyer.country} · ${buyer.currency}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          if (buyer.email != null)
            Text(buyer.email!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
        trailing: Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: buyer.isActive ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
