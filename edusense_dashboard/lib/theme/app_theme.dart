import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryLight = Color(0xFFEBF0FF);
  static const Color accent = Color(0xFF0EA5E9);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color purple = Color(0xFF8B5CF6);

  static const Color sidebarBg = Color(0xFFF8FAFC);
  static const Color contentBg = Color(0xFFF1F5F9);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color headerBg = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textWhite = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  static const Color sidebarSelected = Color(0xFF1A56DB);
  static const Color sidebarSelectedText = Color(0xFFFFFFFF);
  static const Color sidebarText = Color(0xFF475569);

  static const Color chartLine = Color(0xFF1A56DB);
  static const Color chartLineDash = Color(0xFF94A3B8);
  static const Color chartGrid = Color(0xFFE2E8F0);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.contentBg,
      fontFamily: 'Inter',
      useMaterial3: true,
      cardTheme: const CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
    );
  }
}
