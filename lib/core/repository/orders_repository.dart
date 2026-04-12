import '../api/api_client.dart';
import '../database/daos/orders_dao.dart';
import '../models/models.dart';
import '../sync/connectivity_monitor.dart';
import 'network_aware_repository.dart';

/// Network-aware repository for orders.
///
/// Uses [CacheStrategy.networkFirst] by default:
/// - Online: fetch from API, cache locally
/// - Offline: serve from SQLite cache
/// - Network error: fall back to cache transparently
class OrdersRepository extends NetworkAwareRepository<List<Order>> {
  final ApiClient _api;
  final OrdersDao _dao;

  OrdersRepository({
    required ApiClient api,
    required OrdersDao dao,
    required ConnectivityMonitor connectivity,
  })  : _api = api,
        _dao = dao,
        super(connectivity);

  @override
  Duration get maxCacheAge => const Duration(minutes: 15);

  @override
  CacheStrategy get defaultStrategy => CacheStrategy.networkFirst;

  @override
  Future<List<Order>> fetchFromNetwork(Map<String, dynamic>? params) async {
    final queryParams = <String, dynamic>{
      'page': params?['page'] ?? 1,
      'limit': params?['limit'] ?? 20,
    };
    if (params?['status'] != null) queryParams['status'] = params!['status'];
    if (params?['search'] != null && (params!['search'] as String).isNotEmpty) {
      queryParams['search'] = params['search'];
    }

    final res = await _api.get('/api/v1/orders', queryParams: queryParams);
    final paginated = PaginatedResponse.fromJson(
      res.data as Map<String, dynamic>,
      Order.fromJson,
    );

    return paginated.data;
  }

  @override
  Future<List<Order>?> fetchFromCache(Map<String, dynamic>? params) async {
    final orders = await _dao.query(
      status: params?['status'] as String?,
      search: params?['search'] as String?,
      limit: params?['limit'] as int? ?? 20,
      offset: ((params?['page'] as int? ?? 1) - 1) * (params?['limit'] as int? ?? 20),
    );
    return orders.isEmpty ? null : orders;
  }

  @override
  Future<void> saveToCache(List<Order> data, Map<String, dynamic>? params) async {
    final cached = data.map((o) => CachedOrder.fromOrder(o)).toList();
    await _dao.upsertBatch(cached);
  }

  @override
  Future<DateTime?> getCachedAt(Map<String, dynamic>? params) {
    return _dao.lastCachedAt();
  }

  /// Get a single order by ID (network-first with cache fallback).
  Future<DataResult<Order>> getById(String id) async {
    if (_connectivity.isOnline) {
      try {
        final res = await _api.get('/api/v1/orders/$id');
        final order = Order.fromJson(res.data as Map<String, dynamic>);
        await _dao.upsert(CachedOrder.fromOrder(order));
        return DataResult(data: order, source: DataSource.network);
      } catch (_) {
        // Fall through to cache
      }
    }

    final cached = await _dao.getById(id);
    if (cached != null) {
      return DataResult(data: cached, source: DataSource.cache, isStale: true);
    }
    throw CacheEmptyException('Order $id not in cache');
  }

  /// Get cached order count.
  Future<int> cachedCount({String? status}) => _dao.count(status: status);
}
