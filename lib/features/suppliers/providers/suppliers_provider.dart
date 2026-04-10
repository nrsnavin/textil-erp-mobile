import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';

class SupplierFilter {
  final int     page;
  final int     limit;
  final String? search;

  const SupplierFilter({this.page = 1, this.limit = 20, this.search});

  @override
  bool operator ==(Object other) =>
      other is SupplierFilter && other.page == page && other.search == search;

  @override
  int get hashCode => Object.hash(page, search);
}

final suppliersProvider = FutureProvider.family<PaginatedResponse<Supplier>, SupplierFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final params = <String, dynamic>{'page': filter.page, 'limit': filter.limit};
  if (filter.search != null && filter.search!.isNotEmpty) params['search'] = filter.search!;

  final res = await api.get('/api/v1/suppliers', queryParams: params);
  return PaginatedResponse.fromJson(
    res.data as Map<String, dynamic>,
    Supplier.fromJson,
  );
});
