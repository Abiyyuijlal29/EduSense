import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_dosen.dart';
import '../models/iot_state.dart';
import '../models/mahasiswa.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';

// Posisi kotak deteksi di area frame. Koordinat asli belum ada di Firebase,
// jadi kotak ditempatkan pada slot tetap (maksimal 3 deteksi pertama).
class _BoxSlot {
  final double? left;
  final double? right;
  final double top;
  final double width;
  final double height;
  const _BoxSlot({
    this.left,
    this.right,
    required this.top,
    required this.width,
    required this.height,
  });
}

class MonitoringScreen extends StatefulWidget {
  final UserDosen dosen;
  const MonitoringScreen({super.key, required this.dosen});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  bool _isServerOnline = false;
  bool _isLoading = true;
  IoTState? _iotState;
  List<MahasiswaPresensi> _presensiList = [];
  Timer? _timer;

  // [FIREBASE] data monitoring terbaru + langganan real-time
  Map<String, dynamic>? _monitoring;
  StreamSubscription<Map<String, dynamic>?>? _monitoringSub;
  StreamSubscription<IoTState?>? _iotSub;
  StreamSubscription<List<MahasiswaPresensi>>? _presensiSub;

  static const List<_BoxSlot> _slots = [
    _BoxSlot(left: 40, top: 40, width: 95, height: 110),
    _BoxSlot(right: 50, top: 55, width: 105, height: 100),
    _BoxSlot(left: 150, top: 120, width: 90, height: 80),
  ];

  @override
  void initState() {
    super.initState();
    _refreshData();
    // Auto-refresh setiap 5 detik
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshData());

    // [FIREBASE] real-time: perubahan di Firebase langsung muncul tanpa menunggu timer
    try {
      _monitoringSub = FirebaseService().watchLatest('monitoring').listen(
        (data) {
          if (!mounted) return;
          setState(() => _monitoring = data);
        },
        onError: (Object e) {},
      );
      _iotSub = FirebaseService().watchIoT().listen(
        (data) {
          if (!mounted || data == null) return;
          setState(() {
            _iotState = data;
            _isLoading = false;
          });
        },
        onError: (Object e) {},
      );
      _presensiSub = FirebaseService().watchPresensi().listen(
        (data) {
          if (!mounted || data.isEmpty) return;
          setState(() {
            _presensiList = data;
            _isLoading = false;
          });
        },
        onError: (Object e) {},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _monitoringSub?.cancel();
    _iotSub?.cancel();
    _presensiSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final online = await ApiService().checkServerHealth();
    final iot = await ApiService().getIoTStatus();
    final presensi = await ApiService().getPresensi();

    if (mounted) {
      setState(() {
        _isServerOnline = online;
        _iotState = iot;
        _presensiList = presensi;
        _isLoading = false;
      });
    }
  }

  // [FIREBASE] daftar deteksi dari monitoring/<sesi>/detail_deteksi
  List<Map<String, dynamic>> _deteksiList() {
    final raw = _monitoring?['detail_deteksi'];
    Iterable<dynamic> items = const [];
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      items = raw.values;
    }
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Widget> _buildDeteksiBoxes() {
    final list = _deteksiList();
    final widgets = <Widget>[];
    for (int i = 0; i < list.length && i < _slots.length; i++) {
      final d = list[i];
      final status = (d['status'] ?? '').toString().toLowerCase();
      final sleeping = (d['label'] ?? '').toString() == 'head_down' ||
          status.contains('tidur') ||
          status.contains('menunduk');
      final nama = (d['nama'] ?? '').toString();
      final conf = d['confidence'] is num
          ? (d['confidence'] as num).toStringAsFixed(2)
          : '-';
      final slot = _slots[i];
      widgets.add(
        Positioned(
          left: slot.left,
          right: slot.right,
          top: slot.top,
          child: _buildBoundingBox(
            label: '$nama (${sleeping ? 'Tertidur' : 'Fokus'})',
            confidence: conf,
            color: sleeping ? Colors.redAccent : Colors.greenAccent,
            width: slot.width,
            height: slot.height,
          ),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    int siswaTidur = _presensiList.where((m) => m.isTertidur).length;
    int siswaFokus = _presensiList.length - siswaTidur;

    // [FIREBASE] status AI, model, resolusi, dan fps dibaca dari Firebase
    final bool aiOnline =
        _isServerOnline || (_monitoring?['server_online'] == true);
    final String modelAi = (_monitoring?['model_ai'] ?? '-').toString();
    final String resolusi = (_monitoring?['resolusi'] ?? '-').toString();
    final String fps = (_monitoring?['fps'] ?? '-').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.dosen.mataKuliah,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              '${widget.dosen.kelasAktif} • EduSense AI',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          // Indikator Server Online / Offline
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: aiOnline ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: aiOnline ? Colors.green : Colors.orange,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 4,
                  backgroundColor: aiOnline ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  aiOnline ? 'AI Online' : 'AI Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: aiOnline
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Alert Banner jika ada siswa tertidur
                    if (siswaTidur > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade600, Colors.red.shade700],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.shade300.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Peringatan Perhatian Kelas!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '$siswaTidur mahasiswa terdeteksi menunduk / tertidur saat sesi materi.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // CCTV Live Stream Feed Simulation
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Stream
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            color: const Color(0xFF1E293B),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 4,
                                      backgroundColor: Colors.red,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'LIVE CCTV POV',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Model: $modelAi',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Area Frame Gambar Kamera dengan Bounding Boxes
                          Stack(
                            children: [
                              Container(
                                height: 210,
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0F172A),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.videocam_outlined,
                                        size: 48,
                                        color: Colors.white.withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Frame Realtime ${widget.dosen.kelasAktif}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // [FIREBASE] Overlay Bounding Box dari detail_deteksi
                              ..._buildDeteksiBoxes(),
                            ],
                          ),

                          // Stream Bottom bar
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            color: const Color(0xFF1E293B),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Resolusi: $resolusi @ ${fps}fps',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(50, 24),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () async {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Menjalankan inferensi YOLOv8 ke API...'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                    await ApiService().deteksiTidur(
                                        'dataset_cctv_tersaring/cctv_0150.jpg');
                                    _refreshData();
                                  },
                                  icon: const Icon(Icons.refresh,
                                      size: 14, color: Colors.blueAccent),
                                  label: const Text(
                                    'Uji Inferensi',
                                    style: TextStyle(
                                        color: Colors.blueAccent, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Ringkasan Statistik Siswa
                    const Text(
                      'Statistik Perhatian Siswa',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Hadir di Kelas',
                            value: '${_presensiList.length}',
                            icon: Icons.people_alt_outlined,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Memperhatikan',
                            value: '$siswaFokus',
                            icon: Icons.visibility_outlined,
                            color: Colors.green.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Tertidur',
                            value: '$siswaTidur',
                            icon: Icons.hotel_outlined,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Kartu Kondisi IoT Kelas
                    const Text(
                      'Telemetri Lingkungan Kelas (IoT)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.thermostat_outlined,
                                color: Colors.orange, size: 32),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Suhu: ${_iotState?.suhu ?? 28.5}°C • Kelembaban: ${_iotState?.kelembaban ?? 65}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Mode Kipas: ${_iotState?.modeKipas ?? 'Auto'} (Kecepatan ${_iotState?.kecepatanKipas ?? 2})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _iotState?.statusRuangan ?? 'Normal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBoundingBox({
    required String label,
    required String confidence,
    required Color color,
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            color: color,
            child: Text(
              '$label $confidence',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}