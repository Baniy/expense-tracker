import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CategoryPieChart extends StatelessWidget {
  final Map<String, double> data; // category label -> amount

  const CategoryPieChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final total = entries.fold(0.0, (p, e) => p + e.value);
    return SizedBox(
      height: 220,
      child: PieChart(PieChartData(
        sections: List.generate(entries.length, (i) {
          final e = entries[i];
          final value = e.value;
          final percent = total == 0 ? 0.0 : (value / total) * 100;
          final color = Colors.primaries[i % Colors.primaries.length];
          return PieChartSectionData(
            value: value,
            title: '${percent.toStringAsFixed(0)}%',
            color: color,
            radius: 60,
            titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
          );
        }),
        sectionsSpace: 2,
        centerSpaceRadius: 32,
      )),
    );
  }
}
