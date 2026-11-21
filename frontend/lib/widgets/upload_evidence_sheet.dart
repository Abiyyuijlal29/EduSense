import 'dart:math';
import 'package:flutter/material.dart';
import '../models/mahasiswa.dart';
import '../services/presensi_service.dart';

class UploadEvidenceSheet extends StatefulWidget {
  final MahasiswaPresensi student;
  final String targetStatus; // 'Sakit' atau 'Izin'
  final String dosenIdentifier;

  const UploadEvidenceSheet({
    super.key,
    required this.student,
    required this.targetStatus,
    this.dosenIdentifier = 'Dosen Pengampu (NIP 198501012010121001)',
  });

  static Future<bool?> show(
    BuildContext context, {
    required MahasiswaPresensi student,
    required String targetStatus,
    String dosenIdentifier = 'Dosen Pengampu',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UploadEvidenceSheet(
        student: student,
        targetStatus: targetStatus,
        dosenIdentifier: dosenIdentifier,
      ),
    );
  }

  @override
  State<UploadEvidenceSheet> createState() => _UploadEvidenceSheetState();
}

class _UploadEvidenceSheetState extends State<UploadEvidenceSheet> {
  final _noteController = TextEditingController();

  String? _selectedFileName;
  String? _selectedFileType; // 'JPG', 'PNG', 'PDF'
  double? _fileSizeMb;
  String? _previewUrl;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _pickFromSource(String source) {
    setState(() {
      _errorMessage = null;
    });

    // Simulasi pemilihan file responsif dan aman multiplatform
    final random = Random();
    if (source == 'camera') {
      _selectedFileName = 'foto_surat_${DateTime.now().millisecondsSinceEpoch}.jpg';
      _selectedFileType = 'JPG';
      _fileSizeMb = (1.2 + random.nextDouble() * 1.5); // ~1.5 - 2.7 MB
      _previewUrl = 'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80';
    } else if (source == 'gallery') {
      _selectedFileName = 'scan_dokumen_${widget.student.nim}.png';
      _selectedFileType = 'PNG';
      _fileSizeMb = (0.8 + random.nextDouble() * 2.1); // ~1 - 3 MB
      _previewUrl = 'https://images.unsplash.com/photo-1586281380349-632531db7ed4?auto=format&fit=crop&w=600&q=80';
    } else if (source == 'pdf') {
      _selectedFileName = 'surat_${widget.targetStatus.toLowerCase()}_${widget.student.nim}.pdf';
      _selectedFileType = 'PDF';
      _fileSizeMb = (1.1 + random.nextDouble() * 1.8); // ~1.5 MB
      _previewUrl = null;
    }

    // Validasi Ukuran Maksimal 5 MB
    if (_fileSizeMb != null && _fileSizeMb! > 5.0) {
      setState(() {
        _errorMessage = 'Ukuran file (${_fileSizeMb!.toStringAsFixed(1)} MB) melebihi batas maksimal 5 MB.';
      });
    } else {
      setState(() {});
    }
  }

  bool get _canSubmit {
    return _selectedFileName != null &&
        _fileSizeMb != null &&
        _fileSizeMb! <= 5.0 &&
        !_isLoading;
  }

  Future<void> _handleSave() async {
    if (!_canSubmit) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final evidenceUrl = _previewUrl ??
          'https://placehold.co/600x800/1e3a8a/ffffff.png?text=Surat+${widget.targetStatus}+${widget.student.nim}.pdf';

      final success = await PresensiService().overrideStatusWithEvidence(
        studentId: widget.student.nim,
        status: widget.targetStatus,
        evidenceUrl: evidenceUrl,
        evidenceType: 'document',
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : 'Surat ${widget.targetStatus} resmi terverifikasi dosen',
        dosenNameOrNip: widget.dosenIdentifier,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status ${widget.student.nama} berhasil diubah ke ${widget.targetStatus}.',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Gagal menyimpan status ke server/Firebase.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSakit = widget.targetStatus == 'Sakit';
    final titleDoc = isSakit ? 'Surat Keterangan Dokter' : 'Surat Dispensasi / Izin Kegiatan';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSakit
                        ? const Color(0xFFDBEAFE)
                        : const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSakit
                        ? Icons.local_hospital_rounded
                        : Icons.assignment_rounded,
                    color: isSakit
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF7E22CE),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unggah Bukti: ${widget.targetStatus}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Wajib sertakan $titleDoc',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info Mahasiswa
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.student.nama,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'NIM: ${widget.student.nim} • Status Awal: ${widget.student.status}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pilihan Sumber File
            const Text(
              'Pilih Sumber Dokumen Bukti (Maks. 5 MB):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSourceButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Kamera',
                    onTap: () => _pickFromSource('camera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSourceButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Galeri',
                    onTap: () => _pickFromSource('gallery'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSourceButton(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'File PDF',
                    onTap: () => _pickFromSource('pdf'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preview File Terpilih
            if (_selectedFileName != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedFileType == 'PDF'
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _selectedFileType == 'PDF'
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                        color: _selectedFileType == 'PDF'
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF1E3A8A),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFileName!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Format: $_selectedFileType • Ukuran: ${_fileSizeMb!.toStringAsFixed(1)} MB',
                            style: TextStyle(
                              fontSize: 11,
                              color: _fileSizeMb! > 5.0
                                  ? Colors.red
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _selectedFileName = null;
                          _selectedFileType = null;
                          _fileSizeMb = null;
                          _previewUrl = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Input Kolom Catatan Opsional
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Catatan Dosen (Opsional)',
                hintText: 'Contoh: Izin mengikuti lomba IoT, ada surat pengantar resmi.',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Error Message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Tombol Simpan
            ElevatedButton(
              onPressed: _canSubmit ? _handleSave : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSakit
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF7E22CE),
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Simpan Status & Unggah Bukti',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1E3A8A), size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

