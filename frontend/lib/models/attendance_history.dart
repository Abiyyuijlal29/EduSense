class AttendanceHistoryItem {
  final String id;
  final String studentId; // NIM
  final String type; // hadir, terlambat, sakit, izin, tidur
  final DateTime timestamp;
  final String evidenceUrl;
  final String evidenceType; // cctv_capture, document
  final String? note;
  final String createdBy; // system, dosen
  final int? durationMinutes; // untuk tidur
  final String? dosenNameOrNip; // siapa yang override / mencatat

  AttendanceHistoryItem({
    required this.id,
    required this.studentId,
    required this.type,
    required this.timestamp,
    required this.evidenceUrl,
    required this.evidenceType,
    this.note,
    required this.createdBy,
    this.durationMinutes,
    this.dosenNameOrNip,
  });

  factory AttendanceHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime ts;
    try {
      ts = DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String());
    } catch (_) {
      ts = DateTime.now();
    }

    return AttendanceHistoryItem(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      studentId: json['student_id'] ?? json['studentId'] ?? '',
      type: (json['type'] ?? 'hadir').toString().toLowerCase(),
      timestamp: ts,
      evidenceUrl: json['evidence_url'] ?? json['evidenceUrl'] ?? '',
      evidenceType: json['evidence_type'] ?? json['evidenceType'] ?? 'cctv_capture',
      note: json['note'],
      createdBy: json['created_by'] ?? json['createdBy'] ?? 'system',
      durationMinutes: json['duration_minutes'] != null
          ? int.tryParse(json['duration_minutes'].toString())
          : null,
      dosenNameOrNip: json['dosen_name_or_nip'] ?? json['dosenNameOrNip'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'evidence_url': evidenceUrl,
      'evidence_type': evidenceType,
      'note': note,
      'created_by': createdBy,
      'duration_minutes': durationMinutes,
      'dosen_name_or_nip': dosenNameOrNip,
    };
  }

  String get typeLabel {
    switch (type.toLowerCase()) {
      case 'hadir':
        return 'Hadir';
      case 'terlambat':
        return 'Terlambat';
      case 'sakit':
        return 'Sakit';
      case 'izin':
      case 'dispensasi':
        return 'Dispensasi / Izin';
      case 'tidur':
        return 'Tidur';
      case 'alpha':
        return 'Alpha';
      default:
        return type;
    }
  }
}

