import 'attendance_history.dart';

class MahasiswaPresensi {
  final String nim;
  final String nama;
  final String jamKehadiran;
  final String jamKejadianTerakhir;
  final String status; // Alpha, Hadir, Terlambat, Sakit, Izin, Tertidur
  final String aktivitasTerakhir;
  final String? lastCaptureUrl;
  final int totalTidurMenitHariIni;
  final bool isManualOverride;
  final String? previousStatus; // Disimpan saat status berubah jadi Tertidur
  final List<AttendanceHistoryItem> riwayat;

  // State real-time durasi tidur berjalan (Prompt 4: Validasi Tidur)
  final bool isSleepingNow;
  final int currentSleepSeconds;
  final bool hasCapturedThisSession;
  final String? lastReportDate;
  final int accumulatedReportMinutes;

  MahasiswaPresensi({
    required this.nim,
    required this.nama,
    required this.jamKehadiran,
    String? jamKejadianTerakhir,
    required this.status,
    required this.aktivitasTerakhir,
    this.lastCaptureUrl,
    this.totalTidurMenitHariIni = 0,
    this.isManualOverride = false,
    this.previousStatus,
    List<AttendanceHistoryItem>? riwayat,
    this.isSleepingNow = false,
    this.currentSleepSeconds = 0,
    this.hasCapturedThisSession = false,
    this.lastReportDate,
    this.accumulatedReportMinutes = 0,
  })  : jamKejadianTerakhir = jamKejadianTerakhir ?? jamKehadiran,
        riwayat = riwayat ?? [];

  /// Menghitung menit tidur dari detik berjalan saat ini
  int get currentSleepMinutes => currentSleepSeconds ~/ 60;

