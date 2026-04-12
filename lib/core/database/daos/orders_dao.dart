import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../models/models.dart';

/// Cached order row. Stores the full JSON alongside indexed columns
/// for efficient filtering without deserializing.
class CachedOrder {
  final String id;
  final String poNumber;
  final String buyerId;
  final String? buyerJson;
  final String status;
  final String deliveryDate;
  final String? season;
  final String? remarks;
  final int totalQty;
  final int totalStyles;
  final String dataJson;  // Full Order JSON
  final DateTime cachedAt;
  final String? etag;

  CachedOrder({
    required this.id,
    required this.poNumber,
    required this.buyerId,
    this.buyerJson,
    required this.status,
    required this.deliveryDate,
    this.season,
    this.remarks,
    required this.totalQty,
    required this.totalStyles,
    required this.dataJson,
    required this.cachedAt,
    this.etag,
  });

  /// Deserialize the full Order from cached JSON.
  Order toOrder() => Order.fromJson(jsonDecode(dataJson) as Map<String, dynamic>);

  Map<String, dynamic> toMap() => {
    'id': id,
    'po_number': poNumber,
    'buyer_id': buyerId,
    'buyer_json': buyerJson,
    'status': status,
    'delivery_date': deliveryDate,
    'season': season,
    'remarks': remarks,
    'total_qty': totalQty,
    'total_styles': totalStyles,
    'data_json': dataJson,
    'cached_at': cachedAt.toIso8601String(),
    'etag': etag,
  };

  factory CachedOrder.fromMap(Map<String, dynamic> m) => CachedOrder(
    id: m['id'] as String,
    poNumber: m['po_number'] as String,
    buyerId: m['buyer_id'] as String,
    buyerJson: m['buyer_json'] as String?,
    status: m['status'] as String,
    deliveryDate: m['delivery_date'] as String,
    season: m['season'] as String?,
    remarks: m['remarks'] as String?,
    totalQty: m['total_qty'] as int,
    totalStyles: m['total_styles'] as int,
    dataJson: m['data_json'] as String,
    cachedAt: DateTime.parse(m['cached_at'] as String),
    etag: m['etag'] as String?,
  );

  /// Create a CachedOrder from an API Order response.
  factory CachedOrder.fromOrder(Order order, {String? etag}) => CachedOrder(
    id: order.id,
    poNumber: order.poNumber,
    buyerId: order.buyerId,
    buyerJson: order.buyer != null ? jsonEncode({
      'id': order.buyer!.id,
      'name': order.buyer!.name,
      'country': order.buyer!.country,
      'currency': order.buyer!.currency,
    }) : null,
    status: order.status,
    deliveryDate: order.deliveryDate,
    season: order.season,
    remarks: order.remarks,
    totalQty: order.totalQty,
    totalStyles: order.totalStyles,
    dataJson: jsonEncode({
      'id': order.id,
      'poNumber': order.poNumber,
      'buyerId': order.buyerId,
      'buyer': order.buyer != null ? {
        'id': order.buyer!.id,
        'name': order.buyer!.name,
        'country': order.buyer!.country,
        'currency': order.buyer!.currency,
        'isActive': true,
      } : null,
      'status': order.status,
      'deliveryDate': order.deliveryDate,
      'season': order.season,
      'remarks': order.remarks,
      'totalQty': order.totalQty,
      'totalStyles': order.totalStyles,
      'createdAt': order.createdAt,
    }),
    cachedAt: DateTime.now(),
    etag: etag,
  );
}

/// Typed DAO for cached_orders table.
class OrdersDao {
  static const _table = 'cached_orders';
  final Database _db;

  OrdersDao(this._db);

  /// Upsert a single order into cache.
  Future<void> upsert(CachedOrder order) async {
    await _db.insert(
      _table,
      order.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Upsert a batch of orders (e.g. from a list API response).
  Future<void> upsertBatch(List<CachedOrder> orders) async {
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final order in orders) {
        batch.insert(
          _table,
          order.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Query cached orders with optional filters.
  Future<List<Order>> query({
    String? status,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    final where = <String>[];
    final args = <dynamic>[];

    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (search != null && search.isNotEmpty) {
      where.add('po_number LIKE ?');
      args.add('%$search%');
    }

    final rows = await _db.query(
      _table,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'cached_at DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map((r) => CachedOrder.fromMap(r).toOrder()).toList();
  }

  /// Get a single cached order by ID.
  Future<Order?> getById(String id) async {
    final rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CachedOrder.fromMap(rows.first).toOrder();
  }

  /// Count cached orders (optionally by status).
  Future<int> count({String? status}) async {
    final where = status != null ? 'WHERE status = ?' : '';
    final args = status != null ? [status] : <dynamic>[];
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_table $where',
      args,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get the last cache timestamp.
  Future<DateTime?> lastCachedAt() async {
    final result = await _db.rawQuery(
      'SELECT MAX(cached_at) as latest FROM $_table',
    );
    final val = result.first['latest'] as String?;
    return val != null ? DateTime.tryParse(val) : null;
  }

  /// Delete a single cached order.
  Future<void> delete(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Clear all cached orders.
  Future<void> clearAll() async {
    await _db.delete(_table);
  }
}
