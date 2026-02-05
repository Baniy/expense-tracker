import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'services/auth_service.dart';
import '../providers/firestore_providers.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/category_pie_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  List<DateTime> _lastNMonths(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) {
      final d = DateTime(now.year, now.month - (n - 1 - i), 1);
      return d;
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    final user = auth.currentUser;
    final uid = user?.uid;

    if (uid == null) return const Scaffold(body: Center(child: Text('Not signed in')));

    final txsAsync = ref.watch(transactionsStreamProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: txsAsync.when(
          data: (txs) {
            // Totals
            double income = 0.0;
            double expense = 0.0;
            for (final t in txs) {
              if (t.type == 'income') income += t.amount;
              if (t.type == 'expense') expense += t.amount;
            }

            // Monthly chart: last 6 months
            final months = _lastNMonths(6);
            final labels = months.map((m) => DateFormat.MMM().format(m)).toList();
            final incomePerMonth = List<double>.filled(months.length, 0.0);
            final expensePerMonth = List<double>.filled(months.length, 0.0);
            for (final t in txs) {
              final idx = months.indexWhere((m) => m.year == t.date.year && m.month == t.date.month);
              if (idx >= 0) {
                if (t.type == 'income') incomePerMonth[idx] += t.amount;
                if (t.type == 'expense') expensePerMonth[idx] += t.amount;
              }
            }

            // Category pie (expenses only)
            final Map<String, double> categorySums = {};
            for (final t in txs.where((e) => e.type == 'expense')) {
              categorySums[t.categoryId] = (categorySums[t.categoryId] ?? 0) + t.amount;
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(children: [const Text('Total Income'), Text('${income.toStringAsFixed(2)} BDT')]),
                          Column(children: [const Text('Total Expense'), Text('${expense.toStringAsFixed(2)} BDT')]),
                          Column(children: [const Text('Balance'), Text('${(income - expense).toStringAsFixed(2)} BDT')]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Monthly (last 6 months)', style: TextStyle(fontWeight: FontWeight.bold)),
                  MonthlyBarChart(income: incomePerMonth, expense: expensePerMonth, labels: labels),
                  const SizedBox(height: 12),
                  const Text('Category Breakdown (expenses)', style: TextStyle(fontWeight: FontWeight.bold)),
                  CategoryPieChart(data: categorySums),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