  /// Format MM:SS untuk timer berjalan di card
  String get runningSleepTimerFormatted {
    final m = currentSleepSeconds ~/ 60;
    final s = currentSleepSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  factory MahasiswaPresensi.fromJson(Map<String, dynamic> json) {
    // Parse riwayat jika ada
    List<AttendanceHistoryItem> parsedRiwayat = [];
    if (json['riwayat'] != null) {
      if (json['riwayat'] is Map) {
        final map = json['riwayat'] as Map;
        parsedRiwayat = map.values
            .map((v) => AttendanceHistoryItem.fromJson(
                Map<String, dynamic>.from(v as Map)))
            .toList();
      } else if (json['riwayat'] is List) {
        final list = json['riwayat'] as List;
        parsedRiwayat = list
            .map((v) => AttendanceHistoryItem.fromJson(
                Map<String, dynamic>.from(v as Map)))
            .toList();
      }
    }

    parsedRiwayat.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final rawStatus = (json['status'] ?? 'Alpha').toString();
    final jamMasuk = json['jam_kehadiran'] ?? json['jamKehadiran'] ?? '-';
    final jamTerakhir = json['jam_kejadian_terakhir'] ??
        json['jamKejadianTerakhir'] ??
        jamMasuk;

    int totalTidur = 0;
    if (json['total_tidur_menit_hari_ini'] != null) {
      totalTidur =
          int.tryParse(json['total_tidur_menit_hari_ini'].toString()) ?? 0;
    } else if (json['totalTidurMenitHariIni'] != null) {
      totalTidur =
          int.tryParse(json['totalTidurMenitHariIni'].toString()) ?? 0;
    }

    int currentSleepSec = 0;
    if (json['current_sleep_seconds'] != null) {
      currentSleepSec =
          int.tryParse(json['current_sleep_seconds'].toString()) ?? 0;
    }

    return MahasiswaPresensi(
      nim: json['nim'] ?? '',
      nama: json['nama'] ?? '',
      jamKehadiran: jamMasuk,
      jamKejadianTerakhir: jamTerakhir,
      status: _normalizeStatus(rawStatus),
      aktivitasTerakhir: json['aktivitas_terakhir'] ??
          json['aktivitasTerakhir'] ??
          'Memperhatikan',
      lastCaptureUrl: json['last_capture_url'] ?? json['lastCaptureUrl'],
      totalTidurMenitHariIni: totalTidur,
      isManualOverride:
          json['is_manual_override'] ?? json['isManualOverride'] ?? false,
      previousStatus: json['previous_status'] ?? json['previousStatus'],
      riwayat: parsedRiwayat,
      isSleepingNow:
          json['is_sleeping_now'] ?? json['isSleepingNow'] ?? false,
      currentSleepSeconds: currentSleepSec,
      hasCapturedThisSession: json['has_captured_this_session'] ?? false,
      lastReportDate: json['last_report_date'],
      accumulatedReportMinutes: json['accumulated_report_minutes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nim': nim,
      'nama': nama,
      'jam_kehadiran': jamKehadiran,
      'jam_kejadian_terakhir': jamKejadianTerakhir,
      'status': status,
      'aktivitas_terakhir': aktivitasTerakhir,
      'last_capture_url': lastCaptureUrl,
      'total_tidur_menit_hari_ini': totalTidurMenitHariIni,
      'is_manual_override': isManualOverride,
      'previous_status': previousStatus,
      'is_sleeping_now': isSleepingNow,
      'current_sleep_seconds': currentSleepSeconds,
      'has_captured_this_session': hasCapturedThisSession,
      'last_report_date': lastReportDate,
      'accumulated_report_minutes': accumulatedReportMinutes,
    };
  }

  static String _normalizeStatus(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower == 'hadir') return 'Hadir';
    if (lower == 'terlambat') return 'Terlambat';
    if (lower == 'sakit') return 'Sakit';
    if (lower == 'izin' || lower == 'dispensasi') return 'Izin';
    if (lower == 'tidur' || lower == 'tertidur') return 'Tertidur';
    return 'Alpha';
  }

  bool get isAlpha => status == 'Alpha';
  bool get isHadir => status == 'Hadir';
  bool get isTerlambat => status == 'Terlambat';
  bool get isSakit => status == 'Sakit';
  bool get isIzin => status == 'Izin';
  bool get isTertidur => status == 'Tertidur';

  MahasiswaPresensi copyWith({
    String? nim,
    String? nama,
    String? jamKehadiran,
    String? jamKejadianTerakhir,
    String? status,
    String? aktivitasTerakhir,
    String? lastCaptureUrl,
    int? totalTidurMenitHariIni,
    bool? isManualOverride,
    String? previousStatus,
    List<AttendanceHistoryItem>? riwayat,
    bool? isSleepingNow,
    int? currentSleepSeconds,
    bool? hasCapturedThisSession,
    String? lastReportDate,
    int? accumulatedReportMinutes,
  }) {
    return MahasiswaPresensi(
      nim: nim ?? this.nim,
      nama: nama ?? this.nama,
      jamKehadiran: jamKehadiran ?? this.jamKehadiran,
      jamKejadianTerakhir: jamKejadianTerakhir ?? this.jamKejadianTerakhir,
      status: status ?? this.status,
      aktivitasTerakhir: aktivitasTerakhir ?? this.aktivitasTerakhir,
      lastCaptureUrl: lastCaptureUrl ?? this.lastCaptureUrl,
      totalTidurMenitHariIni:
          totalTidurMenitHariIni ?? this.totalTidurMenitHariIni,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      previousStatus: previousStatus ?? this.previousStatus,
      riwayat: riwayat ?? this.riwayat,
      isSleepingNow: isSleepingNow ?? this.isSleepingNow,
      currentSleepSeconds: currentSleepSeconds ?? this.currentSleepSeconds,
      hasCapturedThisSession:
          hasCapturedThisSession ?? this.hasCapturedThisSession,
      lastReportDate: lastReportDate ?? this.lastReportDate,
      accumulatedReportMinutes:
          accumulatedReportMinutes ?? this.accumulatedReportMinutes,
    );
  }
}
