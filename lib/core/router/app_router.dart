import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/mfa_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/orders/screens/orders_list_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/inventory/screens/movement_history_screen.dart';
import '../../features/buyers/screens/buyers_list_screen.dart';
import '../../features/suppliers/screens/suppliers_list_screen.dart';
import '../../features/grn/screens/grn_list_screen.dart';
import '../../features/grn/screens/grn_detail_screen.dart';
import '../../features/finance/screens/finance_dashboard_screen.dart';
import '../../features/finance/screens/invoices_list_screen.dart';
import '../../features/finance/screens/create_invoice_screen.dart';
import '../../features/finance/screens/record_payment_screen.dart';
import '../../features/production/screens/production_dashboard_screen.dart';
import '../../features/production/screens/cut_orders_screen.dart';
import '../../features/production/screens/line_plans_screen.dart';
import '../../features/production/screens/wip_records_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = authState.value?.isLoggedIn ?? false;
      final onAuth  = state.matchedLocation.startsWith('/login') ||
                      state.matchedLocation.startsWith('/mfa');

      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn  &&  onAuth) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/mfa',
        builder: (_, state) => MfaScreen(mfaToken: state.extra as String? ?? ''),
      ),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/orders',    builder: (_, __) => const OrdersListScreen()),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
      GoRoute(
        path: '/inventory/movements',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return MovementHistoryScreen(
            itemId:   extra?['itemId']   as String? ?? '',
            itemName: extra?['itemName'] as String? ?? '',
            location: extra?['location'] as String? ?? 'MAIN',
          );
        },
      ),
      GoRoute(path: '/buyers',    builder: (_, __) => const BuyersListScreen()),
      GoRoute(path: '/suppliers', builder: (_, __) => const SuppliersListScreen()),
      GoRoute(path: '/grn',       builder: (_, __) => const GrnListScreen()),
      GoRoute(
        path: '/grn/:id',
        builder: (_, state) => GrnDetailScreen(grnId: state.pathParameters['id']!),
      ),
      // ── Finance ──
      GoRoute(path: '/finance',          builder: (_, __) => const FinanceDashboardScreen()),
      GoRoute(path: '/finance/invoices', builder: (_, __) => const InvoicesListScreen()),
      GoRoute(path: '/finance/invoices/create', builder: (_, __) => const CreateInvoiceScreen()),
      GoRoute(path: '/finance/payments', builder: (_, __) => const RecordPaymentScreen()),
      // ── Production ──
      GoRoute(path: '/production',            builder: (_, __) => const ProductionDashboardScreen()),
      GoRoute(path: '/production/cut-orders', builder: (_, __) => const CutOrdersScreen()),
      GoRoute(path: '/production/line-plans', builder: (_, __) => const LinePlansScreen()),
      GoRoute(path: '/production/wip',        builder: (_, __) => const WipRecordsScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
