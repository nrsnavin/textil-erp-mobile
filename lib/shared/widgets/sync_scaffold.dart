import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync_status_bar.dart';

/// Scaffold wrapper that includes the SyncStatusBar below the AppBar.
/// Use this instead of Scaffold on screens that should show sync status.
class SyncScaffold extends ConsumerWidget {
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget body;
  final Widget? floatingActionButton;

  const SyncScaffold({
    super.key,
    this.appBar,
    this.drawer,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          const SyncStatusBar(),
          Expanded(child: body),
        ],
      ),
    );
  }
}
