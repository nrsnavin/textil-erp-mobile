import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class InvoiceFilter {
  final int     page;
  final int     limit;
  final String? status;
  final String? type;

  const InvoiceFilter({this.page = 1, this.limit = 20, this.status, this.type});

  InvoiceFilter copyWith({int? page, String? status, String? type}) => InvoiceFilter(
    page:   page   ?? this.page,
    limit:  limit,
    status: status,
    type:   type   ?? this.type,
  );

  @override
  bool operator ==(Object other) =>
      other is InvoiceFilter &&
      other.page   == page &&
      other.status == status &&
      other.type   == type;

  @override
  int get hashCode => Object.hash(page, status, type);
}

final invoicesProvider = FutureProvider.family<Map<String, dynamic>, InvoiceFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final params = <String, dynamic>{'page': filter.page, 'limit': filter.limit};
  if (filter.status != null) params['status'] = filter.status!;
  if (filter.type != null) params['type'] = filter.type!;

  final res = await api.get('/api/v1/finance/invoices', queryParams: params);
  return res.data as Map<String, dynamic>;
});

final invoiceDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/api/v1/finance/invoices/$id');
  return res.data as Map<String, dynamic>;
});

final arSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/api/v1/finance/ar-summary');
  return res.data as Map<String, dynamic>;
});

final apSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/api/v1/finance/ap-summary');
  return res.data as Map<String, dynamic>;
});

final agingProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/api/v1/finance/aging');
  return res.data as Map<String, dynamic>;
});
