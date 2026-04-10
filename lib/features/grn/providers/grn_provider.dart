import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';

class GrnFilter {
  final int     page;
  final int     limit;
  final String? status;
  final String? search;

  const GrnFilter({this.page = 1, this.limit = 20, this.status, this.search});

  GrnFilter copyWith({int? page, String? status, String? search}) => GrnFilter(
    page:   page   ?? this.page,
    limit:  limit,
    status: status,
    search: search,
  );

  @override
  bool operator ==(Object other) =>
      other is GrnFilter &&
      other.page   == page &&
      other.status == status &&
      other.search == search;

  @override
  int get hashCode => Object.hash(page, status, search);
}

final grnsProvider = FutureProvider.family<PaginatedResponse<Grn>, GrnFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final params = <String, dynamic>{'page': filter.page, 'limit': filter.limit};
  if (filter.status != null) params['status'] = filter.status!;
  if (filter.search != null && filter.search!.isNotEmpty) params['search'] = filter.search!;

  final res = await api.get('/api/v1/grn', queryParams: params);
  return PaginatedResponse.fromJson(
    res.data as Map<String, dynamic>,
    Grn.fromJson,
  );
});

final grnDetailProvider = FutureProvider.family<Grn, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/api/v1/grn/$id');
  return Grn.fromJson(res.data as Map<String, dynamic>);
});
