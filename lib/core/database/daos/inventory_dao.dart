import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../models/models.dart';

/// Cached stock balance row.
class CachedStockBalance {
  final String id;
  final String itemId;
  final String? itemJson;
  final String location;
  final double onHand;
  final double reserved;
  final double available;
  final String dataJson;
  final DateTime cachedAt;
  final String? etag;

  CachedStockBalance({
    required this.id,
    required this.itemId,
    this.itemJson,
    required this.location,
    required this.onHand,
    required this.reserved,
    required this.available,
    required this.dataJson,
    required this.cachedAt,
    this.etag,
  });

  StockBalance toStockBalance() =>
      StockBalance.fromJson(jsonDecode(dataJson) as Map<String, dynamic>);

  Map<String, dynamic> toMap() => {
    'id': id,
    'item_id': itemId,
    'item_json': itemJson,
    'location': location,
    'on_hand': onHand,
    'reserved': reserved,
    'available': available,
    'data_json': dataJson,
    'cached_at': cachedAt.toIso8601String(),
    'etag': etag,
  };

  factory CachedStockBalance.fromMap(Map<String, dynamic> m) => CachedStockBalance(
    id: m['id'] as String,
    itemId: m['item_id'] as String,
    itemJson: m['item_json'] as String?,
    location: m['location'] as String,
    onHand: (m['on_hand'] as num).toDouble(),
    reserved: (m['reserved'] as num).toDouble(),
    available: (m['available'] as num).toDouble(),
    dataJson: m['data_json'] as String,
    cachedAt: DateTime.parse(m['cached_at'] as String),
    etag: m['etag'] as String?,
  );

  factory CachedStockBalance.fromStockBalance(StockBalance sb, {String? etag}) {
    final json = {
      'id': sb.id,
      'itemId': sb.itemId,
      'item': sb.item != null ? {
        'id': sb.item!.id,
        'code': sb.item!.code,
        'name': sb.item!.name,
        'unit': sb.item!.unit,
        'category': sb.item!.category,
      } : null,
      'location': sb.location,
      'onHand': sb.onHand,
      'reserved': sb.reserved,
      'available': sb.available,
    };
    return CachedStockBalance(
      id: sb.id,
      itemId: sb.itemId,
      itemJson: sb.item != null ? jsonEncode({
        'id': sb.item!.id,
        'code': sb.item!.code,
        'name': sb.item!.name,
        'unit': sb.item!.unit,
      }) : null,
      location: sb.location,
      onHand: sb.onHand,
      reserved: sb.reserved,
      available: sb.available,
      dataJson: jsonEncode(json),
      cachedAt: DateTime.now(),
      etag: etag,
    );
  }
}

/// Typed DAO for cached_inventory table.
class InventoryDao {
  static const _table = 'cached_inventory';
  final Database _db;

  InventoryDao(this._db);

  /// Upsert a single stock balance into cache.
  Future<void> upsert(CachedStockBalance balance) async {
    await _db.insert(
      _table,
      balance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Upsert a batch of stock balances.
  Future<void> upsertBatch(List<CachedStockBalance> balances) async {
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final b in balances) {
        batch.insert(
          _table,
          b.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Get all cached stock balances, optionally filtered by search.
  Future<List<StockBalance>> getAll({String? search}) async {
    List<Map<String, dynamic>> rows;

    if (search != null && search.isNotEmpty) {
      // Search item name/code from the stored JSON
      rows = await _db.rawQuery(
        'SELECT * FROM $_table WHERE item_json LIKE ? ORDER BY cached_at DESC',
        ['%$search%'],
      );
    } else {
      rows = await _db.query(_table, orderBy: 'cached_at DESC');
    }

    return rows.map((r) => CachedStockBalance.fromMap(r).toStockBalance()).toList();
  }

  /// Get stock balance for a specific item + location.
  Future<StockBalance?> getByItemLocation(String itemId, String location) async {
    final rows = await _db.query(
      _table,
      where: 'item_id = ? AND location = ?',
      whereArgs: [itemId, location],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CachedStockBalance.fromMap(rows.first).toStockBalance();
  }

  /// Count cached stock balances.
  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as cnt FROM $_table');
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

  /// Clear all cached inventory.
  Future<void> clearAll() async {
    await _db.delete(_table);
  }
}
