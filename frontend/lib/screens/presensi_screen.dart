import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mahasiswa.dart';
import '../services/presensi_service.dart';
import '../widgets/student_card.dart';
import '../widgets/upload_evidence_sheet.dart';
import 'student_detail_history_screen.dart';
import 'registrasi_wajah_screen.dart';

class PresensiScreen extends StatefulWidget {
  const PresensiScreen({super.key});

  @override
  State<PresensiScreen> createState() => _PresensiScreenState();
}

class _PresensiScreenState extends State<PresensiScreen> {
  final PresensiService _presensiService = PresensiService();
  final TextEditingController _searchController = TextEditingController();

  List<MahasiswaPresensi> _students = [];
  List<MahasiswaPresensi> _filteredStudents = [];
  bool _isLoading = true;
  StreamSubscription<List<MahasiswaPresensi>>? _subscription;

  @override
  void initState() {
    super.initState();
    _presensiService.init();

    // Dapatkan data awal dari cache atau Firebase
    _students = _presensiService.currentStudents;
    _filteredStudents = _filterStudents(_students);
    _isLoading = _students.isEmpty;

    // Stream listener real-time tersambung ke Firebase (Poin B & H)
    _subscription = _presensiService.studentsStream.listen((data) {
      if (!mounted) return;
      setState(() {
        _students = data;
        _filteredStudents = _filterStudents(data);
        _isLoading = false;
      });
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredStudents = _filterStudents(_students);
    });
  }

