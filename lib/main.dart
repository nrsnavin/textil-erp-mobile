import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/database/app_database.dart';
import 'core/sync/connectivity_monitor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the unified SQLite database (sync queue + cache tables)
  await AppDatabase.instance.initialize();

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
