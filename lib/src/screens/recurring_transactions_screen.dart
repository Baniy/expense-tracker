import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_transaction_model.dart';
import '../providers/firestore_providers.dart';
import '../services/auth_service.dart';
import '../services/recurring_service.dart';

class RecurringTransactionsScreen extends ConsumerWidget {
  const RecurringTransactionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final svc = ref.read(recurringServiceProvider);
    final stream = svc.stream(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Transactions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref, uid),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<RecurringTransactionModel>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('No recurring transactions'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) => _RecurringTile(uid: uid, model: list[i]),
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddRecurringSheet(uid: uid),
    );
  }
}

class _RecurringTile extends ConsumerWidget {
  final String uid;
  final RecurringTransactionModel model;
  const _RecurringTile({Key? key, required this.uid, required this.model})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(recurringServiceProvider);
    final color = model.type == 'income' ? Colors.green : Colors.red;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(
          model.isActive ? Icons.repeat : Icons.repeat_one_outlined,
          color: color,
        ),
      ),
      title: Text(
          '${model.type == 'expense' ? '-' : '+'}${model.amount.toStringAsFixed(2)} ${model.currency}'),
      subtitle: Text(
          '${model.frequency}  •  next: ${DateFormat.yMd().format(model.nextDue)}'
          '${model.note != null ? '  •  ${model.note}' : ''}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Switch(
          value: model.isActive,
          onChanged: (v) async {
            final updated = model.copyWith(isActive: v);
            await svc.update(uid, updated);
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Delete recurring transaction?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete')),
                ],
              ),
            );
            if (ok == true) await svc.delete(uid, model.id);
          },
        ),
      ]),
    );
  }
}

class _AddRecurringSheet extends ConsumerStatefulWidget {
  final String uid;
  const _AddRecurringSheet({Key? key, required this.uid}) : super(key: key);

  @override
  ConsumerState<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends ConsumerState<_AddRecurringSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _type = 'expense';
  String _frequency = 'monthly';
  String _currency = 'BDT';
  String? _categoryId;
  DateTime _startDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesStreamProvider(widget.uid));
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('New Recurring Transaction',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Expense'),
                  value: 'expense',
                  groupValue: _type,
                  onChanged: (v) => setState(() => _type = v!),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Income'),
                  value: 'income',
                  groupValue: _type,
                  onChanged: (v) => setState(() => _type = v!),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ]),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Positive number';
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
              ),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
              ],
              onChanged: (v) => setState(() => _frequency = v!),
            ),
            const SizedBox(height: 8),
            catsAsync.when(
              data: (cats) => DropdownButtonFormField<String>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: cats
                    .map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                  'First due: ${DateFormat.yMd().format(_startDate)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _startDate = d);
              },
            ),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLength: 500,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountCtrl.text);
    final model = RecurringTransactionModel(
      id: const Uuid().v4(),
      type: _type,
      categoryId: _categoryId ?? 'uncategorized',
      amount: amount,
      currency: _currency,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
      frequency: _frequency,
      nextDue: _startDate,
    );
    final svc = ref.read(recurringServiceProvider);
    await svc.add(widget.uid, model);
    if (mounted) Navigator.of(context).pop();
  }
}
