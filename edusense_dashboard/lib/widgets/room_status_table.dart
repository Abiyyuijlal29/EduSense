import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RoomStatusTable extends StatelessWidget {
  const RoomStatusTable({super.key});

  static final List<_RoomData> _rooms = [
    _RoomData(
      number: '401',
      name: 'Lab Komputasi',
      code: 'R.401',
      session: 'Kecerdasan Buatan (Semester 6)',
      status: 'Optimal',
      statusColor: AppColors.success,
      temp: '22.4°C',
      co2: '480 ppm',
      co2Status: 'ok',
      attendance: '32 / 35 Kursi',
      focus: 0.91,
    ),
    _RoomData(
      number: '402',
      name: 'Ruang Teori',
      code: 'R.402',
      session: 'Arsitektur Jaringan (Semester 4)',
      status: 'Optimal',
      statusColor: AppColors.success,
      temp: '22.8°C',
      co2: '505 ppm',
      co2Status: 'ok',
      attendance: '40 / 40 Kursi',
      focus: 0.86,
    ),
    _RoomData(
      number: '403',
      name: 'Auditorium Mini',
      code: 'R.403',
      session: 'Seminar Riset Internet of Things',
      status: 'Autotuning',
      statusColor: AppColors.warning,
      temp: '23.1°C',
      co2: '535 ppm',
      co2Status: 'warn',
      attendance: '58 / 60 Kursi',
      focus: 0.84,
    ),
    _RoomData(
      number: '404',
      name: 'Studio Desain & HW',
      code: 'R.404',
      session: 'Workshop Mikrokontroler Lanjut',
      status: 'Optimal',
      statusColor: AppColors.success,
      temp: '22.0°C',
      co2: '465 ppm',
      co2Status: 'ok',
      attendance: '24 / 25 Kursi',
      focus: 0.88,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Ruang Kelas Aktif',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Telemetri real-time 4 ruang teratas di Gedung Sains & Teknologi',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _buildLegendDot(AppColors.success, 'Normal'),
                const SizedBox(width: 12),
                _buildLegendDot(AppColors.warning, 'Penyesuaian AI'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Table Header
          Container(
            color: AppColors.contentBg,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: const Row(
              children: [
                SizedBox(width: 200, child: _TableHeaderText('RUANG & SESI')),
                SizedBox(width: 110, child: _TableHeaderText('STATUS IOT')),
                SizedBox(width: 90, child: _TableHeaderText('SUHU RUANG')),
                SizedBox(
                  width: 110,
                  child: _TableHeaderText('KONSENTRASI CO₂'),
                ),
                SizedBox(width: 110, child: _TableHeaderText('KEHADIRAN (AI)')),
                Expanded(child: _TableHeaderText('FOKUS SISWA')),
                SizedBox(width: 40, child: _TableHeaderText('AKSI')),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rooms.length,
            separatorBuilder: (_, a) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) => _buildRow(_rooms[index]),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 7, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'Pembaruan data otomatis setiap 30 detik melalui MQTT Broker kampus',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Row(
                    children: [
                      Text(
                        'Lihat Semua 12 Ruang Kelas',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildRow(_RoomData room) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Room Number
          SizedBox(
            width: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      room.number,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${room.name} ${room.code}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      room.session,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status
          SizedBox(
            width: 110,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: room.statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: room.statusColor.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 6, color: room.statusColor),
                  const SizedBox(width: 4),
                  Text(
                    room.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: room.statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Temp
          SizedBox(
            width: 90,
            child: Text(
              room.temp,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // CO2
          SizedBox(
            width: 110,
            child: Row(
              children: [
                Text(
                  room.co2,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  room.co2Status == 'ok' ? Icons.check : Icons.expand_more,
                  size: 14,
                  color: room.co2Status == 'ok'
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ),
          ),

          // Attendance
          SizedBox(
            width: 110,
            child: Text(
              room.attendance,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Focus Bar
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: room.focus,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(room.focus * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Action Arrow
          SizedBox(
            width: 40,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderText extends StatelessWidget {
  final String text;
  const _TableHeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _RoomData {
  final String number;
  final String name;
  final String code;
  final String session;
  final String status;
  final Color statusColor;
  final String temp;
  final String co2;
  final String co2Status;
  final String attendance;
  final double focus;

  _RoomData({
    required this.number,
    required this.name,
    required this.code,
    required this.session,
    required this.status,
    required this.statusColor,
    required this.temp,
    required this.co2,
    required this.co2Status,
    required this.attendance,
    required this.focus,
  });
}
