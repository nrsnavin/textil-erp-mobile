import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';

class BuyerFilter {
  final int     page;
  final int     limit;
  final String? search;

  const BuyerFilter({this.page = 1, this.limit = 20, this.search});

  @override
  bool operator ==(Object other) =>
      other is BuyerFilter && other.page == page && other.search == search;

  @override
  int get hashCode => Object.hash(page, search);
}

final buyersProvider = FutureProvider.family<PaginatedResponse<Buyer>, BuyerFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final params = <String, dynamic>{'page': filter.page, 'limit': filter.limit};
  if (filter.search != null && filter.search!.isNotEmpty) params['search'] = filter.search!;

  final res = await api.get('/api/v1/buyers', queryParams: params);
  return PaginatedResponse.fromJson(
    res.data as Map<String, dynamic>,
    Buyer.fromJson,
  );
});
