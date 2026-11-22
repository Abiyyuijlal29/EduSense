class UserDosen {
  final String nip;
  final String nama;
  final String email;
  final String programStudi;
  final String mataKuliah;
  final String kelasAktif;
  final String? fotoUrl;

  UserDosen({
    required this.nip,
    required this.nama,
    required this.email,
    required this.programStudi,
    required this.mataKuliah,
    required this.kelasAktif,
    this.fotoUrl,
  });

  factory UserDosen.fromJson(Map<String, dynamic> json) {
    return UserDosen(
      nip: json['nip'] ?? '',
      nama: json['nama'] ?? '',
      email: json['email'] ?? '',
      programStudi: json['program_studi'] ?? '',
      mataKuliah: json['mata_kuliah'] ?? '',
      kelasAktif: json['kelas_aktif'] ?? '',
      fotoUrl: json['foto_url'] ?? json['fotoUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nip': nip,
      'nama': nama,
      'email': email,
      'program_studi': programStudi,
      'mata_kuliah': mataKuliah,
      'kelas_aktif': kelasAktif,
      'foto_url': fotoUrl,
    };
  }

  UserDosen copyWith({
    String? nip,
    String? nama,
    String? email,
    String? programStudi,
    String? mataKuliah,
    String? kelasAktif,
    String? fotoUrl,
  }) {
    return UserDosen(
      nip: nip ?? this.nip,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      programStudi: programStudi ?? this.programStudi,
      mataKuliah: mataKuliah ?? this.mataKuliah,
      kelasAktif: kelasAktif ?? this.kelasAktif,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }
}
