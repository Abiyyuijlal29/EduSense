import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/mahasiswa.dart';
import '../models/attendance_history.dart';

/// Konstanta Batas Validasi Tidur (Prompt 4): 10 Menit
/// Mudah diubah melalui konfigurasi konstan ini.
const int kSleepThresholdMinutes = 10;

class PresensiService {
  static final PresensiService _instance = PresensiService._internal();
  factory PresensiService() => _instance;
  PresensiService._internal();

  static const String _dbUrl =
      'https://classvision-iot-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const Duration _timeout = Duration(seconds: 6);

  // Konstanta Batas Keterlambatan: 15 menit setelah jam mulai kelas (07:30 WIB)
  int lateThresholdMinutes = 15;
  String classStartTimeStr = '07:30';

  // Ambang batas validasi tidur 10 menit (Prompt 4)
  static const int sleepThresholdMinutes = kSleepThresholdMinutes;

  /// Logika Validasi Tidur (Prompt 4):
  /// Fungsi tersendiri dengan threshold 10 menit yang mudah diubah.
  /// Status ini menjadi sumber data untuk Prompt 9.
  static bool isSleepValid(int accumulatedMinutes) {
    return accumulatedMinutes >= kSleepThresholdMinutes;
  }

  FirebaseDatabase? get _db {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _dbUrl,
      );
    } catch (e) {
      debugPrint('[PresensiService] Firebase instance not ready: $e');
      return null;
    }
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Cache lokal untuk reaktivitas & fallback offline
  final Map<String, MahasiswaPresensi> _studentCache = {};
  final StreamController<List<MahasiswaPresensi>> _streamController =
      StreamController<List<MahasiswaPresensi>>.broadcast();

  Stream<List<MahasiswaPresensi>> get studentsStream =>
      _streamController.stream;

  List<MahasiswaPresensi> get currentStudents =>
      _studentCache.values.toList();

  bool _isListening = false;
  Timer? _sleepTicker;

  void init() {
    if (_isListening) return;
    _isListening = true;
    _setupInitialDataAndListener();
    _startSleepTicker();
    checkAndRollOverDailySleepReport();
  }

  void dispose() {
    _sleepTicker?.cancel();
  }

  void _setupInitialDataAndListener() {
    final db = _db;
    if (db == null) {
      _loadDefaultSeedData();
      return;
    }

    try {
      final ref = db.ref('presensi/$_todayKey/mahasiswa');
      ref.onValue.listen((event) async {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          await _seedInitialFirebaseData();
          return;
        }

        final raw = event.snapshot.value;
        if (raw is Map) {
          final Map<String, MahasiswaPresensi> updated = {};
          for (var entry in raw.entries) {
            final val = entry.value;
            if (val is Map) {
              final studentMap = Map<String, dynamic>.from(val);
              final student = MahasiswaPresensi.fromJson(studentMap);
              updated[student.nim] = student;
            }
          }
          _studentCache.clear();
          _studentCache.addAll(updated);
          _notifyListeners();
        }
      }, onError: (e) {
        debugPrint('[PresensiService] onValue error: $e');
        if (_studentCache.isEmpty) {
          _loadDefaultSeedData();
        }
      });
    } catch (e) {
      debugPrint('[PresensiService] setupListener error: $e');
      _loadDefaultSeedData();
    }
  }

  void _notifyListeners() {
    _streamController.add(currentStudents);
  }

  // ===========================================================================
  // 1. DATA SEEDING (DEFAULT ALPHA / MAHASISWA KELAS)
  // ===========================================================================
  Future<void> _seedInitialFirebaseData() async {
    final defaultStudents = [
      MahasiswaPresensi(
        nim: 'E41241919',
        nama: 'Abiyyu Ijlal Rasib Novamatin',
        jamKehadiran: '07:35 WIB',
        jamKejadianTerakhir: '07:35 WIB',
        status: 'Hadir',
        aktivitasTerakhir: 'Memperhatikan',
        lastCaptureUrl:
            'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=400&q=80',
        totalTidurMenitHariIni: 0,
        lastReportDate: _todayKey,
      ),
      MahasiswaPresensi(
        nim: 'E41241859',
        nama: 'Adelia Hanifa Saharani',
        jamKehadiran: '07:42 WIB',
        jamKejadianTerakhir: '07:42 WIB',
        status: 'Hadir',
        aktivitasTerakhir: 'Memperhatikan',
        lastCaptureUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
        totalTidurMenitHariIni: 0,
        lastReportDate: _todayKey,
      ),
      MahasiswaPresensi(
        nim: 'E41242025',
        nama: 'Muhammad Rahamadhani',
        jamKehadiran: '07:48 WIB',
        jamKejadianTerakhir: '07:55 WIB',
        status: 'Terlambat',
        aktivitasTerakhir: 'Menunduk / Tidur',
        lastCaptureUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
        totalTidurMenitHariIni: 12,
        isSleepingNow: true,
        currentSleepSeconds: 720, // 12 menit -> Valid Tertidur
        lastReportDate: _todayKey,
      ),
      MahasiswaPresensi(
        nim: 'E41242065',
        nama: 'Muhammad Akbar Ellia Menang',
        jamKehadiran: '-',
        jamKejadianTerakhir: '-',
        status: 'Alpha',
        aktivitasTerakhir: 'Belum Terdeteksi',
        totalTidurMenitHariIni: 0,
        lastReportDate: _todayKey,
      ),
    ];

    for (var m in defaultStudents) {
      _studentCache[m.nim] = m;
      await _syncStudentToFirebase(m);
    }
    _notifyListeners();
  }

  void _loadDefaultSeedData() {
    if (_studentCache.isNotEmpty) return;
    final defaultStudents = [
      MahasiswaPresensi(
        nim: 'E41241919',
        nama: 'Abiyyu Ijlal Rasib Novamatin',
        jamKehadiran: '07:35 WIB',
        jamKejadianTerakhir: '07:35 WIB',
        status: 'Hadir',
        aktivitasTerakhir: 'Memperhatikan',
        lastCaptureUrl:
            'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=400&q=80',
        totalTidurMenitHariIni: 0,
        lastReportDate: _todayKey,
      ),
      MahasiswaPresensi(
        nim: 'E41241859',
        nama: 'Adelia Hanifa Saharani',
        jamKehadiran: '07:42 WIB',
        jamKejadianTerakhir: '07:42 WIB',
        status: 'Hadir',
        aktivitasTerakhir: 'Memperhatikan',
        lastCaptureUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
        totalTidurMenitHariIni: 0,
        lastReportDate: _todayKey,
      ),
      MahasiswaPresensi(
        nim: 'E41242025',
        nama: 'Muhammad Rahamadhani',
        jamKehadiran: '07:48 WIB',
        jamKejadianTerakhir: '07:55 WIB',
        status: 'Terlambat',
        aktivitasTerakhir: 'Menunduk / Tidur',
        lastCaptureUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
        totalTidurMenitHariIni: 12,
        isSleepingNow: true,
        currentSleepSeconds: 720,
        lastReportDate: _todayKey,
      ),
      MahasiswaPresensi(
        nim: 'E41242065',
        nama: 'Muhammad Akbar Ellia Menang',
        jamKehadiran: '-',
        jamKejadianTerakhir: '-',
        status: 'Alpha',
        aktivitasTerakhir: 'Belum Terdeteksi',
        totalTidurMenitHariIni: 0,
        lastReportDate: _todayKey,
      ),
    ];

    for (var m in defaultStudents) {
      _studentCache[m.nim] = m;
    }
    _notifyListeners();
  }

  // ===========================================================================
  // 2. LOGIKA KETERLAMBATAN (POIN C)
  // ===========================================================================
  bool isTimeLate(DateTime time) {
    try {
      final parts = classStartTimeStr.split(':');
      final startHour = int.parse(parts[0]);
      final startMin = int.parse(parts[1]);

      final lateThreshold = DateTime(
        time.year,
        time.month,
        time.day,
        startHour,
        startMin,
      ).add(Duration(minutes: lateThresholdMinutes));

      return time.isAfter(lateThreshold);
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // 3. HADIR VALID DARI CAPTURE CCTV OTOMATIS (POIN B & C)
  // ===========================================================================
  Future<bool> handleAutomaticPresence({
    required String studentId,
    required DateTime capturedAt,
    required String imageUrl,
    bool forceOverrideIfManual = false,
  }) async {
    final student = _studentCache[studentId];
    if (student == null) return false;

    if (student.isManualOverride && !forceOverrideIfManual) {
      return false;
    }

    final isLate = isTimeLate(capturedAt);
    final newStatus = isLate ? 'Terlambat' : 'Hadir';
    final timeStr = DateFormat('HH:mm:ss').format(capturedAt) + ' WIB';

    final historyItem = AttendanceHistoryItem(
      id: 'cctv_${DateTime.now().millisecondsSinceEpoch}',
      studentId: studentId,
      type: newStatus.toLowerCase(),
      timestamp: capturedAt,
      evidenceUrl: imageUrl,
      evidenceType: 'cctv_capture',
      note: isLate
          ? 'Hadir terdeteksi melewati batas toleransi masuk'
          : 'Hadir tepat waktu terverifikasi AI CCTV',
      createdBy: 'system',
    );

    final updatedRiwayat = [historyItem, ...student.riwayat];

    final updated = student.copyWith(
      status: newStatus,
      jamKehadiran: timeStr,
      jamKejadianTerakhir: timeStr,
      lastCaptureUrl: imageUrl,
      isManualOverride: false,
      riwayat: updatedRiwayat,
    );

    _studentCache[studentId] = updated;
    _notifyListeners();
    await _syncStudentToFirebase(updated);
    await _saveHistoryItemToFirebase(studentId, historyItem);
    return true;
  }

  // ===========================================================================
  // 4. OVERRIDE MANUAL DOSEN: SAKIT / DISPENSASI (POIN D)
  // ===========================================================================
  Future<bool> overrideStatusWithEvidence({
    required String studentId,
    required String status,
    required String evidenceUrl,
    required String evidenceType,
    String? note,
    required String dosenNameOrNip,
  }) async {
    final student = _studentCache[studentId];
    if (student == null) return false;

    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm:ss').format(now) + ' WIB';

    final historyItem = AttendanceHistoryItem(
      id: 'doc_${now.millisecondsSinceEpoch}',
      studentId: studentId,
      type: status.toLowerCase(),
      timestamp: now,
      evidenceUrl: evidenceUrl,
      evidenceType: evidenceType,
      note: note ?? 'Pengajuan bukti $status disetujui dosen',
      createdBy: 'dosen',
      dosenNameOrNip: dosenNameOrNip,
    );

    final updatedRiwayat = [historyItem, ...student.riwayat];

    final updated = student.copyWith(
      status: status,
      jamKejadianTerakhir: timeStr,
      isManualOverride: true,
      lastCaptureUrl: evidenceUrl,
      riwayat: updatedRiwayat,
    );

    _studentCache[studentId] = updated;
    _notifyListeners();
    await _syncStudentToFirebase(updated);
    await _saveHistoryItemToFirebase(studentId, historyItem);
    return true;
  }

  // ===========================================================================
  // 5. VALIDASI TIDUR: AKUMULASI 10 MENIT → CAPTURE + CARD MENJADI MERAH (PROMPT 4)
  // ===========================================================================
  void _startSleepTicker() {
    _sleepTicker?.cancel();
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      bool needNotify = false;

      for (var entry in _studentCache.entries) {
        final student = entry.value;
        if (student.isSleepingNow) {
          final newSeconds = student.currentSleepSeconds + 1;
          final accumulatedMin = newSeconds ~/ 60;
          final isValidSleep = isSleepValid(accumulatedMin);

          // Jika mencapai valid tertidur (>= 10 menit) dan belum berstatus Tertidur
          if (isValidSleep && student.status != 'Tertidur') {
            final now = DateTime.now();
            final timeStr = DateFormat('HH:mm:ss').format(now) + ' WIB';
            final captureUrl = student.lastCaptureUrl ??
                'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80';

            // Simpan 1 capture CCTV per sesi tidur ke riwayat
            final historyItem = AttendanceHistoryItem(
              id: 'sleep_${now.millisecondsSinceEpoch}',
              studentId: student.nim,
              type: 'tidur',
              timestamp: now,
              evidenceUrl: captureUrl,
              evidenceType: 'cctv_capture',
              note:
                  'Valid Tertidur: Akumulasi tidur mencapai $accumulatedMin menit',
              createdBy: 'system',
              durationMinutes: accumulatedMin,
            );

            _studentCache[student.nim] = student.copyWith(
              status: 'Tertidur',
              previousStatus: student.status,
              jamKejadianTerakhir: timeStr,
              currentSleepSeconds: newSeconds,
              hasCapturedThisSession: true,
              riwayat: [historyItem, ...student.riwayat],
            );

            _syncStudentToFirebase(_studentCache[student.nim]!);
            _saveHistoryItemToFirebase(student.nim, historyItem);
            needNotify = true;
          } else {
            // Di bawah 10 menit, card tetap normal statusnya, hanya timer berjalan
            _studentCache[student.nim] =
                student.copyWith(currentSleepSeconds: newSeconds);
            needNotify = true;
          }
        }
      }

      if (needNotify) {
        _notifyListeners();
      }
    });
  }

  /// Memulai atau memperbarui pose tidur mahasiswa dari inferensi sensor/CCTV
  void setStudentSleepingPose({
    required String studentId,
    required bool isSleeping,
    String? cctvImageUrl,
  }) {
    final student = _studentCache[studentId];
    if (student == null) return;

    if (isSleeping) {
      if (!student.isSleepingNow) {
        // Mulai sesi tidur baru
        _studentCache[studentId] = student.copyWith(
          isSleepingNow: true,
          currentSleepSeconds: 0,
          hasCapturedThisSession: false,
          previousStatus: student.status != 'Tertidur'
              ? student.status
              : (student.previousStatus ?? 'Hadir'),
          aktivitasTerakhir: 'Menunduk / Terlelap',
        );
        _notifyListeners();
      }
    } else {
      // Mahasiswa bangun: panggil handler wake up
      recordWakeUpEvent(studentId: studentId);
    }
  }

  /// Mencatat kejadian valid tertidur (akumulasi >= 10 menit) secara langsung
  Future<bool> recordSleepEvent({
    required String studentId,
    required String imageUrl,
    int durationMinutes = 10,
  }) async {
    final student = _studentCache[studentId];
    if (student == null) return false;

    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm:ss').format(now) + ' WIB';

    final historyItem = AttendanceHistoryItem(
      id: 'sleep_${now.millisecondsSinceEpoch}',
      studentId: studentId,
      type: 'tidur',
      timestamp: now,
      evidenceUrl: imageUrl,
      evidenceType: 'cctv_capture',
      note: 'Valid Tertidur: Akumulasi tidur mencapai $durationMinutes menit',
      createdBy: 'system',
      durationMinutes: durationMinutes,
    );

    final updatedRiwayat = [historyItem, ...student.riwayat];

    final updated = student.copyWith(
      status: 'Tertidur',
      previousStatus: student.status != 'Tertidur'
          ? student.status
          : (student.previousStatus ?? 'Hadir'),
      jamKejadianTerakhir: timeStr,
      lastCaptureUrl: imageUrl,
      isSleepingNow: true,
      currentSleepSeconds: durationMinutes * 60,
      totalTidurMenitHariIni:
          student.totalTidurMenitHariIni + durationMinutes,
      aktivitasTerakhir: 'Tertidur / Menunduk ($durationMinutes menit)',
      hasCapturedThisSession: true,
      riwayat: updatedRiwayat,
    );

    _studentCache[studentId] = updated;
    _notifyListeners();
    await _syncStudentToFirebase(updated);
    await _saveHistoryItemToFirebase(studentId, historyItem);
    return true;
  }

  /// Saat mahasiswa bangun:
  /// Timer berhenti, akumulasi tetap tersimpan, dan card kembali normal ke status sebelumnya
  Future<void> recordWakeUpEvent({required String studentId}) async {
    final student = _studentCache[studentId];
    if (student == null) return;

    final sessionMinutes = student.currentSleepMinutes;
    final targetStatus = student.previousStatus ?? 'Hadir';
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm:ss').format(now) + ' WIB';

    final updated = student.copyWith(
      status: targetStatus,
      isSleepingNow: false,
      currentSleepSeconds: 0,
      hasCapturedThisSession: false,
      jamKejadianTerakhir: timeStr,
      aktivitasTerakhir: 'Memperhatikan Materi',
      totalTidurMenitHariIni:
          student.totalTidurMenitHariIni + sessionMinutes,
      previousStatus: null,
    );

    _studentCache[studentId] = updated;
    _notifyListeners();
    await _syncStudentToFirebase(updated);
  }

  /// Akumulasi Total 1 Hari dan Penyimpanan ke Pelaporan
  /// Jika sudah lewat 1 hari, sistem mengakumulasi semua durasi tidur dan menyimpannya di pelaporan.
  Future<void> checkAndRollOverDailySleepReport() async {
    final today = _todayKey;
    final db = _db;

    for (var student in _studentCache.values) {
      if (student.lastReportDate != null && student.lastReportDate != today) {
        final yesterday = student.lastReportDate!;
        final totalSleepMinutes = student.totalTidurMenitHariIni;

        // Arsipkan pelaporan harian ke node Firebase
        if (db != null) {
          try {
            await db.ref('pelaporan_tidur_harian/${student.nim}/$yesterday').set({
              'nim': student.nim,
              'nama': student.nama,
              'tanggal': yesterday,
              'total_tidur_menit': totalSleepMinutes,
              'status_akhir': student.status,
              'diarsipkan_pada': DateTime.now().toIso8601String(),
            }).timeout(_timeout);
          } catch (e) {
            debugPrint('[PresensiService] Arsip pelaporan error: $e');
          }
        }

        // Reset akumulasi harian untuk hari baru
        final updated = student.copyWith(
          lastReportDate: today,
          accumulatedReportMinutes:
              student.accumulatedReportMinutes + totalSleepMinutes,
          totalTidurMenitHariIni: 0,
          currentSleepSeconds: 0,
          isSleepingNow: false,
        );
        _studentCache[student.nim] = updated;
        await _syncStudentToFirebase(updated);
      }
    }
    _notifyListeners();
  }

  // ===========================================================================
  // 6. SYNC KE FIREBASE REALTIME DATABASE
  // ===========================================================================
  Future<void> _syncStudentToFirebase(MahasiswaPresensi m) async {
    final db = _db;
    if (db == null) return;
    try {
      final ref = db.ref('presensi/$_todayKey/mahasiswa/${m.nim}');
      await ref.set(m.toJson()).timeout(_timeout);
    } catch (e) {
      debugPrint('[PresensiService] sync to Firebase failed: $e');
    }
  }

  Future<void> _saveHistoryItemToFirebase(
      String studentId, AttendanceHistoryItem item) async {
    final db = _db;
    if (db == null) return;
    try {
      final ref = db.ref('riwayat_presensi/$studentId/${item.id}');
      await ref.set(item.toJson()).timeout(_timeout);
    } catch (e) {
      debugPrint('[PresensiService] save history to Firebase failed: $e');
    }
  }

  // Mengambil riwayat lengkap mahasiswa dari Firebase
  Future<List<AttendanceHistoryItem>> fetchStudentHistory(
      String studentId) async {
    final student = _studentCache[studentId];
    if (student != null && student.riwayat.isNotEmpty) {
      return student.riwayat;
    }

    final db = _db;
    if (db != null) {
      try {
        final snap = await db
            .ref('riwayat_presensi/$studentId')
            .get()
            .timeout(_timeout);
        if (snap.exists && snap.value is Map) {
          final map = snap.value as Map;
          final list = map.values
              .map((v) => AttendanceHistoryItem.fromJson(
                  Map<String, dynamic>.from(v as Map)))
              .toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        }
      } catch (e) {
        debugPrint('[PresensiService] fetchHistory error: $e');
      }
    }
    return student?.riwayat ?? [];
  }
}
