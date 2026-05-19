import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shared_budget_model.dart';
import '../providers/firestore_providers.dart';
import '../services/auth_service.dart';
import '../services/shared_budget_service.dart';

class SharedBudgetsScreen extends ConsumerWidget {
  const SharedBudgetsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    final svc = ref.read(sharedBudgetServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shared Budgets')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showOptions(context, ref, svc, uid),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<SharedBudgetModel>>(
        stream: svc.streamMine(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No shared budgets yet.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showOptions(context, ref, svc, uid),
                    child: const Text('Create or join one'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) =>
                _SharedBudgetTile(budget: list[i], uid: uid),
          );
        },
      ),
    );
  }

  void _showOptions(
      BuildContext context, WidgetRef ref, SharedBudgetService svc, String uid) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Shared Budget',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.create),
            title: const Text('Create new'),
            onTap: () {
              Navigator.pop(context);
              _showCreateDialog(context, svc);
            },
          ),
          ListTile(
            leading: const Icon(Icons.group_add),
            title: const Text('Join by invite code'),
            onTap: () {
              Navigator.pop(context);
              _showJoinDialog(context, svc);
            },
          ),
        ]),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, SharedBudgetService svc) {
    final nameCtrl = TextEditingController();
    String currency = 'BDT';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Create Shared Budget'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Budget name'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: currency,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: const [
                DropdownMenuItem(value: 'BDT', child: Text('BDT')),
                DropdownMenuItem(value: 'USD', child: Text('USD')),
                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
              ],
              onChanged: (v) => setState(() => currency = v!),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                await svc.create(name, currency);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context, SharedBudgetService svc) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Shared Budget'),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(labelText: 'Invite code'),
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final result = await svc.joinByCode(codeCtrl.text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text(result != null
                      ? 'Joined "${result.name}"'
                      : 'Invalid invite code'),
                ));
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _SharedBudgetTile extends ConsumerWidget {
  final SharedBudgetModel budget;
  final String uid;
  const _SharedBudgetTile(
      {Key? key, required this.budget, required this.uid})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(sharedBudgetServiceProvider);
    final isOwner = budget.ownerUid == uid;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        title: Text(budget.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${budget.memberUids.length} member${budget.memberUids.length == 1 ? '' : 's'}  •  ${budget.currency}'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              const Text('Invite code: ',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              Text(budget.inviteCode,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: budget.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')));
                },
              ),
            ]),
          ),
          _BudgetCategoryEditor(budget: budget),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isOwner)
                  TextButton(
                    onPressed: () async {
                      await svc.leave(budget.id);
                    },
                    child: const Text('Leave'),
                  ),
                if (isOwner)
                  TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete shared budget?'),
                          content: const Text(
                              'This removes the budget for all members.'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (ok == true) await svc.delete(budget.id);
                    },
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCategoryEditor extends ConsumerStatefulWidget {
  final SharedBudgetModel budget;
  const _BudgetCategoryEditor({Key? key, required this.budget})
      : super(key: key);

  @override
  ConsumerState<_BudgetCategoryEditor> createState() =>
      _BudgetCategoryEditorState();
}

class _BudgetCategoryEditorState
    extends ConsumerState<_BudgetCategoryEditor> {
  final Map<String, TextEditingController> _ctrls = {};

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid =
        ref.read(authServiceProvider).currentUser?.uid ?? '';
    final catsAsync = ref.watch(categoriesStreamProvider(uid));

    return catsAsync.when(
      data: (cats) => Column(
        children: cats.map((cat) {
          _ctrls.putIfAbsent(
            cat.id,
            () => TextEditingController(
              text: widget.budget.categoryBudgets[cat.id]?.toString() ?? '',
            ),
          );
          final ctrl = _ctrls[cat.id]!;
          final svc = ref.read(sharedBudgetServiceProvider);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(children: [
              Expanded(child: Text(cat.name)),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      hintText: 'Budget', suffixText: widget.budget.currency),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.save, size: 20),
                onPressed: () async {
                  final v = double.tryParse(ctrl.text);
                  if (v == null || v <= 0) return;
                  await svc.setCategoryBudget(
                      widget.budget.id, cat.id, v);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Budget updated')));
                  }
                },
              ),
            ]),
          );
        }).toList(),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
