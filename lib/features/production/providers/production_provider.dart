import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final cutOrdersProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/api/v1/production/cut-orders');
  return res.data as Map<String, dynamic>;
});

final linePlansProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/api/v1/production/line-plans');
  return res.data as Map<String, dynamic>;
});

final wipRecordsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/api/v1/production/wip');
  return res.data as Map<String, dynamic>;
});
