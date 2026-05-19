import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../providers/firestore_providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final TransactionModel? existing;
  final double? initialAmount;
  final String? initialType;
  final String? initialCategoryId;
  const AddTransactionScreen({Key? key, this.existing, this.initialAmount, this.initialType, this.initialCategoryId}) : super(key: key);

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'expense';
  String? _categoryId;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _currency = 'BDT';

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _type = widget.existing!.type;
      _categoryId = widget.existing!.categoryId;
      _amountCtrl.text = widget.existing!.amount.toString();
      _noteCtrl.text = widget.existing!.note ?? '';
      _date = widget.existing!.date;
      _currency = widget.existing!.currency;
    } else {
      if (widget.initialAmount != null) _amountCtrl.text = widget.initialAmount!.toString();
      if (widget.initialType != null) _type = widget.initialType!;
      if (widget.initialCategoryId != null) _categoryId = widget.initialCategoryId!;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authServiceProvider);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    final svc = ref.read(firestoreServiceProvider);
    final id = widget.existing?.id ?? const Uuid().v4();
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0 || amount > 999999999) return;
    final tx = TransactionModel(
      id: id,
      type: _type,
      categoryId: _categoryId ?? 'uncategorized',
      amount: amount,
      currency: _currency,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
      date: _date,
    );
    if (widget.existing == null) {
      try {
        await svc.addTransaction(uid, tx);
      } catch (_) {
        // enqueue for background sync
        final sync = ref.read(syncServiceProvider);
        await sync.enqueueSet(uid, 'transactions', id, tx.toMap());
      }
    } else {
      try {
        await svc.updateTransaction(uid, tx);
      } catch (_) {
        final sync = ref.read(syncServiceProvider);
        await sync.enqueueUpdate(uid, 'transactions', id, tx.toMap());
      }
    }
    // Check budgets after saving
    try {
      final budget = await svc.getBudget(uid, tx.categoryId);
      if (budget != null) {
        final monthSum = await svc.getCategoryMonthSum(uid, tx.categoryId, DateTime(tx.date.year, tx.date.month));
        if (monthSum >= budget) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Budget exceeded for ${tx.categoryId}: ${monthSum.toStringAsFixed(2)} / $budget')));
        } else if (monthSum >= 0.9 * budget) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approaching budget for ${tx.categoryId}: ${monthSum.toStringAsFixed(2)} / $budget')));
        }
      }
    } catch (_) {}

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add Transaction' : 'Edit Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Expense'),
                    value: 'expense',
                    groupValue: _type,
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Income'),
                    value: 'income',
                    groupValue: _type,
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                )
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter an amount';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Enter a positive amount';
                      if (n > 999999999) return 'Amount too large';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _currency,
                  items: const [
                    DropdownMenuItem(value: 'BDT', child: Text('BDT')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                  ],
                  onChanged: (v) => setState(() => _currency = v!),
                )
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final a in [50, 100, 200, 500, 1000])
                  ActionChip(label: Text(a.toString()), onPressed: () => setState(() => _amountCtrl.text = a.toString())),
              ]),
              const SizedBox(height: 8),
              uid == null
                  ? const SizedBox.shrink()
                  : ref.watch(categoriesStreamProvider(uid)).when(
                      data: (cats) => DropdownButtonFormField<String>(
                            value: _categoryId ?? (cats.isNotEmpty ? cats.first.id : null),
                            items: cats
                                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                                .toList(),
                            onChanged: (v) => setState(() => _categoryId = v),
                            decoration: const InputDecoration(labelText: 'Category'),
                          ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Error loading categories'),
                    ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLength: 500,
                validator: (v) => (v != null && v.length > 500) ? 'Note must be 500 characters or fewer' : null,
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _save, child: const Text('Save'))
            ],
          ),
        ),
      ),
    );
  }
}
