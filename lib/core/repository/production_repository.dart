import '../api/api_client.dart';

class ProductionRepository {
  final ApiClient _api;

  ProductionRepository(this._api);

  Future<Map<String, dynamic>> listCutOrders({
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    final res = await _api.get('/api/v1/production/cut-orders', queryParams: params);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCutOrder(Map<String, dynamic> data) async {
    final res = await _api.post('/api/v1/production/cut-orders', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listLinePlans({
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    final res = await _api.get('/api/v1/production/line-plans', queryParams: params);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createLinePlan(Map<String, dynamic> data) async {
    final res = await _api.post('/api/v1/production/line-plans', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listWipRecords({
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    final res = await _api.get('/api/v1/production/wip', queryParams: params);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateWipRecord(String id, Map<String, dynamic> data) async {
    final res = await _api.patch('/api/v1/production/wip/$id', data: data);
    return res.data as Map<String, dynamic>;
  }
}
