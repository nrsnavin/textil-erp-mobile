import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';

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
      child: Container(
        color: const Color(0xFF1A2F56),
        child: Column(
          children: [
            // Header
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1F3864)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFF2E75B6),
                    child: Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    auth?.name ?? '',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    auth?.role ?? '',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Nav items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _tile(context, Icons.dashboard_outlined,    'Dashboard',  '/dashboard',  route, nav),
                  _tile(context, Icons.assignment_outlined,   'Orders',     '/orders',     route, nav),
                  _tile(context, Icons.inventory_2_outlined,  'Inventory',  '/inventory',  route, nav),
                  _tile(context, Icons.people_outline,        'Buyers',     '/buyers',     route, nav),
                  _tile(context, Icons.local_shipping_outlined,'Suppliers', '/suppliers',  route, nav),
                  _tile(context, Icons.receipt_long_outlined, 'GRN',        '/grn',        route, nav),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.white70),
                    title: const Text('Sign Out', style: TextStyle(color: Colors.white70)),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await ref.read(authStateProvider.notifier).logout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext ctx, IconData icon, String label, String path,
      String current, void Function(String) nav) {
    final active = current.startsWith(path);
    return ListTile(
      leading: Icon(icon, color: active ? Colors.white : Colors.white60),
      title: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.white70,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: active ? Colors.white12 : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () => nav(path),
    );
  }
}
