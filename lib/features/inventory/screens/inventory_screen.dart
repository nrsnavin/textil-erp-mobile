import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/inventory_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_drawer.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockBalancesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart_rounded, size: 20),
            tooltip: 'Stock Movement',
            onPressed: () => _showMovementMenu(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => ref.invalidate(stockBalancesProvider),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search by item name or code...',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: stockAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => _ErrorView(message: apiError(e), onRetry: () => ref.invalidate(stockBalancesProvider)),
              data:    (list) {
                final filtered = _search.isEmpty
                    ? list
                    : list.where((s) =>
                        (s.item?.name.toLowerCase().contains(_search) ?? false) ||
                        (s.item?.code.toLowerCase().contains(_search) ?? false)).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No stock records found', style: TextStyle(color: AppColors.textTertiary)));
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async => ref.invalidate(stockBalancesProvider),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _StockTile(
                      balance: filtered[i],
                      onHistoryTap: () => context.go('/inventory/movements', extra: {
                        'itemId':   filtered[i].itemId,
                        'itemName': filtered[i].item?.name ?? filtered[i].itemId,
                        'location': filtered[i].location,
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showMovementMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MovementMenu(onSelected: (type) {
        Navigator.pop(context);
        _showMovementDialog(context, type);
      }),
    );
  }

  void _showMovementDialog(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (_) => _StockMovementDialog(type: type, onDone: () {
        ref.invalidate(stockBalancesProvider);
      }),
    );
  }
}

// ── Stock tile ────────────────────────────────────────────────────────────────────

class _StockTile extends StatelessWidget {
  final StockBalance balance;
  final VoidCallback onHistoryTap;
  const _StockTile({required this.balance, required this.onHistoryTap});

  @override
  Widget build(BuildContext context) {
    final avail = balance.available;
    final availColor = avail > 0 ? AppColors.success : AppColors.error;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF4ADE80), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(balance.item?.name ?? balance.itemId,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
                const SizedBox(height: 4),
                Row(children: [
                  _chip('Code', balance.item?.code ?? '-'),
                  const SizedBox(width: 6),
                  _chip('Loc', balance.location),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _stat('On Hand', balance.onHand, AppColors.textPrimary),
                  const SizedBox(width: 14),
                  _stat('Reserved', balance.reserved, AppColors.warning),
                  const SizedBox(width: 14),
                  _stat('Available', avail, availColor),
                ]),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
              tooltip: 'Movement history',
              onPressed: onHistoryTap,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.primary.withAlpha(12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text('$label: $value',
        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
  );

  Widget _stat(String label, double value, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
        Text(
          value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
        ),
      ]);
}

// ── Movement menu ─────────────────────────────────────────────────────────────────

class _MovementMenu extends StatelessWidget {
  final void Function(String) onSelected;
  const _MovementMenu({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.add_box_outlined,    'Set Opening Stock',       'opening',  const Color(0xFF60A5FA)),
      (Icons.tune_rounded,        'Adjust Stock',            'adjust',   AppColors.warning),
      (Icons.outbox_outlined,     'Issue to Production',     'issue',    AppColors.error),
      (Icons.move_to_inbox,       'Return from Production',  'return',   const Color(0xFF2DD4BF)),
      (Icons.swap_horiz_rounded,  'Transfer Between Locations','transfer',const Color(0xFFA78BFA)),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Stock Movement', style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
              ),
            ),
            const SizedBox(height: 4),
            ...items.map((item) {
              final (icon, label, type, color) = item;
              return ListTile(
                dense: true,
                leading: Icon(icon, color: color, size: 22),
                title: Text(label, style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary)),
                onTap: () => onSelected(type),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Movement dialog ───────────────────────────────────────────────────────────────

class _StockMovementDialog extends ConsumerStatefulWidget {
  final String    type;
  final VoidCallback onDone;
  const _StockMovementDialog({required this.type, required this.onDone});

  @override
  ConsumerState<_StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends ConsumerState<_StockMovementDialog> {
  final _form         = GlobalKey<FormState>();
  final _itemIdCtl    = TextEditingController();
  final _locationCtl  = TextEditingController(text: 'MAIN');
  final _fromLocCtl   = TextEditingController();
  final _toLocCtl     = TextEditingController();
  final _qtyCtl       = TextEditingController();
  final _reasonCtl    = TextEditingController();
  bool _loading       = false;

  String get _title => switch (widget.type) {
    'opening'  => 'Set Opening Stock',
    'adjust'   => 'Adjust Stock',
    'issue'    => 'Issue to Production',
    'return'   => 'Return from Production',
    'transfer' => 'Transfer Stock',
    _          => 'Stock Movement',
  };

  @override
  void dispose() {
    _itemIdCtl.dispose(); _locationCtl.dispose(); _fromLocCtl.dispose();
    _toLocCtl.dispose();  _qtyCtl.dispose();      _reasonCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    final api = ref.read(apiClientProvider);
    final itemId   = _itemIdCtl.text.trim();
    final location = _locationCtl.text.trim().isEmpty ? 'MAIN' : _locationCtl.text.trim();
    final qty      = double.tryParse(_qtyCtl.text) ?? 0;

    try {
      switch (widget.type) {
        case 'opening':
          await setOpeningStock(api, itemId: itemId, location: location, qty: qty, remarks: _reasonCtl.text.trim().isEmpty ? null : _reasonCtl.text.trim());
        case 'adjust':
          await adjustStock(api, itemId: itemId, location: location, qty: qty, reason: _reasonCtl.text.trim());
        case 'issue':
          await issueToProduction(api, itemId: itemId, location: location, qty: qty, remarks: _reasonCtl.text.trim().isEmpty ? null : _reasonCtl.text.trim());
        case 'return':
          await returnFromProduction(api, itemId: itemId, location: location, qty: qty, remarks: _reasonCtl.text.trim().isEmpty ? null : _reasonCtl.text.trim());
        case 'transfer':
          await transferStock(api,
            itemId: itemId,
            fromLocation: _fromLocCtl.text.trim(),
            toLocation:   _toLocCtl.text.trim(),
            qty: qty,
            remarks: _reasonCtl.text.trim().isEmpty ? null : _reasonCtl.text.trim(),
          );
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDone();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Movement recorded'),
            backgroundColor: AppColors.success.withAlpha(200),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiError(e)),
            backgroundColor: AppColors.error.withAlpha(200),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTransfer = widget.type == 'transfer';

    return AlertDialog(
      title: Text(_title),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(_itemIdCtl,   'Item ID (UUID)', required: true),
            const SizedBox(height: 12),
            if (!isTransfer) ...[
              _field(_locationCtl, 'Location', hint: 'MAIN'),
            ] else ...[
              _field(_fromLocCtl, 'From Location', required: true),
              const SizedBox(height: 12),
              _field(_toLocCtl,   'To Location',   required: true),
            ],
            const SizedBox(height: 12),
            _field(
              _qtyCtl,
              widget.type == 'adjust' ? 'Qty (+/-)' : 'Quantity',
              keyboard: TextInputType.numberWithOptions(signed: widget.type == 'adjust', decimal: true),
              required: true,
            ),
            const SizedBox(height: 12),
            _field(
              _reasonCtl,
              widget.type == 'adjust' ? 'Reason (required)' : 'Remarks (optional)',
              maxLines: 2,
              required: widget.type == 'adjust',
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctl,
    String label, {
    String? hint,
    bool required = false,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) => TextFormField(
    controller: ctl,
    keyboardType: keyboard,
    maxLines: maxLines,
    decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
    validator: required
        ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null
        : null,
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    ),
  );
}
