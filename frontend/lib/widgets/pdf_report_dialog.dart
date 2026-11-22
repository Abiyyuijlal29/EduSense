import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/mahasiswa.dart';

class PdfReportDialog extends StatelessWidget {
  final MahasiswaPresensi student;
  final String dosenName;
  final String dosenNip;

  const PdfReportDialog({
    super.key,
    required this.student,
    this.dosenName = 'Dr. Ir. Dosen Pengampu, M.Kom.',
    this.dosenNip = '198501012010121001',
  });

  static void show(
    BuildContext context, {
    required MahasiswaPresensi student,
    String dosenName = 'Dr. Ir. Dosen Pengampu, M.Kom.',
    String dosenNip = '198501012010121001',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PdfReportDialog(
        student: student,
        dosenName: dosenName,
        dosenNip: dosenNip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nowFormatted =
        DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now()) + ' WIB';
    final totalTidurJam = student.totalTidurMenitHariIni ~/ 60;
    final totalTidurSisaMenit = student.totalTidurMenitHariIni % 60;
    final durasiTidurFormatted = totalTidurJam > 0
        ? '$totalTidurJam jam $totalTidurSisaMenit menit'
        : '$totalTidurSisaMenit menit';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Modal Top Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded,
                    color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                const Text(
                  'Pratinjau Dokumen Laporan Resmi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Invoice / Report Canvas (A4 Page Look)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Kop Surat / Header Resmi
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.school_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'KEMENTERIAN PENDIDIKAN, KEBUDAYAAN, RISET, DAN TEKNOLOGI',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                'POLITEKNIK NEGERI JEMBER',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'JURUSAN TEKNOLOGI INFORMASI - SMART CLASSROOM AI EDUSENSE',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(thickness: 1.5, color: Color(0xFF0F172A)),
                    const SizedBox(height: 10),

                    // Judul Dokumen & Periode
                    const Center(
                      child: Text(
                        'LAPORAN REKAPITULASI PRESENSI & MONITORING PERILAKU SISWA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Mata Kuliah: Vision AI & IoT • Periode: Semester Ganjil 2026/2027',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Metadata Box (Invoice-style)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMetaRow('Nama Mahasiswa', student.nama),
                                const SizedBox(height: 4),
                                _buildMetaRow('NIM', student.nim),
                                const SizedBox(height: 4),
                                _buildMetaRow('Kelas / Ruang', 'TI-2F / Lab Vision AI'),
                              ],
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 50,
                              color: const Color(0xFFCBD5E1)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMetaRow('Status Presensi', student.status),
                                const SizedBox(height: 4),
                                _buildMetaRow('Jam Masuk', student.jamKehadiran),
                                const SizedBox(height: 4),
                                _buildMetaRow('Waktu Cetak', nowFormatted),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tabel Rekapitulasi Riwayat
                    const Text(
                      'Tabel Rekapitulasi Sesi & Kejadian Hari Ini:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Table(
                      border: TableBorder.all(
                        color: const Color(0xFFCBD5E1),
                        width: 0.8,
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.4),
                        3: FlexColumnWidth(1.2),
                      },
                      children: [
                        // Header
                        TableRow(
                          decoration:
                              const BoxDecoration(color: Color(0xFFE2E8F0)),
                          children: [
                            _buildTableCell('Tanggal & Jam', isHeader: true),
                            _buildTableCell('Keterangan', isHeader: true),
                            _buildTableCell('Akumulasi Tidur', isHeader: true),
                            _buildTableCell('Status Bukti', isHeader: true),
                          ],
                        ),
                        // Data Row Hari Ini
                        TableRow(
                          children: [
                            _buildTableCell(
                                '${DateFormat('dd/MM/yyyy').format(DateTime.now())}\n${student.jamKehadiran}'),
                            _buildTableCell(student.status),
                            _buildTableCell(student.totalTidurMenitHariIni > 0
                                ? '$durasiTidurFormatted\n(1 Sesi Valid)'
                                : '0 Menit (Tertib)'),
                            _buildTableCell(student.lastCaptureUrl != null
                                ? 'Tersimpan\n(CCTV Capture)'
                                : 'Belum Ada Bukti'),
                          ],
                        ),
                        // Historical Rows dari riwayat
                        ...student.riwayat.take(3).map((item) {
                          return TableRow(
                            children: [
                              _buildTableCell(DateFormat('dd/MM/yyyy\nHH:mm:ss')
                                  .format(item.timestamp)),
                              _buildTableCell(item.typeLabel),
                              _buildTableCell(item.durationMinutes != null
                                  ? '${item.durationMinutes} Menit'
                                  : '-'),
                              _buildTableCell(item.evidenceUrl.isNotEmpty
                                  ? 'Terverifikasi\n(${item.evidenceType})'
                                  : '-'),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Summary Box (Total Akumulasi)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Akumulasi Tidur Hari Ini:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              Text(
                                durasiTidurFormatted,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Indeks Kedisiplinan & Perhatian:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              Text(
                                student.totalTidurMenitHariIni > 0
                                    ? 'Cukup (Perlu Pemantauan)'
                                    : 'Sangat Baik (100%)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: student.totalTidurMenitHariIni > 0
                                      ? Colors.orange.shade800
                                      : Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Signature Block
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sistem Otomatis EduSense',
                                style: TextStyle(
                                    fontSize: 9.5, color: Color(0xFF64748B))),
                            SizedBox(height: 30),
                            Text('Vision AI Edge Engine v2.0',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A))),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jember, ${DateFormat('dd MMMM yyyy').format(DateTime.now())}',
                              style: const TextStyle(
                                  fontSize: 9.5, color: Color(0xFF64748B)),
                            ),
                            const Text('Dosen Pengampu Kelas,',
                                style: TextStyle(
                                    fontSize: 9.5, color: Color(0xFF64748B))),
                            const SizedBox(height: 28),
                            Text(
                              dosenName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text('NIP: $dosenNip',
                                style: const TextStyle(
                                    fontSize: 9, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Laporan PDF dibagikan via sistem.'),
                          backgroundColor: Color(0xFF1E3A8A),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Bagikan Laporan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Laporan PDF ${student.nim}_${student.nama}.pdf berhasil diunduh ke folder Download.',
                          ),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Simpan PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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

  Widget _buildMetaRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 10 : 9.5,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? const Color(0xFF1E293B) : const Color(0xFF334155),
        ),
        textAlign: isHeader ? TextAlign.center : TextAlign.left,
      ),
    );
  }
}

