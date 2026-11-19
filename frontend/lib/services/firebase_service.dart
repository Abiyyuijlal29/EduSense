import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/mahasiswa.dart';
import '../models/iot_state.dart';
import '../models/user_dosen.dart';

/// Semua data dibaca langsung dari Firebase Realtime Database.
/// Tidak ada data yang diketik manual di kode. Fungsi "watch..." memberi
/// Stream: setiap data di Firebase berubah/bertambah, Stream langsung mengirim data baru.
/// Fungsi "get..." mengambil data sekali saja. Jika gagal -> null (tidak melempar error).
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Alamat database (konfigurasi koneksi, bukan data)
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

  // Sesi presensi terbaru (key diawali tanggal, jadi yang terakhir = terbaru)
  Query get _presensiQuery =>
      _db.ref('presensi').orderByKey().limitToLast(1);

  // Ruangan IoT pertama di node iot_ruangan (nama ruangan dibaca dari Firebase)
  Query get _iotQuery => _db.ref('iot_ruangan').limitToFirst(1);

  List<MahasiswaPresensi>? _parsePresensi(DataSnapshot snap) {
    if (!snap.exists) return null;
    final sesi = _toMap(snap.children.first.value);
    final mhs = _toMap(sesi?['mahasiswa']);
    if (mhs == null || mhs.isEmpty) return null;
    return mhs.values
        .map((v) =>
            MahasiswaPresensi.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
  }

  IoTState? _parseIoT(DataSnapshot snap) {
    if (!snap.exists) return null;
    final m = _toMap(snap.children.first.value);
    if (m == null) return null;
    return IoTState.fromJson(m);
  }

  // ================= LOGIN =================
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

  // Keluar dari akun Firebase (dipanggil saat tombol logout ditekan)
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Firebase signOut gagal: $e');
    }
  }

  // Profil dosen dari node "dosen" (dicari berdasarkan email)
  Future<UserDosen?> getDosen(String email) async {
    try {
      if (!_sudahLogin) return null;
      final snap = await _db
          .ref('dosen')
          .orderByChild('email')
          .equalTo(email)
          .limitToFirst(1)
          .get()
          .timeout(_timeout);
      if (!snap.exists) return null;
      final m = _toMap(snap.children.first.value);
      if (m == null) return null;
      return UserDosen.fromJson(m);
    } catch (e) {
      debugPrint('Firebase getDosen gagal: $e');
      return null;
    }
  }

  // ================= REAL-TIME (STREAM) =================
  // Dipakai layar dengan StreamBuilder: data baru di Firebase langsung muncul.

  Stream<List<MahasiswaPresensi>> watchPresensi() => _presensiQuery.onValue
      .map((e) => _parsePresensi(e.snapshot) ?? <MahasiswaPresensi>[]);

  Stream<IoTState?> watchIoT() =>
      _iotQuery.onValue.map((e) => _parseIoT(e.snapshot));

  /// Data terbaru dari sebuah node daftar, misalnya 'monitoring' atau 'alert_tidur'.
  Stream<Map<String, dynamic>?> watchLatest(String path) => _db
      .ref(path)
      .orderByKey()
      .limitToLast(1)
      .onValue
      .map((e) => e.snapshot.exists ? _toMap(e.snapshot.children.first.value) : null);

  /// Seluruh isi sebuah node, misalnya 'mahasiswa' atau 'log_kontrol_kipas'.
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
      if (!_sudahLogin) return null;
      final snap = await _iotQuery.get().timeout(_timeout);
      return _parseIoT(snap);
    } catch (e) {
      debugPrint('Firebase getIoTStatus gagal: $e');
      return null;
    }
  }

  // Ringkasan deteksi dari sesi monitoring terbaru
  Future<Map<String, dynamic>?> getMonitoringRingkasan() async {
    try {
      if (!_sudahLogin) return null;
      final snap = await _db
          .ref('monitoring')
          .orderByKey()
          .limitToLast(1)
          .get()
          .timeout(_timeout);
      if (!snap.exists) return null;
      final m = _toMap(snap.children.first.value);
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

  // ================= TULIS =================
  // Kontrol kipas: ubah iot_ruangan dan catat di log_kontrol_kipas
  Future<IoTState?> updateKipas(String mode, int kecepatan, String? nip) async {
    try {
      if (!_sudahLogin) return null;
      final awal = await _iotQuery.get().timeout(_timeout);
      if (!awal.exists) return null;
      final idRuangan = awal.children.first.key ?? '';
      final sebelum = _toMap(awal.children.first.value) ?? {};
      final ref = _db.ref('iot_ruangan/$idRuangan');
      final sekarang = DateTime.now().toUtc().toIso8601String();

      await ref.update({
        'mode_kipas': mode,
        'kecepatan_kipas': kecepatan,
        'updated_at': sekarang,
      }).timeout(_timeout);

      await _db.ref('log_kontrol_kipas').push().set({
        'id_ruangan': idRuangan,
        'timestamp': sekarang,
        'mode_sebelum': sebelum['mode_kipas'] ?? '',
        'mode_sesudah': mode,
        'kecepatan_sebelum': sebelum['kecepatan_kipas'] ?? 0,
        'kecepatan_sesudah': kecepatan,
        'pesan': 'Kipas diubah ke mode $mode (Kecepatan: $kecepatan)',
        'diubah_oleh': nip ?? '',
      }).timeout(_timeout);

      final sesudah = _toMap((await ref.get().timeout(_timeout)).value);
      if (sesudah == null) return null;
      return IoTState.fromJson(sesudah);
    } catch (e) {
      debugPrint('Firebase updateKipas gagal: $e');
      return null;
    }
  }

  // Simpan hasil registrasi mahasiswa ke node mahasiswa dan registrasi_wajah
  Future<bool> registrasiMahasiswa({
    required String nim,
    required String nama,
    required int jumlahSampel,
  }) async {
    try {
      if (!_sudahLogin) return false;
      // Key di Firebase tidak boleh mengandung . $ # [ ] /
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