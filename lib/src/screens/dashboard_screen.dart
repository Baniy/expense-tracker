import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/firestore_providers.dart';
import '../screens/reports_screen.dart';
import '../services/auth_service.dart';
import '../services/fx_service.dart';
import '../services/settings_service.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/category_pie_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  List<DateTime> _lastNMonths(int n) {
    final now = DateTime.now();
    return List.generate(
        n, (i) => DateTime(now.year, now.month - (n - 1 - i), 1));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text('Not signed in')));
    }

    final displayCurrency =
        ref.watch(settingsNotifierProvider).currency;
    final txsAsync = ref.watch(transactionsStreamProvider(uid));
    final ratesAsync = ref.watch(fxRatesProvider(displayCurrency));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          DropdownButton<String>(
            value: displayCurrency,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'BDT', child: Text('BDT')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
              DropdownMenuItem(value: 'EUR', child: Text('EUR')),
            ],
            onChanged: (v) {
              if (v != null) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .setCurrency(v);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: txsAsync.when(
          data: (txs) {
            final rates = ratesAsync.maybeWhen(
              data: (r) => r,
              orElse: () => <String, double>{},
            );

            double _convert(double amount, String from) {
              if (from == displayCurrency || rates.isEmpty) {
                return amount;
              }
              // rates[X] = 1 displayCurrency = X units of that currency
              final fromRate = rates[from];
              if (fromRate == null || fromRate == 0) return amount;
              return amount / fromRate;
            }

            double income = 0.0;
            double expense = 0.0;
            for (final t in txs) {
              final a = _convert(t.amount, t.currency);
              if (t.type == 'income') income += a;
              if (t.type == 'expense') expense += a;
            }

            final months = _lastNMonths(6);
            final labels =
                months.map((m) => DateFormat.MMM().format(m)).toList();
            final incomePerMonth =
                List<double>.filled(months.length, 0.0);
            final expensePerMonth =
                List<double>.filled(months.length, 0.0);
            for (final t in txs) {
              final a = _convert(t.amount, t.currency);
              final idx = months.indexWhere(
                  (m) => m.year == t.date.year && m.month == t.date.month);
              if (idx >= 0) {
                if (t.type == 'income') incomePerMonth[idx] += a;
                if (t.type == 'expense') expensePerMonth[idx] += a;
              }
            }

            final Map<String, double> categorySums = {};
            for (final t in txs.where((e) => e.type == 'expense')) {
              categorySums[t.categoryId] =
                  (categorySums[t.categoryId] ?? 0) +
                      _convert(t.amount, t.currency);
            }

            final ratesLabel = ratesAsync.maybeWhen(
              data: (_) {
                final fetched = ref
                    .read(fxServiceProvider)
                    .lastFetched(displayCurrency);
                if (fetched == null) return '';
                final mins =
                    DateTime.now().difference(fetched).inMinutes;
                return mins == 0
                    ? 'Rates just updated'
                    : 'Rates ${mins}m ago';
              },
              loading: () => 'Fetching rates…',
              orElse: () => displayCurrency == 'BDT' ? '' : 'Offline rates',
            );

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [
                            Column(children: [
                              const Text('Total Income'),
                              Text(
                                  '${income.toStringAsFixed(2)} $displayCurrency',
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                            ]),
                            Column(children: [
                              const Text('Total Expense'),
                              Text(
                                  '${expense.toStringAsFixed(2)} $displayCurrency',
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold)),
                            ]),
                            Column(children: [
                              const Text('Balance'),
                              Text(
                                  '${(income - expense).toStringAsFixed(2)} $displayCurrency',
                                  style: TextStyle(
                                      color: (income - expense) >= 0
                                          ? Colors.blue
                                          : Colors.orange,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ],
                        ),
                        if (ratesLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(ratesLabel,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Monthly (last 6 months)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  MonthlyBarChart(
                      income: incomePerMonth,
                      expense: expensePerMonth,
                      labels: labels),
                  const SizedBox(height: 12),
                  const Text('Category Breakdown (expenses)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  CategoryPieChart(data: categorySums),
                ],
              ),
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
