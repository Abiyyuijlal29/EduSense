import 'package:flutter/material.dart';

/// Indikator Tingkat Kekuatan Password (Prompt 8)
enum PasswordStrength { lemah, sedang, kuat }

/// Hasil Evaluasi Kata Sandi Real-Time Mengikuti Ketentuan Prompt 8:
/// 1. Minimal 8 karakter (Regex: ^.{8,}$)
/// 2. Minimal 1 huruf kapital (Regex: [A-Z])
/// 3. Minimal 1 huruf kecil (Regex: [a-z])
/// 4. Minimal 1 angka (Regex: [0-9])
/// 5. Tanpa spasi (Regex: ^\S+$)
class PasswordValidationResult {
  final String password;

  PasswordValidationResult(this.password);

  /// 1. Minimal 8 Karakter
  bool get hasMinLength => password.length >= 8;

  /// 2. Minimal 1 Huruf Kapital (A-Z)
  bool get hasUppercase => RegExp(r'[A-Z]').hasMatch(password);

  /// 3. Minimal 1 Huruf Kecil (a-z)
  bool get hasLowercase => RegExp(r'[a-z]').hasMatch(password);

  /// 4. Minimal 1 Angka (0-9)
  bool get hasNumber => RegExp(r'[0-9]').hasMatch(password);

  /// 5. Tanpa Spasi
  bool get hasNoSpaces => !password.contains(' ') && password.isNotEmpty;

  /// Bonus: Simbol/Karakter Khusus opsional untuk penguatan
  bool get hasSpecialChar =>
      RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(password);

  /// Status validasi lengkap sesuai 5 aturan wajib Prompt 8
  bool get isValid =>
      hasMinLength &&
      hasUppercase &&
      hasLowercase &&
      hasNumber &&
      hasNoSpaces;

  /// Jumlah kriteria terpenuhi (0 s/d 5)
  int get metCriteriaCount {
    if (password.isEmpty) return 0;
    int count = 0;
    if (hasMinLength) count++;
    if (hasUppercase) count++;
    if (hasLowercase) count++;
    if (hasNumber) count++;
    if (hasNoSpaces) count++;
    return count;
  }

  /// Indikator Kekuatan Password:
  /// - Lemah (1-2 kriteria)
  /// - Sedang (3-4 kriteria)
  /// - Kuat (5 kriteria terpenuhi)
  PasswordStrength get strength {
    if (password.isEmpty) return PasswordStrength.lemah;
    final count = metCriteriaCount;
    if (count <= 2) return PasswordStrength.lemah;
    if (count <= 4) return PasswordStrength.sedang;
    return PasswordStrength.kuat;
  }

  String get strengthLabel {
    if (password.isEmpty) return '-';
    switch (strength) {
      case PasswordStrength.lemah:
        return 'Lemah';
      case PasswordStrength.sedang:
        return 'Sedang';
      case PasswordStrength.kuat:
        return 'Kuat';
    }
  }

  Color get strengthColor {
    if (password.isEmpty) return const Color(0xFF94A3B8);
    switch (strength) {
      case PasswordStrength.lemah:
        return const Color(0xFFEF4444); // Merah
      case PasswordStrength.sedang:
        return const Color(0xFFF59E0B); // Kuning / Amber
      case PasswordStrength.kuat:
        return const Color(0xFF10B981); // Hijau
    }
  }

  double get strengthFraction {
    if (password.isEmpty) return 0.0;
    switch (strength) {
      case PasswordStrength.lemah:
        return 0.33;
      case PasswordStrength.sedang:
        return 0.66;
      case PasswordStrength.kuat:
        return 1.0;
    }
  }
}

/// Fungsi Validator Reusable (Prompt 8) beserta Regex & Pesan Error Bahasa Indonesia
class AuthValidators {
  static const int nipLength = 18;

  // Regex Patterns
  static final RegExp regexNip = RegExp(r'^[0-9]+$');
  static final RegExp regexEmail =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  static final RegExp regexUppercase = RegExp(r'[A-Z]');
  static final RegExp regexLowercase = RegExp(r'[a-z]');
  static final RegExp regexNumber = RegExp(r'[0-9]');

  /// Validasi Nama Lengkap: Wajib diisi, minimal 3 karakter
  static String? validateNamaLengkap(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama lengkap wajib diisi';
    }
    if (value.trim().length < 3) {
      return 'Nama lengkap minimal 3 karakter';
    }
    return null;
  }

  /// Validasi NIP: Wajib diisi, hanya angka, dan tepat 18 digit
  static String? validateNip(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'NIP wajib diisi';
    }
    final trimmed = value.trim();
    if (!regexNip.hasMatch(trimmed)) {
      return 'NIP hanya boleh berisi angka';
    }
    if (trimmed.length != nipLength) {
      return 'NIP wajib 18 digit angka (saat ini ${trimmed.length} digit)';
    }
    return null;
  }

  /// Validasi Email: Wajib diisi dan format email valid
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email wajib diisi';
    }
    final trimmed = value.trim();
    if (!regexEmail.hasMatch(trimmed)) {
      return 'Format email tidak valid (contoh: dosen@polije.ac.id)';
    }
    return null;
  }

  /// Validasi Password Sesuai Prompt 8:
  /// - Minimal 8 karakter
  /// - Minimal 1 huruf kapital
  /// - Minimal 1 huruf kecil
  /// - Minimal 1 angka
  /// - Tanpa spasi
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password wajib diisi';
    }
    final result = PasswordValidationResult(value);
    if (!result.hasNoSpaces) {
      return 'Password tidak boleh mengandung spasi';
    }
    if (!result.hasMinLength) {
      return 'Password minimal 8 karakter';
    }
    if (!result.hasUppercase) {
      return 'Password harus mengandung minimal 1 huruf kapital (A-Z)';
    }
    if (!result.hasLowercase) {
      return 'Password harus mengandung minimal 1 huruf kecil (a-z)';
    }
    if (!result.hasNumber) {
      return 'Password harus mengandung minimal 1 angka (0-9)';
    }
    return null;
  }

  /// Validasi Ulangi Password: Wajib sama dengan password
  static String? validateConfirmPassword(
      String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Ulangi password wajib diisi';
    }
    if (password != confirmPassword) {
      return 'Password dan ulangi password harus sama';
    }
    return null;
  }

  /// Evaluasi detail password untuk visual checklist & meter kekuatan
  static PasswordValidationResult evaluatePassword(String password) {
    return PasswordValidationResult(password);
  }
}
