import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../providers/firestore_providers.dart';
import '../services/export_service.dart';
import '../services/firestore_service.dart';
import '../models/budget_model.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    final user = auth.currentUser;
    final uid = user?.uid;
    final catsAsync = uid == null ? null : ref.watch(categoriesStreamProvider(uid));
    final settings = ref.watch(settingsNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user?.email ?? ''}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await auth.signOut();
              },
              child: const Text('Sign out'),
            ),
            const SizedBox(height: 12),
            const Text('Budgets (monthly per category)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (uid != null)
              catsAsync!.when(
                data: (cats) => Column(
                  children: cats.map((c) => _BudgetRow(uid: uid, categoryId: c.id, categoryName: c.name)).toList(),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Error loading categories'),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: uid == null
                      ? null
                      : () async {
                          final exporter = ExportService();
                          final path = await exporter.exportTransactionsToCsv(uid);
                          await Clipboard.setData(ClipboardData(text: path));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported CSV to $path (path copied)')));
                        },
                  child: const Text('Export Transactions (CSV)'),
                ),
              ),
              const SizedBox(width: 8),
              Column(children: [
                const Text('Dark Mode'),
                Switch(
                  value: settings.isDark,
                  onChanged: (v) => ref.read(settingsNotifierProvider.notifier).setDark(v),
                )
              ])
            ])
          ],
        ),
      ),
    );
  }
}

class _BudgetRow extends ConsumerStatefulWidget {
  final String uid;
  final String categoryId;
  final String categoryName;
  const _BudgetRow({Key? key, required this.uid, required this.categoryId, required this.categoryName}) : super(key: key);

  @override
  ConsumerState<_BudgetRow> createState() => _BudgetRowState();
}

class _BudgetRowState extends ConsumerState<_BudgetRow> {
  final _ctrl = TextEditingController();
  double? _current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = ref.read(firestoreServiceProvider);
    final val = await svc.getBudget(widget.uid, widget.categoryId);
    setState(() {
      _current = val;
      _ctrl.text = val != null ? val.toString() : '';
    });
  }

  Future<void> _save() async {
    final v = double.tryParse(_ctrl.text);
    if (v == null) return;
    final svc = ref.read(firestoreServiceProvider);
    await svc.setBudget(widget.uid, widget.categoryId, v);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(widget.categoryName)),
      SizedBox(width: 120, child: TextField(controller: _ctrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: 'Amount'))),
      IconButton(icon: const Icon(Icons.save), onPressed: _save),
    ]);
  }
}
