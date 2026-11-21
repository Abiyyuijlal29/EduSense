import 'package:flutter/material.dart';
import '../models/mahasiswa.dart';
import '../services/presensi_service.dart';

class StudentCard extends StatelessWidget {
  final MahasiswaPresensi student;
  final VoidCallback onTap;
  final VoidCallback? onSakitPressed;
  final VoidCallback? onDispensasiPressed;

  const StudentCard({
    super.key,
    required this.student,
    required this.onTap,
    this.onSakitPressed,
    this.onDispensasiPressed,
  });

  /// Cek apakah mahasiswa memenuhi kriteria Valid Tertidur (Akumulasi >= 10 menit)
  bool get _isValidSleep =>
      student.status == 'Tertidur' ||
      (student.isSleepingNow &&
          PresensiService.isSleepValid(student.currentSleepMinutes));

  Color _getBorderColor() {
    if (_isValidSleep) {
      return const Color(0xFFF87171); // Merah tegas
    }

    switch (student.status) {
      case 'Hadir':
        return const Color(0xFF86EFAC); // Hijau lembut
      case 'Terlambat':
        return const Color(0xFFFCD34D); // Kuning/Amber
      case 'Sakit':
        return const Color(0xFF93C5FD); // Biru
      case 'Izin':
        return const Color(0xFFD8B4FE); // Ungu
      case 'Alpha':
      default:
        return const Color(0xFFE2E8F0); // Abu-abu
    }
  }

  Color _getBackgroundColor() {
    if (_isValidSleep) {
      return const Color(0xFFFEF2F2); // Latar merah lembut
    }

    switch (student.status) {
      case 'Hadir':
        return const Color(0xFFF0FDF4);
      case 'Terlambat':
        return const Color(0xFFFFFBEB);
      case 'Sakit':
        return const Color(0xFFEFF6FF);
      case 'Izin':
        return const Color(0xFFFAF5FF);
      case 'Alpha':
      default:
        return Colors.white;
    }
  }

  Color _getBadgeColor() {
    if (_isValidSleep) {
      return const Color(0xFFFEE2E2);
    }

    switch (student.status) {
      case 'Hadir':
        return const Color(0xFFDCFCE7);
      case 'Terlambat':
        return const Color(0xFFFEF3C7);
      case 'Sakit':
        return const Color(0xFFDBEAFE);
      case 'Izin':
        return const Color(0xFFF3E8FF);
      case 'Alpha':
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getBadgeTextColor() {
    if (_isValidSleep) {
      return const Color(0xFFB91C1C);
    }

    switch (student.status) {
      case 'Hadir':
        return const Color(0xFF15803D);
      case 'Terlambat':
        return const Color(0xFFB45309);
      case 'Sakit':
        return const Color(0xFF1D4ED8);
      case 'Izin':
        return const Color(0xFF7E22CE);
      case 'Alpha':
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getStatusIcon() {
    if (_isValidSleep) {
      return Icons.warning_amber_rounded;
    }

    switch (student.status) {
      case 'Hadir':
        return Icons.check_circle_rounded;
      case 'Terlambat':
        return Icons.access_time_filled_rounded;
      case 'Sakit':
        return Icons.local_hospital_rounded;
      case 'Izin':
        return Icons.assignment_turned_in_rounded;
      case 'Alpha':
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getDisplayStatus() {
    if (_isValidSleep) {
      return 'Tertidur';
    }
    return student.status;
  }

  Widget _buildAvatar() {
    final hasCapture = student.lastCaptureUrl != null &&
        student.lastCaptureUrl!.isNotEmpty &&
        student.lastCaptureUrl!.startsWith('http');

    if (hasCapture) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 58,
          height: 58,
          color: const Color(0xFFE2E8F0),
          child: Image.network(
            student.lastCaptureUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildInitialsAvatar();
            },
          ),
        ),
      );
    }
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    final initial =
        student.nama.isNotEmpty ? student.nama[0].toUpperCase() : 'M';
    final isTertidur = _isValidSleep;

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color:
            isTertidur ? const Color(0xFFFEE2E2) : const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTertidur
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFC7D2FE),
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isTertidur
                ? const Color(0xFFDC2626)
                : const Color(0xFF1E3A8A),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAlpha = student.status == 'Alpha';
    final isTertidur = _isValidSleep;
    final isTerlambat = student.status == 'Terlambat';
    final isSleepRunningUnder10Min =
        student.isSleepingNow && !PresensiService.isSleepValid(student.currentSleepMinutes);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getBorderColor(),
          width: isTertidur ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isTertidur
                ? Colors.red.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isTertidur ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Foto Capture Terakhir atau Inisial
                    _buildAvatar(),
                    const SizedBox(width: 14),

                    // Informasi Mahasiswa & Status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  student.nama,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Badge Status
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: _getBadgeColor(),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getBorderColor(),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getStatusIcon(),
                                      size: 13,
                                      color: _getBadgeTextColor(),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getDisplayStatus(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _getBadgeTextColor(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'NIM: ${student.nim}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Keterangan Jam & Akumulasi Tidur
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              // Jam Kejadian Terakhir / Datang Aktual
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.schedule_rounded,
                                      size: 13, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    isTerlambat
                                        ? 'Datang Aktual: ${student.jamKehadiran}'
                                        : 'Terakhir: ${student.jamKejadianTerakhir}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF475569),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),

                              // Akumulasi Tidur Hari Ini
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: student.totalTidurMenitHariIni > 0
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bedtime_outlined,
                                      size: 11,
                                      color: student.totalTidurMenitHariIni > 0
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Tidur: ${student.totalTidurMenitHariIni}m',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: student.totalTidurMenitHariIni > 0
                                            ? const Color(0xFFB91C1C)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Timer Durasi Tidur Berjalan Saat Sedang Tidur Tapi Di Bawah 10 Menit (Card Normal)
                if (isSleepRunningUnder10Min) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 14, color: Color(0xFFB45309)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Durasi tidur berjalan: ${student.runningSleepTimerFormatted} (< 10m: Status tetap normal)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Peringatan Khusus Jika Valid Tertidur (Akumulasi >= 10 Menit, Card Merah)
                if (isTertidur) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'VALID TERTIDUR: ${student.runningSleepTimerFormatted} (>= 10 Menit). Capture CCTV tersimpan di riwayat.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF991B1B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Tombol Khusus Override Mahasiswa Alpha (Poin D)
                if (isAlpha) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Override Manual:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const Spacer(),
                      // Tombol Sakit (Biru)
                      OutlinedButton.icon(
                        onPressed: onSakitPressed,
                        icon: const Icon(Icons.medication_outlined, size: 14),
                        label: const Text('Sakit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1D4ED8),
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                          backgroundColor: const Color(0xFFEFF6FF),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tombol Dispensasi / Izin (Ungu)
                      OutlinedButton.icon(
                        onPressed: onDispensasiPressed,
                        icon: const Icon(Icons.assignment_outlined, size: 14),
                        label: const Text('Dispensasi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7E22CE),
                          side: const BorderSide(color: Color(0xFFD8B4FE)),
                          backgroundColor: const Color(0xFFFAF5FF),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
