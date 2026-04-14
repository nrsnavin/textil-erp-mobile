import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth  = ref.watch(authStateProvider).value;
    final route = GoRouterState.of(context).matchedLocation;

    void nav(String path) {
      Navigator.of(context).pop();
      context.go(path);
    }

    return Drawer(
      backgroundColor: AppColors.scaffold,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (auth?.name ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  auth?.name ?? '',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  auth?.role?.replaceAll('_', ' ') ?? '',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),

          // Nav items
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _tile(Icons.grid_view_rounded,       'Dashboard',    '/dashboard',    route, nav),
                _tile(Icons.assignment_outlined,      'Orders',       '/orders',       route, nav),
                _tile(Icons.inventory_2_outlined,     'Inventory',    '/inventory',    route, nav),
                _tile(Icons.people_outline_rounded,   'Buyers',       '/buyers',       route, nav),
                _tile(Icons.local_shipping_outlined,  'Suppliers',    '/suppliers',    route, nav),
                _tile(Icons.receipt_long_outlined,    'GRN',          '/grn',          route, nav),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                _tile(Icons.account_balance_outlined, 'Finance',      '/finance',      route, nav),
                _tile(Icons.precision_manufacturing_outlined, 'Production', '/production', route, nav),
              ],
            ),
          ),

          // Sign out
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: const Icon(Icons.logout_rounded, color: AppColors.textTertiary, size: 20),
              title: const Text(
                'Sign out',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(authStateProvider.notifier).logout();
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, String path,
      String current, void Function(String) nav) {
    final active = current.startsWith(path);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        leading: Icon(
          icon,
          size: 20,
          color: active ? AppColors.primary : AppColors.textTertiary,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: active ? AppColors.primary.withAlpha(18) : null,
        onTap: () => nav(path),
      ),
    );
  }
}
