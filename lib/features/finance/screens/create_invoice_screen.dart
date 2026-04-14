import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  ConsumerState<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'SALES';
  String _currency = 'INR';
  final _invoiceNoCtrl = TextEditingController();
  final _buyerIdCtrl   = TextEditingController();
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate     = DateTime.now().add(const Duration(days: 30));
  bool _submitting = false;

  final List<_LineItem> _lines = [_LineItem()];

  double get _subTotal => _lines.fold(0.0, (sum, l) => sum + l.amount);
  double get _totalGst => _lines.fold(0.0, (sum, l) => sum + l.gstAmount);
  double get _grandTotal => _subTotal + _totalGst;

  @override
  void dispose() {
    _invoiceNoCtrl.dispose();
    _buyerIdCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool isInvoice) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isInvoice ? _invoiceDate : _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isInvoice) {
          _invoiceDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/v1/finance/invoices', data: {
        'type': _type,
        'buyerId': _buyerIdCtrl.text.trim(),
        'invoiceNo': _invoiceNoCtrl.text.trim(),
        'invoiceDate': _invoiceDate.toIso8601String(),
        'dueDate': _dueDate.toIso8601String(),
        'currency': _currency,
        'lines': _lines.map((l) => {
          'description': l.descCtrl.text.trim(),
          'hsnCode': l.hsnCtrl.text.trim(),
          'qty': double.tryParse(l.qtyCtrl.text) ?? 0,
          'rate': double.tryParse(l.rateCtrl.text) ?? 0,
          'gstPct': double.tryParse(l.gstCtrl.text) ?? 0,
        }).toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice created')),
        );
        context.go('/finance/invoices');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${apiError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    final numFmt = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(title: const Text('Create Invoice')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Type ──
            const Text('Type', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Row(children: [
              _RadioChip(label: 'SALES', selected: _type == 'SALES', onTap: () => setState(() => _type = 'SALES')),
              const SizedBox(width: 8),
              _RadioChip(label: 'PURCHASE', selected: _type == 'PURCHASE', onTap: () => setState(() => _type = 'PURCHASE')),
            ]),
            const SizedBox(height: 16),

            // ── Buyer ID ──
            TextFormField(
              controller: _buyerIdCtrl,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(labelText: 'Buyer / Supplier ID', isDense: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // ── Invoice No ──
            TextFormField(
              controller: _invoiceNoCtrl,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(labelText: 'Invoice No', isDense: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // ── Dates ──
            Row(children: [
              Expanded(
                child: _DateField(
                  label: 'Invoice Date',
                  value: dateFmt.format(_invoiceDate),
                  onTap: () => _pickDate(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Due Date',
                  value: dateFmt.format(_dueDate),
                  onTap: () => _pickDate(false),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Currency ──
            DropdownButtonFormField<String>(
              value: _currency,
              dropdownColor: AppColors.elevated,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(labelText: 'Currency', isDense: true),
              items: const [
                DropdownMenuItem(value: 'INR', child: Text('INR')),
                DropdownMenuItem(value: 'USD', child: Text('USD')),
                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                DropdownMenuItem(value: 'GBP', child: Text('GBP')),
              ],
              onChanged: (v) => setState(() => _currency = v ?? 'INR'),
            ),
            const SizedBox(height: 20),

            // ── Line Items ──
            Row(children: [
              const Text('Line Items', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
                onPressed: () => setState(() => _lines.add(_LineItem())),
              ),
            ]),
            const SizedBox(height: 8),
            ..._lines.asMap().entries.map((entry) => _LineItemCard(
              index: entry.key,
              line: entry.value,
              onRemove: _lines.length > 1 ? () => setState(() {
                _lines[entry.key].dispose();
                _lines.removeAt(entry.key);
              }) : null,
              onChanged: () => setState(() {}),
            )),

            const SizedBox(height: 16),

            // ── Totals ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(children: [
                _TotalRow(label: 'Sub Total', value: numFmt.format(_subTotal)),
                const SizedBox(height: 4),
                _TotalRow(label: 'GST', value: numFmt.format(_totalGst)),
                const Divider(height: 16),
                _TotalRow(label: 'Grand Total', value: numFmt.format(_grandTotal), bold: true),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Submit ──
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Invoice'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Line item model ──────────────────────────────────────────────────────────

class _LineItem {
  final descCtrl = TextEditingController();
  final hsnCtrl  = TextEditingController();
  final qtyCtrl  = TextEditingController();
  final rateCtrl = TextEditingController();
  final gstCtrl  = TextEditingController(text: '18');

  double get qty     => double.tryParse(qtyCtrl.text) ?? 0;
  double get rate    => double.tryParse(rateCtrl.text) ?? 0;
  double get gstPct  => double.tryParse(gstCtrl.text) ?? 0;
  double get amount  => qty * rate;
  double get gstAmount => amount * gstPct / 100;

  void dispose() {
    descCtrl.dispose();
    hsnCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
    gstCtrl.dispose();
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _LineItemCard extends StatelessWidget {
  final int index;
  final _LineItem line;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _LineItemCard({required this.index, required this.line, this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Item ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13)),
            const Spacer(),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ]),
          const SizedBox(height: 8),
          TextFormField(
            controller: line.descCtrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: const InputDecoration(labelText: 'Description', isDense: true),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: line.hsnCtrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: const InputDecoration(labelText: 'HSN Code', isDense: true),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: line.qtyCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: line.rateCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Rate', isDense: true),
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: line.gstCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(labelText: 'GST %', isDense: true),
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _RadioChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RadioChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent.withAlpha(30) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? AppColors.accent.withAlpha(80) : AppColors.border),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12,
        color: selected ? AppColors.accent : AppColors.textTertiary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      )),
    ),
  );
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
    ),
  );
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _TotalRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(
        color: bold ? AppColors.textPrimary : AppColors.textSecondary,
        fontSize: 13,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      )),
      Text(value, style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: bold ? 16 : 13,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      )),
    ],
  );
}
