import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class EnvChartCard extends StatelessWidget {
  const EnvChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tren Lingkungan & Konsumsi Energi Hari Ini',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Korelasi tingkat CO₂ rata-rata ruang terhadap load daya\nHVAC (07:00 - 17:00 WIB)',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _buildLegend(AppColors.chartLine, 'Kualitas Udara (ppm)'),
              const SizedBox(width: 12),
              _buildLegend(AppColors.chartLineDash, 'Beban Daya (kW)'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              _buildChartData(),
              duration: const Duration(milliseconds: 400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 2,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  LineChartData _buildChartData() {
    final spots1 = [
      FlSpot(0, 420),
      FlSpot(1, 430),
      FlSpot(2, 445),
      FlSpot(3, 460),
      FlSpot(4, 490),
      FlSpot(5, 510),
      FlSpot(6, 540),
      FlSpot(7, 525),
      FlSpot(8, 515),
      FlSpot(9, 500),
      FlSpot(10, 490),
    ];

    final spots2 = [
      FlSpot(0, 380),
      FlSpot(1, 390),
      FlSpot(2, 395),
      FlSpot(3, 405),
      FlSpot(4, 420),
      FlSpot(5, 430),
      FlSpot(6, 445),
      FlSpot(7, 440),
      FlSpot(8, 435),
      FlSpot(9, 425),
      FlSpot(10, 415),
    ];

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 40,
        getDrawingHorizontalLine: (val) => FlLine(
          color: AppColors.chartGrid,
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              const labels = ['07:00', '08:00', '09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00'];
              final index = value.toInt();
              if (index < 0 || index >= labels.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  labels[index],
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 10,
      minY: 340,
      maxY: 580,
      lineBarsData: [
        LineChartBarData(
          spots: spots1,
          isCurved: true,
          color: AppColors.chartLine,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.primary.withValues(alpha: 0.06),
          ),
        ),
        LineChartBarData(
          spots: spots2,
          isCurved: true,
          color: AppColors.chartLineDash,
          barWidth: 1.5,
          dashArray: [5, 5],
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      extraLinesData: ExtraLinesData(
        verticalLines: [
          VerticalLine(
            x: 5.5,
            color: AppColors.primary.withValues(alpha: 0.6),
            strokeWidth: 1,
            dashArray: [4, 4],
            label: VerticalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              labelResolver: (line) => '12:30 WIB\n540 ppm · Stabil',
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
