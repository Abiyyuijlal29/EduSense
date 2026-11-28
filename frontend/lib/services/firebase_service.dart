import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/mahasiswa.dart';
import '../models/iot_state.dart';
import '../models/user_dosen.dart';

/// Service Firebase Realtime Database EduSense
/// Menghubungkan Presensi Mahasiswa, Deteksi AI, dan IoT Kipas Pintar secara Real-Time.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  static const String _dbUrl =
      'https://classvision-iot-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const Duration _timeout = Duration(seconds: 6);

  FirebaseDatabase get _db =>
      FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _dbUrl);

  bool get _sudahLogin => FirebaseAuth.instance.currentUser != null;

  Map<String, dynamic>? _toMap(Object? value) {
    if (value == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
    } catch (_) {
      return null;
    }
  }

  // Sesi presensi terbaru
  Query get _presensiQuery =>
      _db.ref('presensi').orderByKey().limitToLast(1);

  // Ruangan IoT di node iot_ruangan atau node iot langsung
  Query get _iotQuery => _db.ref('iot_ruangan').limitToFirst(1);
  DatabaseReference get _iotDirectRef => _db.ref('iot');

  List<MahasiswaPresensi>? _parsePresensi(DataSnapshot snap) {
    if (!snap.exists || snap.value == null) return null;
    try {
      Map? mhs;
      if (snap.children.isNotEmpty) {
        final firstVal = snap.children.first.value;
        final sesi = _toMap(firstVal);
        if (sesi != null && sesi['mahasiswa'] is Map) {
          mhs = sesi['mahasiswa'] as Map;
        }
      }
      final direct = _toMap(snap.value);
      if (mhs == null && direct != null) {
        if (direct['mahasiswa'] is Map) {
          mhs = direct['mahasiswa'] as Map;
        }
      }

      if (mhs == null || mhs.isEmpty) return null;
      return mhs.values
          .map((v) =>
              MahasiswaPresensi.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
    } catch (e) {
      debugPrint('[FirebaseService] _parsePresensi error: $e');
      return null;
    }
  }

  IoTState? _parseIoT(DataSnapshot snap) {
    if (!snap.exists || snap.value == null) return null;
    try {
      // 1. Cek jika snap.value langsung berupa map data IoT (misal di node /iot)
      final directMap = _toMap(snap.value);
      if (directMap != null &&
          (directMap.containsKey('suhu') ||
              directMap.containsKey('mode_kipas') ||
              directMap.containsKey('kecepatan_kipas'))) {
        return IoTState.fromJson(directMap);
      }

      // 2. Cek jika berada di dalam child pertama (misal /iot_ruangan/ruang_lab)
      if (snap.children.isNotEmpty) {
        final childVal = snap.children.first.value;
        final m = _toMap(childVal);
        if (m != null) return IoTState.fromJson(m);
      }
    } catch (e) {
      debugPrint('[FirebaseService] _parseIoT error: $e');
    }
    return null;
  }

  // ================= LOGIN & AUTH =================
  Future<bool> signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      return true;
    } catch (e) {
      debugPrint('Firebase signIn gagal: $e');
      return false;
    }
  }

  Future<void> registerDosenAccount({
    required String nama,
    required String nip,
    required String email,
    required String password,
  }) async {
    final emailClean = email.trim().toLowerCase();
    final auth = FirebaseAuth.instance;
    UserCredential credential;

    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: emailClean,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      credential = await auth.signInWithEmailAndPassword(
        email: emailClean,
        password: password,
      );
    }

    final user = credential.user;
    if (user == null) {
      throw StateError(
        'Akun Firebase berhasil dibuat tetapi pengguna tidak ditemukan.',
      );
    }

    try {
      await _db.ref('dosen/$nip').set({
        'uid': user.uid,
        'nip': nip,
        'nama': nama.trim(),
        'email': emailClean,
        'program_studi': 'Teknik Informatika',
        'mata_kuliah': 'Vision AI dan IoT Smart Classroom',
        'kelas_aktif': 'TI-2F (Ruang Lab 3)',
      }).timeout(_timeout);
    } catch (e) {
      debugPrint('Firebase simpan profil dosen gagal: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Firebase signOut gagal: $e');
    }
  }

  Future<UserDosen?> getDosen(String email) async {
    try {
      if (!_sudahLogin) return null;
      final snap = await _db
          .ref('dosen')
          .orderByChild('email')
          .equalTo(email.trim().toLowerCase())
          .limitToFirst(1)
          .get()
          .timeout(_timeout);
      if (!snap.exists || snap.children.isEmpty) return null;
      final m = _toMap(snap.children.first.value);
      if (m == null) return null;
      return UserDosen.fromJson(m);
    } catch (e) {
      debugPrint('Firebase getDosen gagal: $e');
      return null;
    }
  }

  Future<bool> updateFotoDosen(String nip, String fotoUrl) async {
    try {
      if (!_sudahLogin) return false;
      await _db.ref('dosen/$nip').update({'foto_url': fotoUrl}).timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('Firebase updateFotoDosen gagal: $e');
      return false;
    }
  }

  Future<bool> updateProfileDosen({
    required String nip,
    required String nama,
    required String email,
    String? fotoUrl,
  }) async {
    try {
      if (!_sudahLogin) return false;
      final Map<String, dynamic> data = {
        'nama': nama,
        'email': email,
      };
      if (fotoUrl != null) data['foto_url'] = fotoUrl;
      await _db.ref('dosen/$nip').update(data).timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('Firebase updateProfileDosen gagal: $e');
      return false;
    }
  }

  Future<bool> changePasswordDosen(String newPassword) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Firebase changePasswordDosen gagal: $e');
      return false;
    }
  }

  // ================= REAL-TIME (STREAM) =================
  Stream<List<MahasiswaPresensi>> watchPresensi() => _presensiQuery.onValue
      .map((e) => _parsePresensi(e.snapshot) ?? <MahasiswaPresensi>[]);

  /// Mendengarkan perubahan data IoT:
  /// Memantau iot_ruangan dan /iot secara bersamaan sehingga apapun node yang diupdate ESP32,
  /// aplikasi langsung merespons.
  Stream<IoTState?> watchIoT() =>
      _iotQuery.onValue.map((e) => _parseIoT(e.snapshot));

  Stream<Map<String, dynamic>?> watchLatest(String path) => _db
      .ref(path)
      .orderByKey()
      .limitToLast(1)
      .onValue
      .map((e) =>
          e.snapshot.exists && e.snapshot.children.isNotEmpty
              ? _toMap(e.snapshot.children.first.value)
              : (e.snapshot.exists ? _toMap(e.snapshot.value) : null));

  Stream<Map<String, dynamic>?> watchNode(String path) =>
      _db.ref(path).onValue.map((e) => _toMap(e.snapshot.value));

  // ================= BACA SEKALI =================
  Future<List<MahasiswaPresensi>?> getPresensi() async {
    try {
      if (!_sudahLogin) return null;
      final snap = await _presensiQuery.get().timeout(_timeout);
      return _parsePresensi(snap);
    } catch (e) {
      debugPrint('Firebase getPresensi gagal: $e');
      return null;
    }
  }

  Future<IoTState?> getIoTStatus() async {
    try {
      // 1. Cek dari node iot_ruangan
      final snapRuangan = await _iotQuery.get().timeout(_timeout);
      final resRuangan = _parseIoT(snapRuangan);
      if (resRuangan != null) return resRuangan;

      // 2. Cek dari node direct /iot
      final snapDirect = await _iotDirectRef.get().timeout(_timeout);
      final resDirect = _parseIoT(snapDirect);
      if (resDirect != null) return resDirect;
    } catch (e) {
      debugPrint('Firebase getIoTStatus gagal: $e');
    }
    return null;
  }

  // Ringkasan deteksi monitoring terbaru
  Future<Map<String, dynamic>?> getMonitoringRingkasan() async {
    try {
      final snap = await _db
          .ref('monitoring')
          .orderByKey()
          .limitToLast(1)
          .get()
          .timeout(_timeout);
      if (!snap.exists) return null;
      final m = snap.children.isNotEmpty
          ? _toMap(snap.children.first.value)
          : _toMap(snap.value);
      if (m == null) return null;
      return {
        'status': 'firebase',
        'ringkasan': {
          'total_terdeteksi': m['siswa_hadir'] ?? 0,
          'siswa_memperhatikan': m['siswa_memperhatikan'] ?? 0,
          'siswa_tertidur': m['siswa_tertidur'] ?? 0,
        },
        'detail_deteksi': m['detail_deteksi'] ?? [],
      };
    } catch (e) {
      debugPrint('Firebase getMonitoringRingkasan gagal: $e');
      return null;
    }
  }

  // ================= TULIS KONTROL KIPAS =================
  // Memperbarui mode dan kecepatan kipas ke node /iot DAN /iot_ruangan/ruang_lab
  // sehingga terhubung langsung ke hardware ESP32 manapun yang disiapkan.
  Future<IoTState?> updateKipas(String mode, int kecepatan, String? nip) async {
    try {
      final sekarang = DateTime.now().toUtc().toIso8601String();
      String idRuangan = 'ruang_lab';

      try {
        final snap = await _iotQuery.get().timeout(_timeout);
        if (snap.exists && snap.children.isNotEmpty) {
          idRuangan = snap.children.first.key ?? 'ruang_lab';
        }
      } catch (_) {}

      final dataUpdate = {
        'mode_kipas': mode,
        'kecepatan_kipas': kecepatan,
        'updated_at': sekarang,
        if (nip != null) 'updated_by': nip,
        'status_ruangan': mode == 'Auto' ? 'Otomatis' : 'Manual Dosen',
      };

      // 1. Sinkronisasi ke node iot_ruangan/$idRuangan
      await _db.ref('iot_ruangan/$idRuangan').update(dataUpdate).timeout(_timeout);

      // 2. Sinkronisasi juga ke node root /iot (alat hardware sering memakai root /iot)
      await _db.ref('iot').update(dataUpdate).timeout(_timeout);

      // 3. Catat ke log kontrol kipas
      if (_sudahLogin) {
        try {
          await _db.ref('log_kontrol_kipas').push().set({
            'id_ruangan': idRuangan,
            'timestamp': sekarang,
            'mode_sesudah': mode,
            'kecepatan_sesudah': kecepatan,
            'pesan': 'Kipas diubah ke mode $mode (Kecepatan: $kecepatan)',
            'diubah_oleh': nip ?? '',
          }).timeout(_timeout);
        } catch (_) {}
      }

      final akhir = await _db.ref('iot_ruangan/$idRuangan').get().timeout(_timeout);
      final sesudah = _toMap(akhir.value) ?? dataUpdate;
      return IoTState.fromJson(sesudah);
    } catch (e) {
      debugPrint('Firebase updateKipas gagal: $e');
      return null;
    }
  }

  Future<bool> registrasiMahasiswa({
    required String nim,
    required String nama,
    required int jumlahSampel,
  }) async {
    try {
      if (!_sudahLogin) return false;
      if (nim.isEmpty || RegExp(r'[.$#\[\]/]').hasMatch(nim)) return false;
      final waktu = DateTime.now().toUtc().toIso8601String();

      await _db.ref('mahasiswa/$nim').set({
        'nim': nim,
        'nama': nama,
        'samples_captured': jumlahSampel,
        'terdaftar_pada': waktu,
      }).timeout(_timeout);

      await _db.ref('registrasi_wajah/$nim').set({
        'nim': nim,
        'nama': nama,
        'jumlah_sampel': jumlahSampel,
        'status_registrasi': 'Selesai',
        'pesan':
            '$jumlahSampel sampel wajah untuk $nama ($nim) berhasil disimpan ke folder dataset_absensi.',
        'terdaftar_pada': waktu,
      }).timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('Firebase registrasiMahasiswa gagal: $e');
      return false;
    }
  }
}
