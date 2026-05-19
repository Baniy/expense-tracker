import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/firestore_providers.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';
import '../services/firestore_service.dart';
import '../services/settings_service.dart';
import 'recurring_transactions_screen.dart';
import 'shared_budgets_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    final user = auth.currentUser;
    final uid = user?.uid;
    final catsAsync =
        uid == null ? null : ref.watch(categoriesStreamProvider(uid));
    final settings = ref.watch(settingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user?.email ?? ''}'),
            const SizedBox(height: 16),

            // Feature shortcuts
            const Text('Features',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.repeat),
              title: const Text('Recurring Transactions'),
              subtitle: const Text('Scheduled income & expenses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const RecurringTransactionsScreen())),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.group),
              title: const Text('Shared Budgets'),
              subtitle: const Text('Budget with family or teammates'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SharedBudgetsScreen())),
            ),
            const Divider(),

            // Personal monthly budgets
            const Text('Personal Budgets (monthly per category)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (uid != null)
              catsAsync!.when(
                data: (cats) => Column(
                  children: cats
                      .map((c) => _BudgetRow(
                          uid: uid,
                          categoryId: c.id,
                          categoryName: c.name))
                      .toList(),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) =>
                    const Text('Error loading categories'),
              ),
            const Divider(),

            // Settings & export
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Export CSV'),
                  onPressed: uid == null
                      ? null
                      : () async {
                          try {
                            final exporter = ExportService();
                            await exporter.exportTransactionsToCsv(uid);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Transactions exported successfully')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Export failed')),
                              );
                            }
                          }
                        },
                ),
              ),
              const SizedBox(width: 8),
              Column(children: [
                const Text('Dark Mode'),
                Switch(
                  value: settings.isDark,
                  onChanged: (v) =>
                      ref.read(settingsNotifierProvider.notifier).setDark(v),
                )
              ])
            ]),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await auth.signOut();
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sign out'),
            ),
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
  const _BudgetRow(
      {Key? key,
      required this.uid,
      required this.categoryId,
      required this.categoryName})
      : super(key: key);

  @override
  ConsumerState<_BudgetRow> createState() => _BudgetRowState();
}

class _BudgetRowState extends ConsumerState<_BudgetRow> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final svc = ref.read(firestoreServiceProvider);
    final val = await svc.getBudget(widget.uid, widget.categoryId);
    if (mounted) {
      setState(() => _ctrl.text = val != null ? val.toString() : '');
    }
  }

  Future<void> _save() async {
    final v = double.tryParse(_ctrl.text);
    if (v == null || v <= 0) return;
    final svc = ref.read(firestoreServiceProvider);
    await svc.setBudget(widget.uid, widget.categoryId, v);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Budget saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(widget.categoryName)),
      SizedBox(
        width: 120,
        child: TextField(
          controller: _ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Amount'),
        ),
      ),
      IconButton(icon: const Icon(Icons.save), onPressed: _save),
    ]);
  }
}
