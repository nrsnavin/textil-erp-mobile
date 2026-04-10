import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';

final stockBalancesProvider = FutureProvider<List<StockBalance>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/api/v1/inventory/stock');
  return (res.data as List<dynamic>)
      .map((e) => StockBalance.fromJson(e as Map<String, dynamic>))
      .toList();
});

final movementHistoryProvider =
    FutureProvider.family<List<StockLedgerEntry>, MovementFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final params = <String, dynamic>{
    'limit': filter.limit.toString(),
    'page':  filter.page.toString(),
  };
  if (filter.itemId   != null) params['itemId']   = filter.itemId!;
  if (filter.location != null) params['location']  = filter.location!;
  if (filter.entryType != null) params['entryType'] = filter.entryType!;

  final res = await api.get('/api/v1/inventory/stock/movements', queryParams: params);
  final data = res.data as Map<String, dynamic>;
  return (data['data'] as List<dynamic>)
      .map((e) => StockLedgerEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});

class MovementFilter {
  final String? itemId;
  final String? location;
  final String? entryType;
  final int     page;
  final int     limit;

  const MovementFilter({
    this.itemId,
    this.location,
    this.entryType,
    this.page  = 1,
    this.limit = 20,
  });

  MovementFilter copyWith({String? itemId, String? location, String? entryType, int? page}) =>
      MovementFilter(
        itemId:    itemId    ?? this.itemId,
        location:  location  ?? this.location,
        entryType: entryType ?? this.entryType,
        page:      page      ?? this.page,
        limit:     limit,
      );

  @override
  bool operator ==(Object other) =>
      other is MovementFilter &&
      other.itemId    == itemId &&
      other.location  == location &&
      other.entryType == entryType &&
      other.page      == page;

  @override
  int get hashCode => Object.hash(itemId, location, entryType, page);
}

// ── Mutation helpers (returns Future, caller handles error/success) ───────────

Future<void> adjustStock(
  ApiClient api, {
  required String itemId,
  required String location,
  required double qty,
  required String reason,
}) async {
  await api.post('/api/v1/inventory/stock/adjust', data: {
    'itemId': itemId, 'location': location, 'qty': qty, 'reason': reason,
  });
}

Future<void> issueToProduction(
  ApiClient api, {
  required String itemId,
  required String location,
  required double qty,
  String? remarks,
}) async {
  await api.post('/api/v1/inventory/stock/issue', data: {
    'itemId': itemId, 'location': location, 'qty': qty,
    if (remarks != null) 'remarks': remarks,
  });
}

Future<void> returnFromProduction(
  ApiClient api, {
  required String itemId,
  required String location,
  required double qty,
  String? remarks,
}) async {
  await api.post('/api/v1/inventory/stock/return', data: {
    'itemId': itemId, 'location': location, 'qty': qty,
    if (remarks != null) 'remarks': remarks,
  });
}

Future<void> transferStock(
  ApiClient api, {
  required String itemId,
  required String fromLocation,
  required String toLocation,
  required double qty,
  String? remarks,
}) async {
  await api.post('/api/v1/inventory/stock/transfer', data: {
    'itemId': itemId, 'fromLocation': fromLocation,
    'toLocation': toLocation, 'qty': qty,
    if (remarks != null) 'remarks': remarks,
  });
}

Future<void> setOpeningStock(
  ApiClient api, {
  required String itemId,
  required String location,
  required double qty,
  double? rate,
  String? remarks,
}) async {
  await api.post('/api/v1/inventory/stock/opening', data: {
    'itemId': itemId, 'location': location, 'qty': qty,
    if (rate != null) 'rate': rate,
    if (remarks != null) 'remarks': remarks,
  });
}
