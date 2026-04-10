import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/suppliers_provider.dart';
import '../../../core/models/models.dart';
import '../../../shared/widgets/app_drawer.dart';

class SuppliersListScreen extends ConsumerStatefulWidget {
  const SuppliersListScreen({super.key});

  @override
  ConsumerState<SuppliersListScreen> createState() => _SuppliersListScreenState();
}

class _SuppliersListScreenState extends ConsumerState<SuppliersListScreen> {
  int _page = 1;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final params = SupplierFilter(page: _page, search: _search.isNotEmpty ? _search : null);
    final suppliersAsync = ref.watch(suppliersProvider(params));

    return Scaffold(
      appBar: AppBar(title: const Text('Suppliers')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search suppliers…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() { _search = v; _page = 1; }),
            ),
          ),
          Expanded(
            child: suppliersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('Error: $e')),
              data:    (resp) {
                if (resp.data.isEmpty) {
                  return const Center(child: Text('No suppliers found'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(suppliersProvider(params)),
                  child: ListView.builder(
                    itemCount: resp.data.length,
                    itemBuilder: (_, i) => _SupplierTile(supplier: resp.data[i]),
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

class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  const _SupplierTile({required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1F3864).withAlpha(20),
          child: Text(supplier.name[0].toUpperCase(),
              style: const TextStyle(color: Color(0xFF1F3864), fontWeight: FontWeight.bold)),
        ),
        title: Row(children: [
          Expanded(
            child: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: supplier.isActive ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 2),
          if (supplier.contactName != null)
            Text(supplier.contactName!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          if (supplier.email != null)
            Text(supplier.email!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          if (supplier.phone != null)
            Text(supplier.phone!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }
}
