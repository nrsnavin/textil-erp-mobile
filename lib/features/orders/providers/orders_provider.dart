import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';

class OrderFilter {
  final int     page;
  final int     limit;
  final String? status;
  final String? search;

  const OrderFilter({this.page = 1, this.limit = 20, this.status, this.search});

  OrderFilter copyWith({int? page, String? status, String? search}) => OrderFilter(
    page:   page   ?? this.page,
    limit:  limit,
    status: status,
    search: search,
  );

  @override
  bool operator ==(Object other) =>
      other is OrderFilter &&
      other.page   == page &&
      other.status == status &&
      other.search == search;

  @override
  int get hashCode => Object.hash(page, status, search);
}

final ordersProvider = FutureProvider.family<PaginatedResponse<Order>, OrderFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final params = <String, dynamic>{'page': filter.page, 'limit': filter.limit};
  if (filter.status != null) params['status'] = filter.status!;
  if (filter.search != null && filter.search!.isNotEmpty) params['search'] = filter.search!;

  final res = await api.get('/api/v1/orders', queryParams: params);
  return PaginatedResponse.fromJson(
    res.data as Map<String, dynamic>,
    Order.fromJson,
  );
});

final orderDetailProvider = FutureProvider.family<Order, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/api/v1/orders/$id');
  return Order.fromJson(res.data as Map<String, dynamic>);
});
