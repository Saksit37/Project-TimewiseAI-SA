import 'package:flutter/material.dart';

/// โทนสีหลักของแอป (ตรงกับต้นแบบใน Figma)
class AppColors {
  static const bg = Color(0xFFF4F2EC);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1A1D24);
  static const muted = Color(0xFF5B6070);
  static const line = Color(0xFFE3E0D8);
  static const accent = Color(0xFF0E6B63);
  static const accentSoft = Color(0xFFE1EFEC);
  static const high = Color(0xFFA63A12);
  static const highSoft = Color(0xFFF8E4D9);
  static const mid = Color(0xFF7A560A);
  static const midSoft = Color(0xFFF5ECD3);
  static const low = Color(0xFF3A6650);
  static const lowSoft = Color(0xFFE2EDE5);
  static const blue = Color(0xFF2A5DB0);
  static const blueSoft = Color(0xFFE3EAF7);
  static const graySoft = Color(0xFFECEAE4);
  static const segmentBg = Color(0xFFEAE7E0);
  static const chartPlanned = Color(0xFF2A6FDB);
  static const chartActual = Color(0xFFC9701A);
  static const sidebar = Color(0xFF12302D);
  static const avatar = Color(0xFFD8E6E3);
}

class AppText {
  static const title = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink);
  static const h2 = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink);
  static const body = TextStyle(fontSize: 14, color: AppColors.ink, height: 1.5);
  static const bodyStrong = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink);
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink);
  static const muted = TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5);
  static const small = TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5);
}

class AppTheme {
  static const fontFamily = 'IBMPlexSansThai';

  static ThemeData get light {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.line),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accent,
        surface: AppColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        errorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.high)),
        focusedErrorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.high, width: 1.5)),
        hintStyle: const TextStyle(color: AppColors.muted),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
    );
  }
}
