import 'package:flutter/material.dart';
import '../models/mahasiswa.dart';
import '../models/attendance_history.dart';
import '../services/presensi_service.dart';
import '../widgets/history_table.dart';
import '../widgets/upload_evidence_sheet.dart';
import '../widgets/pdf_report_dialog.dart';

class StudentDetailHistoryScreen extends StatefulWidget {
  final MahasiswaPresensi student;

  const StudentDetailHistoryScreen({
    super.key,
    required this.student,
  });

  @override
  State<StudentDetailHistoryScreen> createState() =>
      _StudentDetailHistoryScreenState();
}

class _StudentDetailHistoryScreenState
    extends State<StudentDetailHistoryScreen> {
  late MahasiswaPresensi _currentStudent;
  List<AttendanceHistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentStudent = widget.student;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final list = await PresensiService()
        .fetchStudentHistory(_currentStudent.nim);
    if (!mounted) return;
    setState(() {
      _history = list;
      _isLoading = false;
    });
  }

  void _handleChangeEvidence() async {
    final result = await UploadEvidenceSheet.show(
      context,
      student: _currentStudent,
      targetStatus: _currentStudent.status,
    );
    if (result == true) {
      final updated = PresensiService()
          .currentStudents
          .firstWhere((s) => s.nim == _currentStudent.nim,
              orElse: () => _currentStudent);
      setState(() {
        _currentStudent = updated;
      });
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalTidurMenit = _currentStudent.totalTidurMenitHariIni;
    final totalTidurJam = totalTidurMenit ~/ 60;
    final totalTidurSisaMenit = totalTidurMenit % 60;
    final sleepEventsCount =
        _history.where((item) => item.type == 'tidur').length;

    final isManualDoc = _currentStudent.isSakit || _currentStudent.isIzin;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profil & Riwayat Mahasiswa',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined,
                color: Color(0xFFDC2626)),
            tooltip: 'Unduh Laporan PDF',
            onPressed: () {
              PdfReportDialog.show(context, student: _currentStudent);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Profil Mahasiswa Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar / Capture
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: _currentStudent.lastCaptureUrl != null &&
                                  _currentStudent.lastCaptureUrl!.isNotEmpty &&
                                  _currentStudent.lastCaptureUrl!.startsWith('http')
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    _currentStudent.lastCaptureUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    _currentStudent.nama.isNotEmpty
                                        ? _currentStudent.nama[0].toUpperCase()
                                        : 'M',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),

                        // Nama, NIM, Status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentStudent.nama,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'NIM: ${_currentStudent.nim}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _currentStudent.status,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ),
                                  if (isManualDoc) ...[
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: _handleChangeEvidence,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border:
                                              Border.all(color: Colors.white54),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_rounded,
                                                size: 11, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text(
                                              'Ganti Bukti',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Rekap Tidur Harian & Grafik Batang (Poin G)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.insights_rounded,
                              size: 18,
                              color: Color(0xFF1E3A8A),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Rekap Tidur & Perilaku Hari Ini',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const Spacer(),
                            // Tombol Unduh Laporan PDF
                            TextButton.icon(
                              onPressed: () {
                                PdfReportDialog.show(context,
                                    student: _currentStudent);
                              },
                              icon: const Icon(Icons.picture_as_pdf_rounded,
                                  size: 14, color: Color(0xFFDC2626)),
                              label: const Text(
                                'Unduh PDF',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Stats Summary Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildRecapCard(
                                title: 'Akumulasi Tidur',
                                value: totalTidurJam > 0
                                    ? '$totalTidurJam jam $totalTidurSisaMenit m'
                                    : '$totalTidurSisaMenit menit',
                                icon: Icons.bedtime_outlined,
                                isWarning: totalTidurMenit > 0,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildRecapCard(
                                title: 'Jumlah Kejadian',
                                value: '$sleepEventsCount Kali',
                                icon: Icons.alarm_outlined,
                                isWarning: sleepEventsCount > 0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Grafik Batang Sederhana (Visual Bar Recap)
                        const Text(
                          'Tingkat Menunduk per Sesi (Ambang Batas 10 Menit):',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSimpleBarChart(totalTidurMenit),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Tabel Riwayat Capture (Poin E)
                  Row(
                    children: [
                      const Icon(Icons.history_rounded,
                          size: 18, color: Color(0xFF1E3A8A)),
                      const SizedBox(width: 6),
                      const Text(
                        'Riwayat Capture & Dokumen',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        onPressed: _loadHistory,
                        tooltip: 'Muat ulang riwayat',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  HistoryTable(
                    history: _history,
                    studentName: _currentStudent.nama,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildRecapCard({
    required String title,
    required String value,
    required IconData icon,
    required bool isWarning,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWarning ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isWarning
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: isWarning
                      ? const Color(0xFF991B1B)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isWarning
                  ? const Color(0xFFB91C1C)
                  : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBarChart(int totalMinutes) {
    // 0 - 30 menit scale
    final double percent = (totalMinutes / 30.0).clamp(0.0, 1.0);
    final isDanger = totalMinutes >= 10;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 12,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(
              isDanger ? const Color(0xFFDC2626) : const Color(0xFF10B981),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('0m (Fokus)',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            Text(
              'Ambang Batas Peringatan: 10m',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDanger ? const Color(0xFFDC2626) : const Color(0xFF64748B),
              ),
            ),
            const Text('30m+ (Kritis)',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
      ],
    );
  }
}

