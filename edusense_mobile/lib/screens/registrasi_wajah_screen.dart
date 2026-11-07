import 'package:flutter/material.dart';

class RegistrasiWajahScreen extends StatefulWidget {
  const RegistrasiWajahScreen({super.key});

  @override
  State<RegistrasiWajahScreen> createState() => _RegistrasiWajahScreenState();
}

class _RegistrasiWajahScreenState extends State<RegistrasiWajahScreen> {
  final _nimController = TextEditingController();
  final _namaController = TextEditingController();
  bool _isCapturing = false;
  int _samplesCaptured = 0;
  String? _statusMessage;

  void _startFaceCapture() async {
    final nim = _nimController.text.trim();
    final nama = _namaController.text.trim();

    if (nim.isEmpty || nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Harap lengkapi NIM dan Nama Mahasiswa terlebih dahulu!',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCapturing = true;
      _samplesCaptured = 0;
      _statusMessage = 'Mengarahkan feed CCTV ke area wajah mahasiswa...';
    });

    // Simulasi pengambilan 15 sampel foto wajah dari CCTV
    for (int i = 1; i <= 15; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(() {
        _samplesCaptured = i;
        _statusMessage = 'Mengekstrak fitur wajah: sampel $i dari 15...';
      });
    }

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    setState(() {
      _isCapturing = false;
      _statusMessage =
          '✅ Sukses! 15 sampel wajah untuk $nama ($nim) berhasil disimpan ke folder dataset_absensi.';
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrasi Wajah Berhasil'),
        content: Text(
          'Data wajah $nama ($nim) telah berhasil didaftarkan ke sistem EduSense.\n\nEmbedding wajah kini aktif untuk verifikasi presensi otomatis di CCTV.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Registrasi Mahasiswa Baru',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview Frame CCTV
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    color: const Color(0xFF0F172A),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 44,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Kamera CCTV Ruang Kelas (RTSP Port 554)',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Reticle / Face Target Box
                  Container(
                    width: 130,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isCapturing
                            ? Colors.greenAccent
                            : Colors.white70,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(
                            _isCapturing
                                ? '$_samplesCaptured / 15'
                                : 'Posisikan Wajah',
                            style: TextStyle(
                              color: _isCapturing
                                  ? Colors.greenAccent
                                  : Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_isCapturing)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form Input Mahasiswa
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nimController,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Induk Mahasiswa (NIM)',
                      hintText: 'Contoh: E41249999',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap Mahasiswa',
                      hintText: 'Contoh: Budi Santoso',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),

            // Capture Button
            ElevatedButton.icon(
              onPressed: _isCapturing ? null : _startFaceCapture,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isCapturing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt_rounded),
              label: Text(
                _isCapturing
                    ? 'Sedang Mengambil Sampel...'
                    : 'Ambil 15 Sampel Wajah dari CCTV',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
