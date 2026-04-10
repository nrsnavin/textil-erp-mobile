import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class DashboardStats {
  final int totalOrders;
  final int activeOrders;
  final int stockItems;
  final int pendingGrns;
  final int totalBuyers;
  final int totalSuppliers;

  const DashboardStats({
    this.totalOrders    = 0,
    this.activeOrders   = 0,
    this.stockItems     = 0,
    this.pendingGrns    = 0,
    this.totalBuyers    = 0,
    this.totalSuppliers = 0,
  });
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final api = ref.watch(apiClientProvider);

  // Fetch all in parallel — gracefully degrade if any endpoint fails
  final results = await Future.wait([
    api.get('/api/v1/orders',    queryParams: {'limit': '1'}).then((r) => r.data).catchError((_) => {'meta': {'total': 0}}),
    api.get('/api/v1/orders',    queryParams: {'limit': '1', 'status': 'IN_PRODUCTION'}).then((r) => r.data).catchError((_) => {'meta': {'total': 0}}),
    api.get('/api/v1/inventory/stock').then((r) => r.data).catchError((_) => <dynamic>[]),
    api.get('/api/v1/grn',       queryParams: {'limit': '1', 'status': 'DRAFT'}).then((r) => r.data).catchError((_) => {'meta': {'total': 0}}),
    api.get('/api/v1/buyers',    queryParams: {'limit': '1'}).then((r) => r.data).catchError((_) => {'meta': {'total': 0}}),
    api.get('/api/v1/suppliers', queryParams: {'limit': '1'}).then((r) => r.data).catchError((_) => {'meta': {'total': 0}}),
  ]);

  int meta(dynamic d) => (d is Map ? (d['meta']?['total'] ?? 0) : 0) as int;
  int listLen(dynamic d) => d is List ? d.length : 0;

  return DashboardStats(
    totalOrders:    meta(results[0]),
    activeOrders:   meta(results[1]),
    stockItems:     listLen(results[2]),
    pendingGrns:    meta(results[3]),
    totalBuyers:    meta(results[4]),
    totalSuppliers: meta(results[5]),
  );
});
