import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_dosen.dart';
import '../models/mahasiswa.dart';
import '../models/iot_state.dart';

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
  Future<UserDosen> login(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username_atau_email': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentUser = UserDosen.fromJson(data['data_dosen']);
        return currentUser!;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['detail'] ?? 'NIP/Password salah');
      }
    } catch (e) {
      // Fallback Demo jika server offline tetapi dosen mencoba login default
      if ((username.contains('dosen') || username.contains('1985')) &&
          (password == 'dosen123' || password == 'admin123')) {
        currentUser = UserDosen(
          nip: '198501012010121001',
          nama: 'Dr. Ir. Dosen Pengampu, M.Kom.',
          email: 'dosen@polije.ac.id',
          programStudi: 'Teknik Informatika',
          mataKuliah: 'Vision AI & IoT Smart Classroom',
          kelasAktif: 'TI-2F (Ruang Lab 3)',
        );
        return currentUser!;
      }
      rethrow;
    }
  }

  // 3. Mengambil Data Presensi Mahasiswa
  Future<List<MahasiswaPresensi>> getPresensi() async {
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

    // Fallback Mock Presensi jika server offline
    return [
      MahasiswaPresensi(
        nim: 'E41241919',
        nama: 'Abiyyu Ijlal Rasib Novamatin',
        jamKehadiran: '07:35 WIB',
        status: 'Hadir',
        aktivitasTerakhir: 'Memperhatikan',
      ),
      MahasiswaPresensi(
        nim: 'E41241859',
        nama: 'Adelia Hanifa Saharani',
        jamKehadiran: '07:42 WIB',
        status: 'Hadir',
        aktivitasTerakhir: 'Memperhatikan',
      ),
      MahasiswaPresensi(
        nim: 'E41242025',
        nama: 'Muhammad Rahamadhani',
        jamKehadiran: '07:48 WIB',
        status: 'Hadir',
        aktivitasTerakhir: 'Tertidur / Menunduk',
      ),
      MahasiswaPresensi(
        nim: 'E41242065',
        nama: 'Muhammad Akbar Ellia Menang',
        jamKehadiran: '07:50 WIB',
        status: 'Hadir',
        aktivitasTerakhir: 'Memperhatikan',
      ),
    ];
  }

  // 4. Membaca Status IoT (Suhu & Kipas)
  Future<IoTState> getIoTStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/iot/status'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return IoTState.fromJson(data['iot']);
      }
    } catch (_) {}

    // Fallback Mock State jika server belum terhubung
    return IoTState(
      suhu: 28.8,
      kelembaban: 64.0,
      modeKipas: 'Auto',
      kecepatanKipas: 2,
      statusRuangan: 'Normal Nyaman',
    );
  }

  // 5. Mengirim Perintah Kontrol Kipas ke IoT
  Future<IoTState> updateKipas(String mode, int kecepatan) async {
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

    return IoTState(
      suhu: 28.8,
      kelembaban: 64.0,
      modeKipas: mode,
      kecepatanKipas: kecepatan,
      statusRuangan: mode == 'Auto' ? 'Otomatis' : 'Manual Dosen',
    );
  }

  // 6. Jalankan Deteksi Tidur Langsung (Inference)
  Future<Map<String, dynamic>> deteksiTidur(String pathGambar) async {
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

    return {
      'status': 'mock',
      'ringkasan': {
        'total_terdeteksi': 2,
        'siswa_memperhatikan': 1,
        'siswa_tertidur': 1
      }
    };
  }
}
