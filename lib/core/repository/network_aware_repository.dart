import 'dart:async';

import 'package:flutter/foundation.dart';

import '../sync/connectivity_monitor.dart';

/// Cache freshness strategy.
enum CacheStrategy {
  /// Always try network first, fall back to cache on failure.
  networkFirst,

  /// Use cache if fresh (< maxAge), otherwise fetch from network.
  cacheFirst,

  /// Always use cache, refresh in background (stale-while-revalidate).
  staleWhileRevalidate,

  /// Network only — never use cache.
  networkOnly,

  /// Cache only — never hit network (for truly offline screens).
  cacheOnly,
}

/// Result of a repository fetch operation.
class DataResult<T> {
  final T data;
  final DataSource source;
  final DateTime? cachedAt;
  final bool isStale;

  const DataResult({
    required this.data,
    required this.source,
    this.cachedAt,
    this.isStale = false,
  });
}

enum DataSource { network, cache }

/// Abstract base class for repositories that transparently handle
/// online/offline data access.
///
/// ## How it works:
///
/// ```
/// User requests data
///       │
///       ▼
/// NetworkAwareRepository.fetch()
///       │
///   ┌───┴───────────────────┐
///   │ Check CacheStrategy   │
///   └───┬───────────────────┘
///       │
///   ┌───┴──────────┬──────────────┬──────────────┐
///   │ networkFirst │ cacheFirst   │ staleWhileRe │
///   │              │              │ validate     │
///   ├──────────────┼──────────────┼──────────────┤
///   │ try network  │ check cache  │ return cache │
///   │ → cache on   │ → network if │ → refresh in │
///   │   failure    │   stale      │   background │
///   └──────────────┴──────────────┴──────────────┘
/// ```
///
/// Subclasses implement [fetchFromNetwork] and [fetchFromCache] / [saveToCache].
abstract class NetworkAwareRepository<T> {
  final ConnectivityMonitor _connectivity;

  NetworkAwareRepository(this._connectivity);

  /// Maximum age before cached data is considered stale.
  Duration get maxCacheAge => const Duration(minutes: 30);

  /// Default strategy for this repository.
  CacheStrategy get defaultStrategy => CacheStrategy.networkFirst;

  /// Fetch data using the specified strategy.
  Future<DataResult<T>> fetch({
    CacheStrategy? strategy,
    Map<String, dynamic>? params,
  }) async {
    final strat = strategy ?? _resolveStrategy();

    switch (strat) {
      case CacheStrategy.networkOnly:
        return _fetchNetworkOnly(params);

      case CacheStrategy.cacheOnly:
        return _fetchCacheOnly(params);

      case CacheStrategy.networkFirst:
        return _fetchNetworkFirst(params);

      case CacheStrategy.cacheFirst:
        return _fetchCacheFirst(params);

      case CacheStrategy.staleWhileRevalidate:
        return _fetchStaleWhileRevalidate(params);
    }
  }

  /// Resolve strategy based on current connectivity.
  CacheStrategy _resolveStrategy() {
    if (!_connectivity.isOnline) {
      return CacheStrategy.cacheOnly;
    }
    return defaultStrategy;
  }

  // ── Strategy implementations ──────────────────────────────────────────

  Future<DataResult<T>> _fetchNetworkOnly(Map<String, dynamic>? params) async {
    final data = await fetchFromNetwork(params);
    await saveToCache(data, params);
    return DataResult(data: data, source: DataSource.network);
  }

  Future<DataResult<T>> _fetchCacheOnly(Map<String, dynamic>? params) async {
    final cached = await fetchFromCache(params);
    if (cached != null) {
      final cachedAt = await getCachedAt(params);
      return DataResult(
        data: cached,
        source: DataSource.cache,
        cachedAt: cachedAt,
        isStale: _isStale(cachedAt),
      );
    }
    throw CacheEmptyException('No cached data available offline');
  }

  Future<DataResult<T>> _fetchNetworkFirst(Map<String, dynamic>? params) async {
    try {
      final data = await fetchFromNetwork(params);
      await saveToCache(data, params);
      return DataResult(data: data, source: DataSource.network);
    } catch (e) {
      debugPrint('[NetworkAwareRepo] Network failed, trying cache: $e');
      final cached = await fetchFromCache(params);
      if (cached != null) {
        final cachedAt = await getCachedAt(params);
        return DataResult(
          data: cached,
          source: DataSource.cache,
          cachedAt: cachedAt,
          isStale: _isStale(cachedAt),
        );
      }
      rethrow;
    }
  }

  Future<DataResult<T>> _fetchCacheFirst(Map<String, dynamic>? params) async {
    final cached = await fetchFromCache(params);
    final cachedAt = await getCachedAt(params);

    if (cached != null && !_isStale(cachedAt)) {
      return DataResult(
        data: cached,
        source: DataSource.cache,
        cachedAt: cachedAt,
      );
    }

    // Cache is stale or empty — fetch from network
    if (_connectivity.isOnline) {
      try {
        final data = await fetchFromNetwork(params);
        await saveToCache(data, params);
        return DataResult(data: data, source: DataSource.network);
      } catch (e) {
        // If we have stale cache, return it
        if (cached != null) {
          return DataResult(
            data: cached,
            source: DataSource.cache,
            cachedAt: cachedAt,
            isStale: true,
          );
        }
        rethrow;
      }
    }

    // Offline + have stale cache
    if (cached != null) {
      return DataResult(
        data: cached,
        source: DataSource.cache,
        cachedAt: cachedAt,
        isStale: true,
      );
    }

    throw CacheEmptyException('No cached data available');
  }

  Future<DataResult<T>> _fetchStaleWhileRevalidate(Map<String, dynamic>? params) async {
    final cached = await fetchFromCache(params);
    final cachedAt = await getCachedAt(params);

    if (cached != null) {
      // Return cache immediately, refresh in background
      if (_connectivity.isOnline && _isStale(cachedAt)) {
        _refreshInBackground(params);
      }
      return DataResult(
        data: cached,
        source: DataSource.cache,
        cachedAt: cachedAt,
        isStale: _isStale(cachedAt),
      );
    }

    // No cache — must fetch from network
    if (_connectivity.isOnline) {
      final data = await fetchFromNetwork(params);
      await saveToCache(data, params);
      return DataResult(data: data, source: DataSource.network);
    }

    throw CacheEmptyException('No cached data available offline');
  }

  bool _isStale(DateTime? cachedAt) {
    if (cachedAt == null) return true;
    return DateTime.now().difference(cachedAt) > maxCacheAge;
  }

  void _refreshInBackground(Map<String, dynamic>? params) {
    // Fire-and-forget background refresh
    Future(() async {
      try {
        final data = await fetchFromNetwork(params);
        await saveToCache(data, params);
      } catch (e) {
        debugPrint('[NetworkAwareRepo] Background refresh failed: $e');
      }
    });
  }

  // ── Abstract methods (implement in subclass) ──────────────────────────

  /// Fetch fresh data from the API.
  Future<T> fetchFromNetwork(Map<String, dynamic>? params);

  /// Load cached data from SQLite.
  Future<T?> fetchFromCache(Map<String, dynamic>? params);

  /// Save network data to SQLite cache.
  Future<void> saveToCache(T data, Map<String, dynamic>? params);

  /// Get the timestamp of the cached data.
  Future<DateTime?> getCachedAt(Map<String, dynamic>? params);
}

/// Exception thrown when cache is empty and network is unavailable.
class CacheEmptyException implements Exception {
  final String message;
  CacheEmptyException(this.message);

  @override
  String toString() => 'CacheEmptyException: $message';
}
