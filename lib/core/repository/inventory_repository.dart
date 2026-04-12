import '../api/api_client.dart';
import '../database/daos/inventory_dao.dart';
import '../models/models.dart';
import '../sync/connectivity_monitor.dart';
import 'network_aware_repository.dart';

/// Network-aware repository for stock balances.
///
/// Uses [CacheStrategy.cacheFirst] because inventory data changes less
/// frequently than orders and is critical for offline stock movements.
class InventoryRepository extends NetworkAwareRepository<List<StockBalance>> {
  final ApiClient _api;
  final InventoryDao _dao;

  InventoryRepository({
    required ApiClient api,
    required InventoryDao dao,
    required ConnectivityMonitor connectivity,
  })  : _api = api,
        _dao = dao,
        super(connectivity);

  @override
  Duration get maxCacheAge => const Duration(minutes: 30);

  @override
  CacheStrategy get defaultStrategy => CacheStrategy.cacheFirst;

  @override
  Future<List<StockBalance>> fetchFromNetwork(Map<String, dynamic>? params) async {
    final res = await _api.get('/api/v1/inventory/stock');
    return (res.data as List<dynamic>)
        .map((e) => StockBalance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<StockBalance>?> fetchFromCache(Map<String, dynamic>? params) async {
    final search = params?['search'] as String?;
    final balances = await _dao.getAll(search: search);
    return balances.isEmpty ? null : balances;
  }

  @override
  Future<void> saveToCache(List<StockBalance> data, Map<String, dynamic>? params) async {
    final cached = data.map((sb) => CachedStockBalance.fromStockBalance(sb)).toList();
    await _dao.upsertBatch(cached);
  }

  @override
  Future<DateTime?> getCachedAt(Map<String, dynamic>? params) {
    return _dao.lastCachedAt();
  }

  /// Get a specific stock balance from cache.
  Future<StockBalance?> getByItemLocation(String itemId, String location) {
    return _dao.getByItemLocation(itemId, location);
  }

  /// Get cached item count.
  Future<int> cachedCount() => _dao.count();
}
