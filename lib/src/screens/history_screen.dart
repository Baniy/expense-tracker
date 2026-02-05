import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../providers/firestore_providers.dart';
import 'add_transaction_screen.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _search = '';
  String? _categoryId;
  DateTime? _from;
  DateTime? _to;
  final _searchCtrl = TextEditingController();

  Future<void> _pickFrom(BuildContext context) async {
    final d = await showDatePicker(context: context, initialDate: _from ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo(BuildContext context) async {
    final d = await showDatePicker(context: context, initialDate: _to ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null) setState(() => _to = d);
  }

  List<TransactionModel> _applyFilters(List<TransactionModel> txs) {
    return txs.where((t) {
      if (_categoryId != null && _categoryId!.isNotEmpty && t.categoryId != _categoryId) return false;
      if (_from != null && t.date.isBefore(_from!)) return false;
      if (_to != null && t.date.isAfter(_to!)) return false;
      if (_search.isNotEmpty) {
        final s = _search.toLowerCase();
        if (!(t.note?.toLowerCase().contains(s) ?? false) && !t.categoryId.toLowerCase().contains(s) && !t.amount.toString().contains(s)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Not signed in')));

    final txsAsync = ref.watch(transactionsStreamProvider(uid));
    final catsAsync = ref.watch(categoriesStreamProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search note, category, amount'),
                onChanged: (v) => setState(() => _search = v.trim()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () async {
                // open a small dialog with date pickers
                await showModalBottomSheet(context: context, builder: (_) => _buildFilterSheet(catsAsync));
              },
            )
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: txsAsync.when(
              data: (txs) {
                final filtered = _applyFilters(txs);
                if (filtered.isEmpty) return const Center(child: Text('No transactions'));
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _TransactionTile(tx: filtered[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          )
        ]),
      ),
    );
  }

  Widget _buildFilterSheet(AsyncValue<List<dynamic>> catsAsync) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text('From: ${_from != null ? DateFormat.yMd().format(_from!) : 'Any'}')),
          TextButton(onPressed: () => _pickFrom(context), child: const Text('Pick')),
        ]),
        Row(children: [
          Expanded(child: Text('To: ${_to != null ? DateFormat.yMd().format(_to!) : 'Any'}')),
          TextButton(onPressed: () => _pickTo(context), child: const Text('Pick')),
        ]),
        const SizedBox(height: 8),
        catsAsync.when(
          data: (cats) => DropdownButtonFormField<String>(
            value: _categoryId,
            items: [const DropdownMenuItem(value: null, child: Text('All'))]
                .followedBy(cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))))
                .toList(),
            onChanged: (v) => setState(() => _categoryId = v),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => setState(() {
                _from = null;
                _to = null;
                _categoryId = null;
                _searchCtrl.clear();
                _search = '';
              }), child: const Text('Clear')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ])
      ]),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final TransactionModel tx;
  const _TransactionTile({Key? key, required this.tx}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    final uid = auth.currentUser?.uid;
    return ListTile(
      title: Text('${tx.type == 'expense' ? '-' : '+'}${tx.amount.toStringAsFixed(2)} ${tx.currency}'),
      subtitle: Text('${tx.categoryId} • ${tx.note ?? ''} • ${DateFormat.yMd().format(tx.date)}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: tx))),
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: uid == null
                ? null
                : () async {
                    final svc = ref.read(firestoreServiceProvider);
                    try {
                      await svc.deleteTransaction(uid, tx.id);
                    } catch (_) {
                      final sync = ref.read(syncServiceProvider);
                      await sync.enqueueDelete(uid, 'transactions', tx.id);
                    }
                  },
        ),
      ]),
    );
  }
}
