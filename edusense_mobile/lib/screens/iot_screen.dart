import 'dart:async';
import 'package:flutter/material.dart';
import '../models/iot_state.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';

class IoTScreen extends StatefulWidget {
  const IoTScreen({super.key});

  @override
  State<IoTScreen> createState() => _IoTScreenState();
}

class _IoTScreenState extends State<IoTScreen> {
  IoTState? _iotState;
  bool _isLoading = true;
  bool _isUpdating = false;
  StreamSubscription<IoTState?>? _iotSub;

  @override
  void initState() {
    super.initState();
    _fetchIoT();
    // [FIREBASE] real-time: suhu, kelembaban, dan kipas berubah otomatis
    try {
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
    } catch (_) {}
  }

  @override
  void dispose() {
    _iotSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchIoT() async {
    setState(() => _isLoading = true);
    final data = await ApiService().getIoTStatus();
    if (mounted) {
      setState(() {
        _iotState = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _setKipas(String mode, int kecepatan) async {
    setState(() => _isUpdating = true);
    final newState = await ApiService().updateKipas(mode, kecepatan);
    if (mounted) {
      setState(() {
        _iotState = newState;
        _isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kipas diubah ke mode $mode (Kecepatan $kecepatan)',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = _iotState?.modeKipas ?? 'Auto';
    final speed = _iotState?.kecepatanKipas ?? 2;
    final suhu = _iotState?.suhu ?? 28.5;
    final kelembaban = _iotState?.kelembaban ?? 64.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Kontrol Lingkungan Kelas (IoT ESP32)',
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
                  // Kartu Utama Suhu & Kelembaban
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: suhu > 30.0
                            ? [Colors.deepOrange.shade600, Colors.orange.shade500]
                            : [const Color(0xFF1E3A8A), const Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Suhu Ruang Lab',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      suhu.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      '°C',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.thermostat_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kelembaban: ${kelembaban.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Status: ${_iotState?.statusRuangan ?? 'Normal'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bagian Kontrol Kipas
                  const Text(
                    'Manajemen Kipas Angin Pintar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mode Selector (Auto vs Manual)
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Mode Operasi Kipas',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: mode == 'Auto'
                                    ? Colors.green.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                mode == 'Auto'
                                    ? '🤖 Otomatis Suhu'
                                    : '🖐️ Manual Dosen',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: mode == 'Auto'
                                      ? Colors.green.shade800
                                      : Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Switch Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mode == 'Auto'
                                      ? const Color(0xFF1E3A8A)
                                      : Colors.grey.shade100,
                                  foregroundColor: mode == 'Auto'
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  elevation: mode == 'Auto' ? 2 : 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: _isUpdating
                                    ? null
                                    : () => _setKipas('Auto', speed),
                                icon: const Icon(Icons.autorenew_rounded,
                                    size: 18),
                                label: const Text('Mode Otomatis'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mode == 'Manual'
                                      ? const Color(0xFF1E3A8A)
                                      : Colors.grey.shade100,
                                  foregroundColor: mode == 'Manual'
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  elevation: mode == 'Manual' ? 2 : 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: _isUpdating
                                    ? null
                                    : () => _setKipas('Manual', speed),
                                icon: const Icon(Icons.touch_app_outlined,
                                    size: 18),
                                label: const Text('Mode Manual'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        Text(
                          mode == 'Auto'
                              ? 'ℹ️ Pada Mode Otomatis, ESP32 mengatur kecepatan kipas berdasar suhu sensor DHT22 (<26°C: Off, 27-28°C: Low, 29-31°C: Med, >31°C: High).'
                              : 'ℹ️ Pada Mode Manual, Anda bebas mengatur kecepatan kipas 0, 1, 2, atau 3.',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Fan Speed Control Selector
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pilih Tingkat Kecepatan Kipas',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSpeedButton(0, 'Mati (0)'),
                            _buildSpeedButton(1, 'Pelan (1)'),
                            _buildSpeedButton(2, 'Sedang (2)'),
                            _buildSpeedButton(3, 'Cepat (3)'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSpeedButton(int targetSpeed, String label) {
    final currentSpeed = _iotState?.kecepatanKipas ?? 0;
    final isSelected = currentSpeed == targetSpeed;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: _isUpdating
              ? null
              : () => _setKipas(_iotState?.modeKipas ?? 'Manual', targetSpeed),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1E3A8A)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.mode_fan_off_outlined,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  size: 22,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}