import '../api/api_client.dart';

class FinanceRepository {
  final ApiClient _api;

  FinanceRepository(this._api);

  Future<Map<String, dynamic>> listInvoices({
    int page = 1,
    int limit = 20,
    String? status,
    String? type,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null) params['status'] = status;
    if (type != null) params['type'] = type;
    final res = await _api.get('/api/v1/finance/invoices', queryParams: params);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getInvoice(String id) async {
    final res = await _api.get('/api/v1/finance/invoices/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> data) async {
    final res = await _api.post('/api/v1/finance/invoices', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listPayments({
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    final res = await _api.get('/api/v1/finance/payments', queryParams: params);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recordPayment(Map<String, dynamic> data) async {
    final res = await _api.post('/api/v1/finance/payments', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getArSummary() async {
    final res = await _api.get('/api/v1/finance/ar-summary');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getApSummary() async {
    final res = await _api.get('/api/v1/finance/ap-summary');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAgingReport() async {
    final res = await _api.get('/api/v1/finance/aging');
    return res.data as Map<String, dynamic>;
  }
}
