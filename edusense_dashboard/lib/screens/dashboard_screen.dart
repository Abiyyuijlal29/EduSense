import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar_nav.dart';
import '../widgets/top_header.dart';
import '../widgets/stat_card.dart';
import '../widgets/env_chart_card.dart';
import '../widgets/ai_insight_card.dart';
import '../widgets/room_status_table.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.contentBg,
      body: Row(
        children: [
          // Sidebar
          SidebarNav(
            selectedIndex: _selectedNavIndex,
            onItemSelected: (index) => setState(() => _selectedNavIndex = index),
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Header
                const TopHeader(),

                // Page Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page Title Row
                        Row(
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.sensors, size: 13, color: AppColors.primary),
                                    SizedBox(width: 5),
                                    Text(
                                      'TELEMETRI REAL-TIME',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Ringkasan Kampus Cerdas',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Pemantauan terpadu telemetri IoT dan AI vision ruang kelas.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Filter Sensor Button
                            OutlinedButton.icon(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                foregroundColor: AppColors.textSecondary,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.tune, size: 15),
                              label: const Text('Filter Sensor', style: TextStyle(fontSize: 13)),
                            ),
                            const SizedBox(width: 10),
                            // Export Log Button
                            ElevatedButton.icon(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.download_outlined, size: 15),
                              label: const Text('Ekspor Log', style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Stats Cards Row
                        IntrinsicHeight(
                          child: Row(
                            children: [
                              // STATUS RUANG - special with progress ring visual
                              Expanded(
                                child: _buildStatusRuangCard(),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: StatCard(
                                  title: 'KUALITAS UDARA (IAQ)',
                                  value: '512',
                                  subtitle: 'CO₂ Rata-rata',
                                  badge: 'Optimal',
                                  badgeColor: AppColors.success,
                                  icon: Icons.air_outlined,
                                  footerText: null,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: StatCard(
                                  title: 'EFISIENSI HVAC',
                                  value: '94.2%',
                                  subtitle: null,
                                  icon: Icons.ac_unit_outlined,
                                  footerIcon: 'check',
                                  footerText: 'Beban hemat kompresor AI',
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: StatCard(
                                  title: 'ATENSI SISWA',
                                  value: '87%',
                                  subtitle: null,
                                  icon: Icons.remove_red_eye_outlined,
                                  footerIcon: 'trend',
                                  footerText: '+3.4% dari sesi perkuliahan pagi',
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Chart + AI Insight Row
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Chart
                              const Expanded(
                                flex: 3,
                                child: EnvChartCard(),
                              ),
                              const SizedBox(width: 14),
                              // AI Insight
                              const Expanded(
                                flex: 2,
                                child: AiInsightCard(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Room Status Table
                        const RoomStatusTable(),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRuangCard() {
    return Container(
      padding: const EdgeInsets.all(18),
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
              const Text(
                'STATUS RUANG',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: AppColors.success),
                    SizedBox(width: 4),
                    Text(
                      '100% Online',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '12',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const Text(
                ' / 12',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.sensors, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              const Text(
                'Seluruh nodus IoT terhubung aktif',
                style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
