import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../providers/firestore_providers.dart';
import '../services/auth_service.dart';
import '../services/fx_service.dart';
import '../services/settings_service.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final displayCurrency =
        ref.watch(settingsNotifierProvider).currency;
    final txsAsync = ref.watch(transactionsStreamProvider(uid));
    final ratesAsync = ref.watch(fxRatesProvider(displayCurrency));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          _CurrencyPicker(current: displayCurrency),
        ],
      ),
      body: txsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (txs) {
          final rates = ratesAsync.maybeWhen(
            data: (r) => r,
            orElse: () => <String, double>{},
          );
          return _ReportsBody(
              txs: txs,
              displayCurrency: displayCurrency,
              rates: rates);
        },
      ),
    );
  }
}

class _CurrencyPicker extends ConsumerWidget {
  final String current;
  const _CurrencyPicker({Key? key, required this.current})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButton<String>(
      value: current,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: 'BDT', child: Text('BDT')),
        DropdownMenuItem(value: 'USD', child: Text('USD')),
        DropdownMenuItem(value: 'EUR', child: Text('EUR')),
      ],
      onChanged: (v) {
        if (v != null) {
          ref.read(settingsNotifierProvider.notifier).setCurrency(v);
        }
      },
    );
  }
}

class _ReportsBody extends StatelessWidget {
  final List<TransactionModel> txs;
  final String displayCurrency;
  final Map<String, double> rates;

  const _ReportsBody({
    Key? key,
    required this.txs,
    required this.displayCurrency,
    required this.rates,
  }) : super(key: key);

  double _convert(double amount, String from) {
    if (from == displayCurrency) return amount;
    final toRate = rates[displayCurrency] ?? 1.0;
    final fromRate = rates[from] ?? 1.0;
    // rates are relative to displayCurrency as base
    if (rates.containsKey(displayCurrency)) {
      // rates[X] = how many X per 1 displayCurrency — invert
      // Actually rates are: 1 displayCurrency = rates[target]
      // We want: amount from -> displayCurrency
      // from->DC: amount / rates[from]   (if rates are 1 DC = X from)
      // The FxService fetches getRates(displayCurrency), so rates[from]
      // means "1 displayCurrency = rates[from] units of from"
      return amount / (fromRate == 0 ? 1.0 : fromRate);
    }
    return amount;
  }

  List<DateTime> _lastNMonths(int n) {
    final now = DateTime.now();
    return List.generate(n,
        (i) => DateTime(now.year, now.month - (n - 1 - i), 1));
  }

  @override
  Widget build(BuildContext context) {
    final months = _lastNMonths(12);
    final labels =
        months.map((m) => DateFormat.MMM().format(m)).toList();

    final incomePerMonth = List<double>.filled(12, 0);
    final expensePerMonth = List<double>.filled(12, 0);
    final Map<String, double> categoryTotals = {};

    for (final t in txs) {
      final amount = _convert(t.amount, t.currency);
      final idx = months.indexWhere(
          (m) => m.year == t.date.year && m.month == t.date.month);
      if (idx >= 0) {
        if (t.type == 'income') incomePerMonth[idx] += amount;
        if (t.type == 'expense') expensePerMonth[idx] += amount;
      }
      if (t.type == 'expense') {
        categoryTotals[t.categoryId] =
            (categoryTotals[t.categoryId] ?? 0) + amount;
      }
    }

    final savingsPerMonth = List<double>.generate(
        12, (i) => incomePerMonth[i] - expensePerMonth[i]);

    final totalIncome = incomePerMonth.fold(0.0, (a, b) => a + b);
    final totalExpense = expensePerMonth.fold(0.0, (a, b) => a + b);
    final savingsRate =
        totalIncome > 0 ? (totalIncome - totalExpense) / totalIncome : 0.0;

    final fmt = NumberFormat('#,##0.00');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(children: [
            _SummaryCard(
                label: 'Total Income',
                value: '${fmt.format(totalIncome)} $displayCurrency',
                color: Colors.green),
            const SizedBox(width: 8),
            _SummaryCard(
                label: 'Total Expense',
                value: '${fmt.format(totalExpense)} $displayCurrency',
                color: Colors.red),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _SummaryCard(
                label: 'Net Savings',
                value:
                    '${fmt.format(totalIncome - totalExpense)} $displayCurrency',
                color: (totalIncome - totalExpense) >= 0
                    ? Colors.blue
                    : Colors.orange),
            const SizedBox(width: 8),
            _SummaryCard(
                label: 'Savings Rate',
                value:
                    '${(savingsRate * 100).toStringAsFixed(1)}%',
                color: savingsRate >= 0.2 ? Colors.green : Colors.orange),
          ]),
          const SizedBox(height: 16),

          // 12-month income vs expense bar chart
          const Text('Income vs Expense (12 months)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _IncomeExpenseBarChart(
                income: incomePerMonth,
                expense: expensePerMonth,
                labels: labels),
          ),
          const SizedBox(height: 16),

