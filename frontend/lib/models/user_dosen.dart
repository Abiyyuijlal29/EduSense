class UserDosen {
  final String nip;
  final String nama;
  final String email;
  final String programStudi;
  final String mataKuliah;
  final String kelasAktif;

  UserDosen({
    required this.nip,
    required this.nama,
    required this.email,
    required this.programStudi,
    required this.mataKuliah,
    required this.kelasAktif,
  });

  factory UserDosen.fromJson(Map<String, dynamic> json) {
    return UserDosen(
      nip: json['nip'] ?? '',
      nama: json['nama'] ?? '',
      email: json['email'] ?? '',
      programStudi: json['program_studi'] ?? '',
      mataKuliah: json['mata_kuliah'] ?? '',
      kelasAktif: json['kelas_aktif'] ?? '',
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
    };
  }
}
