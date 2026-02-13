import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AdminPaymentMethodChart extends StatelessWidget {

  const AdminPaymentMethodChart({super.key, required this.data});
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.purple,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.red,
    ];

    int i = 0;

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          sections: data.entries.map((e) {
            final c = colors[i++ % colors.length];
            return PieChartSectionData(
              value: e.value.toDouble(),
              title: '${e.key}\n${e.value}',
              color: c,
              radius: 70,
              titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
            );
          }).toList(),
        ),
      ),
    );
  }
}