          // Net savings line chart
          const Text('Monthly Net Savings',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: _SavingsLineChart(savings: savingsPerMonth),
          ),
          const SizedBox(height: 16),

          // Monthly table
          const Text('Monthly Summary',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2.5),
              2: FlexColumnWidth(2.5),
              3: FlexColumnWidth(2.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Text('Month',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Text('Income',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                        textAlign: TextAlign.right),
                  ),
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Text('Expense',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red),
                        textAlign: TextAlign.right),
                  ),
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Text('Net',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
              for (int i = 0; i < 12; i++)
                TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Text(labels[i], textAlign: TextAlign.center),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Text(fmt.format(incomePerMonth[i]),
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.green)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Text(fmt.format(expensePerMonth[i]),
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.red)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Text(
                      fmt.format(savingsPerMonth[i]),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: savingsPerMonth[i] >= 0
                              ? Colors.blue
                              : Colors.orange),
                    ),
                  ),
                ]),
            ],
          ),
          const SizedBox(height: 16),

          // Top expense categories
          if (categoryTotals.isNotEmpty) ...[
            const Text('Top Expense Categories',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._topCategories(categoryTotals, fmt, displayCurrency),
          ],
        ],
      ),
    );
  }

  List<Widget> _topCategories(
      Map<String, double> totals, NumberFormat fmt, String currency) {
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final maxVal = top.isNotEmpty ? top.first.value : 1.0;
    return top.map((e) {
      final fraction = maxVal > 0 ? e.value / maxVal : 0.0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
              width: 100,
              child: Text(e.key,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 12,
              backgroundColor: Colors.red.withOpacity(0.1),
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text('${fmt.format(e.value)} $currency',
              style: const TextStyle(fontSize: 12)),
        ]),
      );
    }).toList();
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCard(
      {Key? key,
      required this.label,
      required this.value,
      required this.color})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(children: [
            Text(label,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _IncomeExpenseBarChart extends StatelessWidget {
  final List<double> income;
  final List<double> expense;
  final List<String> labels;
  const _IncomeExpenseBarChart(
      {Key? key,
      required this.income,
      required this.expense,
      required this.labels})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxY = [
      ...income,
      ...expense,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxY * 1.15,
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(labels[i],
                    style: const TextStyle(fontSize: 9));
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          income.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                  toY: income[i],
                  color: Colors.green,
                  width: 6,
                  borderRadius: BorderRadius.circular(2)),
              BarChartRodData(
                  toY: expense[i],
                  color: Colors.red,
                  width: 6,
                  borderRadius: BorderRadius.circular(2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavingsLineChart extends StatelessWidget {
  final List<double> savings;
  const _SavingsLineChart({Key? key, required this.savings})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final spots = savings
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    final minY = savings.reduce((a, b) => a < b ? a : b);
    final maxY = savings.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY).abs() * 0.2 + 1;

    return LineChart(
      LineChartData(
        minY: minY - padding,
        maxY: maxY + padding,
        titlesData: const FlTitlesData(
          leftTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.12),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: Colors.grey.withOpacity(0.5),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ],
        ),
      ),
    );
  }
}

// Provider for FX rates keyed by base currency
final fxRatesProvider =
    FutureProvider.family<Map<String, double>, String>((ref, base) {
  return ref.read(fxServiceProvider).getRates(base);
});
