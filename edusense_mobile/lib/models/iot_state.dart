class IoTState {
  final double suhu;
  final double kelembaban;
  final String modeKipas;
  final int kecepatanKipas;
  final String statusRuangan;

  IoTState({
    required this.suhu,
    required this.kelembaban,
    required this.modeKipas,
    required this.kecepatanKipas,
    required this.statusRuangan,
  });

  factory IoTState.fromJson(Map<String, dynamic> json) {
    return IoTState(
      suhu: (json['suhu'] is num) ? (json['suhu'] as num).toDouble() : 28.0,
      kelembaban: (json['kelembaban'] is num)
          ? (json['kelembaban'] as num).toDouble()
          : 60.0,
      modeKipas: json['mode_kipas'] ?? 'Auto',
      kecepatanKipas: json['kecepatan_kipas'] ?? 1,
      statusRuangan: json['status_ruangan'] ?? 'Normal',
    );
  }

  IoTState copyWith({
    double? suhu,
    double? kelembaban,
    String? modeKipas,
    int? kecepatanKipas,
    String? statusRuangan,
  }) {
    return IoTState(
      suhu: suhu ?? this.suhu,
      kelembaban: kelembaban ?? this.kelembaban,
      modeKipas: modeKipas ?? this.modeKipas,
      kecepatanKipas: kecepatanKipas ?? this.kecepatanKipas,
      statusRuangan: statusRuangan ?? this.statusRuangan,
    );
  }
}
