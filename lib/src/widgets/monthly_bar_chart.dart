import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MonthlyBarChart extends StatelessWidget {
  final List<double> income; // per-month income values
  final List<double> expense; // per-month expense values
  final List<String> labels; // month labels

  const MonthlyBarChart({Key? key, required this.income, required this.expense, required this.labels}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxVal = <double>[...income, ...expense].fold(0.0, (p, e) => e > p ? e : p);
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxVal * 1.2).clamp(10.0, double.infinity),
          barGroups: List.generate(labels.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: expense[i], color: Colors.redAccent, width: 8),
              BarChartRodData(toY: income[i], color: Colors.greenAccent, width: 8),
            ], barsSpace: 4);
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(labels[v.toInt()], style: const TextStyle(fontSize: 10)),
                ),
              ),
            ),
          ),
          gridData: FlGridData(show: true),
        ),
      ),
    );
  }
}