  List<MahasiswaPresensi> _filterStudents(List<MahasiswaPresensi> source) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return List.from(source);
    return source.where((m) {
      return m.nama.toLowerCase().contains(q) ||
          m.nim.toLowerCase().contains(q) ||
          m.status.toLowerCase().contains(q);
    }).toList();
  }

  // ===========================================================================
  // PENANGANAN KONFIRMASI OVERRIDE SISTEM VS DOSEN (POIN H)
  // ===========================================================================
  Future<void> _handleSimulateDetection(String nim, {bool isLate = false}) async {
    final student = _students.firstWhere((s) => s.nim == nim,
        orElse: () => _students.first);

    final capturedAt = isLate
        ? DateTime.now().subtract(const Duration(minutes: 5)) // Terlambat
        : DateTime.now();

    // Jika mahasiswa sebelumnya berstatus Sakit/Izin (Manual Override),
    // minta konfirmasi dosen terlebih dahulu (Poin H)
    if (student.isManualOverride) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.help_outline_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Konfirmasi Kehadiran',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Mahasiswa ${student.nama} (${student.nim}) sebelumnya berstatus ${student.status}.\n\n'
            'Sistem AI kamera mendeteksi wajah di kelas. Apakah Anda ingin memperbarui statusnya menjadi ${isLate ? "Terlambat" : "Hadir"}?',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Pertahankan Status'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Perbarui ke Hadir'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    await _presensiService.handleAutomaticPresence(
      studentId: nim,
      capturedAt: capturedAt,
      imageUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      forceOverrideIfManual: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Presensi ${student.nama} otomatis terdeteksi & diperbarui.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openUploadSheet(MahasiswaPresensi student, String status) async {
    final res = await UploadEvidenceSheet.show(
      context,
      student: student,
      targetStatus: status,
    );
    if (res == true && mounted) {
      // Data sudah otomatis sinkron via listener Firebase
    }
  }

  void _openDetail(MahasiswaPresensi student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailHistoryScreen(student: student),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalTerdaftar = _students.length;
    final totalHadir = _students.where((m) => m.isHadir).length;
    final totalTerlambat = _students.where((m) => m.isTerlambat).length;
    final totalSakit = _students.where((m) => m.isSakit).length;
    final totalIzin = _students.where((m) => m.isIzin).length;
    final totalAlpha = _students.where((m) => m.isAlpha).length;
    final totalTertidur = _students.where((m) => m.isTertidur).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Presensi & Profil Mahasiswa',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E3A8A)),
            tooltip: 'Sinkronisasi Ulang',
            onPressed: () {
              setState(() => _isLoading = true);
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted) {
                  setState(() {
                    _students = _presensiService.currentStudents;
                    _filteredStudents = _filterStudents(_students);
                    _isLoading = false;
                  });
                }
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Registrasi Wajah'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RegistrasiWajahScreen(),
            ),
          );
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _students = _presensiService.currentStudents;
                  _filteredStudents = _filterStudents(_students);
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  children: [
                    // Kartu Statistik Ringkasan Presensi
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('Terdaftar', '$totalTerdaftar Mhs'),
                              Container(width: 1, height: 32, color: Colors.white24),
                              _buildStatItem('Hadir', '$totalHadir Mhs'),
                              Container(width: 1, height: 32, color: Colors.white24),
                              _buildStatItem('Terlambat', '$totalTerlambat Mhs'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Colors.white24),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('Sakit/Izin', '${totalSakit + totalIzin} Mhs'),
                              Container(width: 1, height: 28, color: Colors.white24),
                              _buildStatItem('Alpha', '$totalAlpha Mhs'),
                              Container(width: 1, height: 28, color: Colors.white24),
                              _buildStatItem('Tertidur', '$totalTertidur Mhs',
                                  isAlert: totalTertidur > 0),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Kotak Pencarian Real-time
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari mahasiswa berdasarkan nama, NIM, atau status...',
                        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF64748B), size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Simulation Bar untuk Pengujian Alur C, D, F
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text(
                            'Simulasi Event:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildSimButton(
                            '✅ Kamera Hadir',
                            () {
                              final alpha = _students.firstWhere(
                                (s) => s.isAlpha,
                                orElse: () => _students.first,
                              );
                              _handleSimulateDetection(alpha.nim, isLate: false);
                            },
                          ),
                          const SizedBox(width: 6),
                          _buildSimButton(
                            '⚠️ Kamera Terlambat',
                            () {
                              final student = _students.firstWhere(
                                (s) => s.nim == 'E41242065' || s.isAlpha,
                                orElse: () => _students.last,
                              );
                              _handleSimulateDetection(student.nim, isLate: true);
                            },
                          ),
                          const SizedBox(width: 6),
                          _buildSimButton(
                            '😴 Valid Tidur 10m',
                            () async {
                              final student = _students.firstWhere(
                                (s) => s.isHadir || s.isTerlambat,
                                orElse: () => _students.first,
                              );
                              await _presensiService.recordSleepEvent(
                                studentId: student.nim,
                                imageUrl:
                                    'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=400&q=80',
                                durationMinutes: 10,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Valid Tidur 10m tercatat untuk ${student.nama}. Card berubah merah.'),
                                  backgroundColor: const Color(0xFFDC2626),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          _buildSimButton(
                            '☀️ Bangun',
                            () async {
                              final tidur = _students.firstWhere(
                                (s) => s.isTertidur,
                                orElse: () => _students.first,
                              );
                              await _presensiService.recordWakeUpEvent(
                                  studentId: tidur.nim);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Mahasiswa ${tidur.nama} telah bangun. Card kembali normal.'),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Daftar Card Mahasiswa
                    Expanded(
                      child: _filteredStudents.isEmpty
                          ? const Center(
                              child: Text(
                                'Tidak ada mahasiswa yang sesuai dengan pencarian.',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredStudents.length,
                              itemBuilder: (context, index) {
                                final student = _filteredStudents[index];

                                return StudentCard(
                                  student: student,
                                  onTap: () => _openDetail(student),
                                  onSakitPressed: () =>
                                      _openUploadSheet(student, 'Sakit'),
                                  onDispensasiPressed: () =>
                                      _openUploadSheet(student, 'Izin'),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value, {bool isAlert = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: isAlert ? const Color(0xFFFCA5A5) : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isAlert ? const Color(0xFFFCA5A5) : Colors.white70,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSimButton(String label, VoidCallback onPressed) {
    return ActionChip(
      label: Text(label),
      labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}
