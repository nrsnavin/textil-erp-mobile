import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks device network connectivity state.
///
/// Uses connectivity_plus to detect WiFi/mobile/none transitions.
/// Exposes a stream and a synchronous snapshot for the sync engine.
enum NetworkStatus { online, offline }

class ConnectivityMonitor {
  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<NetworkStatus>.broadcast();

  NetworkStatus _currentStatus = NetworkStatus.offline;
  StreamSubscription? _subscription;

  NetworkStatus get currentStatus => _currentStatus;
  Stream<NetworkStatus> get statusStream => _controller.stream;
  bool get isOnline => _currentStatus == NetworkStatus.online;

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _currentStatus = _mapResults(results);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final newStatus = _mapResults(results);
      if (newStatus != _currentStatus) {
        _currentStatus = newStatus;
        _controller.add(newStatus);
      }
    });
  }

  NetworkStatus _mapResults(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

// ── Riverpod providers ────────────────────────────────────────────────────

final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  final monitor = ConnectivityMonitor();
  ref.onDispose(() => monitor.dispose());
  return monitor;
});

final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final monitor = ref.watch(connectivityMonitorProvider);
  return monitor.statusStream;
});
