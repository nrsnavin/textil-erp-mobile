import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/dashboard_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/sync_status_bar.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _syncInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_syncInitialized) {
        ref.read(syncEngineProvider).initialize();
        _syncInitialized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth  = ref.watch(authStateProvider).value;
    final stats = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => ref.invalidate(dashboardStatsProvider),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(children: [
        const SyncStatusBar(),
        Expanded(child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(dashboardStatsProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        auth?.name ?? '',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats grid
                stats.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(48),
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
                          color: const Color(0xFF60A5FA),
                          onTap: () => context.go('/orders'),
                        ),
                        StatCard(
                          title: 'Active Orders',
                          value: s.activeOrders.toString(),
                          icon: Icons.pending_actions_rounded,
                          color: const Color(0xFFFBBF24),
                          onTap: () => context.go('/orders'),
                        ),
                        StatCard(
                          title: 'Stock Items',
                          value: s.stockItems.toString(),
                          icon: Icons.inventory_2_outlined,
                          color: const Color(0xFF4ADE80),
                          onTap: () => context.go('/inventory'),
                        ),
                        StatCard(
                          title: 'Pending GRNs',
                          value: s.pendingGrns.toString(),
                          icon: Icons.receipt_long_outlined,
                          color: const Color(0xFFA78BFA),
                          onTap: () => context.go('/grn'),
                        ),
                        StatCard(
                          title: 'Buyers',
                          value: s.totalBuyers.toString(),
                          icon: Icons.people_outline_rounded,
                          color: const Color(0xFF2DD4BF),
                          onTap: () => context.go('/buyers'),
                        ),
                        StatCard(
                          title: 'Suppliers',
                          value: s.totalSuppliers.toString(),
                          icon: Icons.local_shipping_outlined,
                          color: const Color(0xFFF472B6),
                          onTap: () => context.go('/suppliers'),
                        ),
                      ],
                    ),
                  ),
                ),

                // Quick actions
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Quick actions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _QuickActions(),
              ],
            ),
          ),
        )),
      ]),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.add_circle_outline_rounded, 'New Order',     '/orders',    const Color(0xFF60A5FA)),
      (Icons.qr_code_scanner_rounded,    'Receive Goods', '/grn',       const Color(0xFF4ADE80)),
      (Icons.outbox_rounded,             'Issue Stock',   '/inventory', const Color(0xFFFBBF24)),
      (Icons.person_add_outlined,        'Add Buyer',     '/buyers',    const Color(0xFFA78BFA)),
    ];

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (icon, label, path, color) = actions[i];
          return InkWell(
            onTap: () => context.go(path),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 88,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
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
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.error.withAlpha(15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withAlpha(40)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 13))),
      ],
    ),
  );
}
