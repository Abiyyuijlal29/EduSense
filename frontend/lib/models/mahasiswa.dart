class MahasiswaPresensi {
  final String nim;
  final String nama;
  final String jamKehadiran;
  final String status;
  final String aktivitasTerakhir;

  MahasiswaPresensi({
    required this.nim,
    required this.nama,
    required this.jamKehadiran,
    required this.status,
    required this.aktivitasTerakhir,
  });

  factory MahasiswaPresensi.fromJson(Map<String, dynamic> json) {
    return MahasiswaPresensi(
      nim: json['nim'] ?? '',
      nama: json['nama'] ?? '',
      jamKehadiran: json['jam_kehadiran'] ?? '',
      status: json['status'] ?? 'Belum Hadir',
      aktivitasTerakhir: json['aktivitas_terakhir'] ?? 'Memperhatikan',
    );
  }

  bool get isTertidur => aktivitasTerakhir.toLowerCase().contains('tidur') ||
      aktivitasTerakhir.toLowerCase().contains('menunduk');
}
