import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  const RecordPaymentScreen({super.key});

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceIdCtrl  = TextEditingController();
  final _amountCtrl     = TextEditingController();
  final _referenceCtrl  = TextEditingController();
  String _mode = 'BANK_TRANSFER';
  DateTime _paymentDate = DateTime.now();
  bool _submitting = false;

  // Simulated invoice balance (populated after searching)
  double? _invoiceTotal;
  double? _invoicePaid;
  String? _invoiceNo;

  double get _balance => (_invoiceTotal ?? 0) - (_invoicePaid ?? 0);

  @override
  void dispose() {
    _invoiceIdCtrl.dispose();
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupInvoice() async {
    final id = _invoiceIdCtrl.text.trim();
    if (id.isEmpty) return;

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/api/v1/finance/invoices/$id');
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _invoiceNo    = data['invoiceNo'] as String?;
        _invoiceTotal = (data['total'] ?? 0).toDouble();
        _invoicePaid  = (data['paidAmount'] ?? 0).toDouble();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice not found: ${apiError(e)}')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/v1/finance/payments', data: {
        'invoiceId': _invoiceIdCtrl.text.trim(),
        'amount': double.tryParse(_amountCtrl.text) ?? 0,
        'mode': _mode,
        'reference': _referenceCtrl.text.trim(),
        'paymentDate': _paymentDate.toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded')),
        );
        context.go('/finance');
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
      appBar: AppBar(title: const Text('Record Payment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Invoice Search ──
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _invoiceIdCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Invoice ID',
                    hintText: 'Enter invoice ID',
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _lookupInvoice,
                icon: const Icon(Icons.search_rounded, color: AppColors.primary),
              ),
            ]),

            // ── Invoice Balance ──
            if (_invoiceNo != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Invoice: $_invoiceNo', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Total: ${numFmt.format(_invoiceTotal ?? 0)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text('Paid: ${numFmt.format(_invoicePaid ?? 0)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'Balance Remaining: ${numFmt.format(_balance)}',
                    style: TextStyle(
                      color: _balance > 0 ? AppColors.warning : AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 16),

            // ── Amount ──
            TextFormField(
              controller: _amountCtrl,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(labelText: 'Amount', isDense: true),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final amt = double.tryParse(v);
                if (amt == null || amt <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // ── Payment Mode ──
            DropdownButtonFormField<String>(
              value: _mode,
              dropdownColor: AppColors.elevated,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(labelText: 'Payment Mode', isDense: true),
              items: const [
                DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(value: 'UPI', child: Text('UPI')),
              ],
              onChanged: (v) => setState(() => _mode = v ?? 'BANK_TRANSFER'),
            ),
            const SizedBox(height: 12),

            // ── Reference ──
            TextFormField(
              controller: _referenceCtrl,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(labelText: 'Reference / Transaction ID', isDense: true),
            ),
            const SizedBox(height: 12),

            // ── Date ──
            GestureDetector(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Payment Date', isDense: true),
                child: Text(dateFmt.format(_paymentDate), style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              ),
            ),

            const SizedBox(height: 24),

            // ── Submit ──
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Record Payment'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
