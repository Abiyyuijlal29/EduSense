import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_dosen.dart';
import '../models/mahasiswa.dart';
import '../models/iot_state.dart';
import 'firebase_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // URL default: 10.0.2.2 untuk emulator Android, 127.0.0.1 untuk Windows Desktop/Web
  String baseUrl = kIsWeb
      ? 'http://127.0.0.1:8000'
      : (defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8000'
          : 'http://127.0.0.1:8000');

  UserDosen? currentUser;

  void updateBaseUrl(String newUrl) {
    String cleanUrl = newUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    baseUrl = cleanUrl;
  }

  // 1. Cek Koneksi Server
  Future<bool> checkServerHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 2. Login Dosen
  // Urutan: (1) Firebase Authentication + profil dari node "dosen" di Firebase,
  //         (2) cadangan: server FastAPI (termasuk login memakai NIP).
  Future<UserDosen> login(String username, String password) async {
    final input = username.trim();

    // [FIREBASE] sumber utama: login memakai email yang diketik
    if (input.contains('@')) {
      final berhasil = await FirebaseService().signIn(input, password);
      if (berhasil) {
        final profil = await FirebaseService().getDosen(input);
        if (profil != null) {
          currentUser = profil;
          return profil;
        }
        throw Exception(
            'Akun berhasil login, tetapi profil dosen dengan email ini belum ada di Firebase (node dosen).');
      }
    }

    // Cadangan: server FastAPI
    http.Response? response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username_atau_email': input,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      response = null;
    }

    if (response == null) {
      throw Exception(
          'Login gagal. Periksa email/kata sandi, atau server tidak dapat dihubungi.');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      currentUser = UserDosen.fromJson(data['data_dosen']);
      // [FIREBASE] login juga ke Firebase agar data bisa dibaca
      await FirebaseService().signIn(currentUser!.email, password);
      return currentUser!;
    }

    String pesan = 'NIP/Password salah';
    try {
      final data = jsonDecode(response.body);
      pesan = (data['detail'] ?? pesan).toString();
    } catch (_) {}
    throw Exception(pesan);
  }

  // 3. Mengambil Data Presensi Mahasiswa
  Future<List<MahasiswaPresensi>> getPresensi() async {
    // [FIREBASE] sumber utama: baca langsung dari Firebase
    final fb = await FirebaseService().getPresensi();
    if (fb != null && fb.isNotEmpty) return fb;

    // Cadangan: server FastAPI
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/presensi'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['daftar_mahasiswa'] as List)
            .map((item) => MahasiswaPresensi.fromJson(item))
            .toList();
        return list;
      }
    } catch (_) {}

    // Tidak ada data di Firebase maupun server
    return [];
  }

  // 4. Membaca Status IoT (Suhu & Kipas)
  Future<IoTState> getIoTStatus() async {
    // [FIREBASE] sumber utama: baca langsung dari Firebase
    final fb = await FirebaseService().getIoTStatus();
    if (fb != null) return fb;

    // Cadangan: server FastAPI
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/iot/status'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return IoTState.fromJson(data['iot']);
      }
    } catch (_) {}

    // Tidak ada data: nilai bawaan model
    return IoTState.fromJson({});
  }

  // 5. Mengirim Perintah Kontrol Kipas ke IoT
  Future<IoTState> updateKipas(String mode, int kecepatan) async {
    // [FIREBASE] sumber utama: tulis langsung ke Firebase
    final fb =
        await FirebaseService().updateKipas(mode, kecepatan, currentUser?.nip);
    if (fb != null) return fb;

    // Cadangan: server FastAPI
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/iot/kontrol-kipas'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mode_kipas': mode,
              'kecepatan_kipas': kecepatan,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return IoTState.fromJson(data['iot']);
      }
    } catch (_) {}

    return IoTState.fromJson({
      'mode_kipas': mode,
      'kecepatan_kipas': kecepatan,
      'status_ruangan': mode == 'Auto' ? 'Otomatis' : 'Manual Dosen',
    });
  }

  // 6. Jalankan Deteksi Tidur Langsung (Inference)
  Future<Map<String, dynamic>> deteksiTidur(String pathGambar) async {
    // Inferensi gambar hanya bisa dilakukan server FastAPI
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/deteksi-tidur'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'path_gambar': pathGambar}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}

    // [FIREBASE] jika server tidak ada, pakai ringkasan monitoring terbaru dari Firebase
    final fb = await FirebaseService().getMonitoringRingkasan();
    if (fb != null) return fb;

    return {
      'status': 'kosong',
      'ringkasan': {
        'total_terdeteksi': 0,
        'siswa_memperhatikan': 0,
        'siswa_tertidur': 0
      }
    };
  }
}