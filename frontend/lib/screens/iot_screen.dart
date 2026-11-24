import 'dart:async';
import 'package:flutter/material.dart';
import '../models/iot_state.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';

/// Halaman Kontrol Kipas & Lingkungan Kelas IoT ESP32 (Prompt 5 & Prompt 6)
class IoTScreen extends StatefulWidget {
  const IoTScreen({super.key});

  @override
  State<IoTScreen> createState() => _IoTScreenState();
}

class _IoTScreenState extends State<IoTScreen>
    with SingleTickerProviderStateMixin {
  IoTState? _iotState;
  bool _isLoading = true;
  bool _isUpdating = false;
  int _lastManualSpeed = 2; // Kecepatan terakhir tersimpan pada mode manual
  StreamSubscription<IoTState?>? _iotSub;

  late AnimationController _fanAnimController;

  @override
  void initState() {
    super.initState();
    _fanAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fetchIoT();

    // Listener Real-Time Firebase Realtime Database
    try {
      _iotSub = FirebaseService().watchIoT().listen(
        (data) {
          if (!mounted || data == null) return;
          setState(() {
            _iotState = data;
            _isLoading = false;
            if (data.modeKipas == 'Manual') {
              _lastManualSpeed = data.kecepatanKipas;
            }
          });
          _updateFanAnimation(data.kecepatanKipas);
        },
        onError: (Object e) {
          debugPrint('[IoTScreen] Firebase error: $e');
        },
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _iotSub?.cancel();
    _fanAnimController.dispose();
    super.dispose();
  }

  void _updateFanAnimation(int speed) {
    if (speed > 0) {
      // Kecepatan putaran menyesuaikan level kipas
      final durationMs = speed == 1
          ? 1800
          : (speed == 2 ? 1000 : 500);
      _fanAnimController.duration = Duration(milliseconds: durationMs);
      if (!_fanAnimController.isAnimating) {
        _fanAnimController.repeat();
      }
    } else {
      _fanAnimController.stop();
    }
  }

  Future<void> _fetchIoT() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().getIoTStatus();
      if (mounted) {
        setState(() {
          _iotState = data;
          _isLoading = false;
          if (data.modeKipas == 'Manual') {
            _lastManualSpeed = data.kecepatanKipas;
          }
        });
        _updateFanAnimation(data.kecepatanKipas);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Menghitung kecepatan otomatis berdasar data pemicu suhu ruangan (DHT22)
  int _calculateAutoSpeed(double suhu) {
    if (suhu < 26.0) return 0;
    if (suhu <= 28.5) return 1;
    if (suhu <= 31.0) return 2;
    return 3;
  }

  /// Mengirim perubahan mode kipas (Otomatis vs Manual)
  Future<void> _onModeChanged(String newMode) async {
    if (_isUpdating) return;
    final currentSuhu = _iotState?.suhu ?? 28.5;

    int targetSpeed;
    if (newMode == 'Auto') {
      // Pada mode otomatis, kecepatan dihitung otomatis oleh sistem pemicu
      targetSpeed = _calculateAutoSpeed(currentSuhu);
    } else {
      // Pada mode manual, gunakan kecepatan terakhir yang tersimpan
      targetSpeed = _lastManualSpeed;
    }

    setState(() => _isUpdating = true);

    try {
      final newState = await ApiService().updateKipas(newMode, targetSpeed);
      if (mounted) {
        setState(() {
          _iotState = newState;
          _isUpdating = false;
        });
        _updateFanAnimation(newState.kecepatanKipas);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newMode == 'Auto'
                  ? '🤖 Mode Otomatis aktif. Kecepatan diatur otomatis oleh sistem.'
                  : '🖐️ Mode Manual aktif. Anda dapat mengatur level kecepatan.',
            ),
            backgroundColor: const Color(0xFF1E3A8A),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah mode kipas: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  /// Mengirim perubahan kecepatan kipas pada Mode Manual (Prompt 6)
  Future<void> _setManualSpeed(int targetSpeed) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
      _lastManualSpeed = targetSpeed;
    });

    try {
      final newState = await ApiService().updateKipas('Manual', targetSpeed);
      if (mounted) {
        setState(() {
          _iotState = newState;
          _isUpdating = false;
        });
        _updateFanAnimation(newState.kecepatanKipas);

        final label = targetSpeed == 0 ? 'Mati' : 'Level $targetSpeed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kecepatan kipas diatur ke $label (Manual)'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim perintah kecepatan ke perangkat: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = _iotState?.modeKipas ?? 'Auto';
    final isAuto = mode == 'Auto';
    final speed = _iotState?.kecepatanKipas ?? 0;
    final suhu = _iotState?.suhu ?? 28.5;
    final kelembaban = _iotState?.kelembaban ?? 64.0;
    final isFanRunning = speed > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Kontrol Kipas Pintar (IoT ESP32)',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1E3A8A)),
            onPressed: _fetchIoT,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Koneksi Perangkat ESP32
                  _buildConnectionStatusCard(),
                  const SizedBox(height: 14),

                  // Kartu Telemetri Sensor & Indikator Kipas Menyala
                  _buildTelemetryAndFanCard(suhu, kelembaban, speed, isFanRunning),
                  const SizedBox(height: 20),

                  // Mode Operasi: Otomatis vs Manual (Segmented Toggle)
                  _buildModeSelectorSection(isAuto),
                  const SizedBox(height: 18),

                  // Kontrol Kecepatan Kipas (Prompt 5 & 6)
                  _buildSpeedControlSection(isAuto, speed),
                  const SizedBox(height: 18),

                  // Data Pemicu Suhu DHT22 (Kondisi Otomatisasi Sistem)
                  _buildTriggerDataSection(suhu, isAuto),
                ],
              ),
            ),
    );
  }

  /// Badge Status Koneksi Perangkat
  Widget _buildConnectionStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'ESP32 Online',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '• Terhubung Firebase RTDB',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const Spacer(),
          if (_isUpdating)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.wifi_rounded, size: 16, color: Color(0xFF10B981)),
        ],
      ),
    );
  }

  /// Kartu Telemetri Sensor & Indikator Kipas Menyala
  Widget _buildTelemetryAndFanCard(
      double suhu, double kelembaban, int speed, bool isFanRunning) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: suhu > 30.0
              ? [const Color(0xFFEA580C), const Color(0xFFF97316)]
              : [const Color(0xFF1E3A8A), const Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Suhu
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suhu Ruang Lab (Sensor DHT22)',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suhu.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '°C',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Kelembaban: ${kelembaban.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),

              // Indikator Kipas Menyala dengan Animasi Putar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: RotationTransition(
                  turns: _fanAnimController,
                  child: Icon(
                    Icons.air_rounded,
                    color: isFanRunning ? Colors.white : Colors.white38,
                    size: 46,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),

          // Baris Notifikasi Status Kipas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isFanRunning
                        ? Icons.check_circle_outline
                        : Icons.power_settings_new,
                    color: isFanRunning
                        ? const Color(0xFF86EFAC)
                        : Colors.white60,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isFanRunning
                        ? 'Kipas Menyala (Level $speed)'
                        : 'Kipas Mati (Kecepatan 0)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _iotState?.statusRuangan ?? 'Normal Nyaman',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Segmented Button / Toggle Mode Otomatis vs Manual
  Widget _buildModeSelectorSection(bool isAuto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mode Operasi Kipas',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                'Prompt 5 & 6',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Segmented Toggle Button
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Tombol Otomatis
                Expanded(
                  child: InkWell(
                    onTap: _isUpdating ? null : () => _onModeChanged('Auto'),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isAuto ? const Color(0xFF1E3A8A) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isAuto
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.smart_toy_outlined,
                            size: 16,
                            color: isAuto ? Colors.white : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Mode Otomatis',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isAuto
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isAuto
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Tombol Manual
                Expanded(
                  child: InkWell(
                    onTap: _isUpdating ? null : () => _onModeChanged('Manual'),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !isAuto ? const Color(0xFF1E3A8A) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: !isAuto
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 16,
                            color: !isAuto ? Colors.white : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Mode Manual',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: !isAuto
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: !isAuto
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
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

  /// Bagian Kontrol Kecepatan Kipas (Terkunci di Otomatis, Aktif di Manual)
  Widget _buildSpeedControlSection(bool isAuto, int currentSpeed) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tingkat Kecepatan Kipas',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              // Kecepatan Berjalan Read-Only
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  currentSpeed == 0
                      ? 'Status: Mati'
                      : 'Berjalan: Level $currentSpeed',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Label Khusus Saat Mode Otomatis (Prompt 5)
          if (isAuto) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_rounded, size: 15, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kecepatan diatur otomatis oleh sistem',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Tombol Pilihan Kecepatan: Mati (0), 1, 2, 3
          // Dinonaktifkan dan tampak abu-abu jika Mode Otomatis (Prompt 5)
          AbsorbPointer(
            absorbing: isAuto || _isUpdating,
            child: Opacity(
              opacity: isAuto ? 0.45 : 1.0,
              child: Row(
                children: [
                  _buildSpeedButton(0, 'Mati (0)', isAuto, currentSpeed),
                  const SizedBox(width: 8),
                  _buildSpeedButton(1, 'Pelan (1)', isAuto, currentSpeed),
                  const SizedBox(width: 8),
                  _buildSpeedButton(2, 'Sedang (2)', isAuto, currentSpeed),
                  const SizedBox(width: 8),
                  _buildSpeedButton(3, 'Cepat (3)', isAuto, currentSpeed),
                ],
              ),
            ),
          ),

          if (isAuto) ...[
            const SizedBox(height: 8),
            const Text(
              '🔒 Pindah ke Mode Manual untuk mengatur kecepatan kipas secara bebas.',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              '⚡ Sentuh salah satu level di atas untuk mengirim perintah langsung ke ESP32.',
              style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
            ),
          ],
        ],
      ),
    );
  }

  /// Tombol Level Kecepatan Individual
  Widget _buildSpeedButton(
      int level, String label, bool isAuto, int currentSpeed) {
    final isSelected = currentSpeed == level;

    Color bg;
    Color border;
    Color text;

    if (isAuto) {
      bg = isSelected ? const Color(0xFFCBD5E1) : const Color(0xFFF1F5F9);
      border = isSelected ? const Color(0xFF94A3B8) : const Color(0xFFE2E8F0);
      text = const Color(0xFF64748B);
    } else {
      if (isSelected) {
        bg = const Color(0xFF1E3A8A);
        border = const Color(0xFF1E3A8A);
        text = Colors.white;
      } else {
        bg = const Color(0xFFF8FAFC);
        border = const Color(0xFFCBD5E1);
        text = const Color(0xFF334155);
      }
    }

    return Expanded(
      child: InkWell(
        onTap: () => _setManualSpeed(level),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: isSelected ? 1.5 : 1.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                level == 0
                    ? Icons.power_settings_new
                    : Icons.air_rounded,
                size: 20,
                color: text,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                  color: text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bagian Data Pemicu Suhu DHT22 (Kondisi Otomatisasi Sistem)
  Widget _buildTriggerDataSection(double suhu, bool isAuto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.thermostat_outlined,
                  size: 18, color: Color(0xFF1E3A8A)),
              SizedBox(width: 8),
              Text(
                'Data Pemicu Otomatisasi (Sensor Suhu DHT22)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTriggerRuleRow(
            '< 26.0 °C',
            'Kipas Mati (0)',
            suhu < 26.0 && isAuto,
          ),
          const SizedBox(height: 6),
          _buildTriggerRuleRow(
            '26.0 °C - 28.5 °C',
            'Kecepatan Pelan (Level 1)',
            suhu >= 26.0 && suhu <= 28.5 && isAuto,
          ),
          const SizedBox(height: 6),
          _buildTriggerRuleRow(
            '28.6 °C - 31.0 °C',
            'Kecepatan Sedang (Level 2)',
            suhu > 28.5 && suhu <= 31.0 && isAuto,
          ),
          const SizedBox(height: 6),
          _buildTriggerRuleRow(
            '> 31.0 °C',
            'Kecepatan Maksimal (Level 3)',
            suhu > 31.0 && isAuto,
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerRuleRow(String tempRange, String speedTarget, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: isActive ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            tempRange,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive
                  ? const Color(0xFF065F46)
                  : const Color(0xFF475569),
            ),
          ),
          Row(
            children: [
              Text(
                speedTarget,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive
                      ? const Color(0xFF047857)
                      : const Color(0xFF1E293B),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Aktif',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
