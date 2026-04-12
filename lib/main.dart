import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/sync/connectivity_monitor.dart';
import 'core/sync/mutation_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the offline mutation database (SQLite with WAL mode)
  await MutationDb.instance.initialize();

  // Initialize connectivity monitor before the widget tree builds
  final connectivity = ConnectivityMonitor();
  await connectivity.initialize();

  runApp(
    ProviderScope(
      overrides: [
        connectivityMonitorProvider.overrideWithValue(connectivity),
      ],
      child: const TextileErpApp(),
    ),
  );
}
