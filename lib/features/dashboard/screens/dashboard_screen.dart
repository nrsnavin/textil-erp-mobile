import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/dashboard_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth  = ref.watch(authStateProvider).value;
    final stats = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardStatsProvider),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardStatsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${auth?.name ?? ''}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      auth?.role.replaceAll('_', ' ') ?? '',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Stats grid
              stats.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ErrorCard(message: e.toString()),
                ),
                data: (s) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 0,
                    crossAxisSpacing: 0,
                    childAspectRatio: 1.4,
                    children: [
                      StatCard(
                        title: 'Total Orders',
                        value: s.totalOrders.toString(),
                        icon: Icons.assignment_outlined,
                        color: const Color(0xFF1890FF),
                        onTap: () => context.go('/orders'),
                      ),
                      StatCard(
                        title: 'Active Orders',
                        value: s.activeOrders.toString(),
                        icon: Icons.pending_actions,
                        color: const Color(0xFFFAAD14),
                        onTap: () => context.go('/orders'),
                      ),
                      StatCard(
                        title: 'Stock Items',
                        value: s.stockItems.toString(),
                        icon: Icons.inventory_2_outlined,
                        color: const Color(0xFF52C41A),
                        onTap: () => context.go('/inventory'),
                      ),
                      StatCard(
                        title: 'Pending GRNs',
                        value: s.pendingGrns.toString(),
                        icon: Icons.receipt_long_outlined,
                        color: const Color(0xFF722ED1),
                        onTap: () => context.go('/grn'),
                      ),
                      StatCard(
                        title: 'Buyers',
                        value: s.totalBuyers.toString(),
                        icon: Icons.people_outline,
                        color: const Color(0xFF13C2C2),
                        onTap: () => context.go('/buyers'),
                      ),
                      StatCard(
                        title: 'Suppliers',
                        value: s.totalSuppliers.toString(),
                        icon: Icons.local_shipping_outlined,
                        color: const Color(0xFFEB2F96),
                        onTap: () => context.go('/suppliers'),
                      ),
                    ],
                  ),
                ),
              ),

              // Quick actions
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text('Quick Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              _QuickActions(),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.add_circle_outline, 'New Order',     '/orders',    const Color(0xFF1890FF)),
      (Icons.qr_code_scanner,   'Receive Goods',  '/grn',       const Color(0xFF52C41A)),
      (Icons.move_down,         'Issue Stock',    '/inventory', const Color(0xFFFA8C16)),
      (Icons.people_alt_outlined,'Add Buyer',     '/buyers',    const Color(0xFF722ED1)),
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final (icon, label, path, color) = actions[i];
          return InkWell(
            onTap: () => context.go(path),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 90,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(51)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 6),
                  Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.red.shade50,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
        ],
      ),
    ),
  );
}
