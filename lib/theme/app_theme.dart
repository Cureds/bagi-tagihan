// lib/theme/app_theme.dart
// Semua warna, style, dan tema aplikasi di satu tempat.
// Kalau mau ganti warna/style, ubah di sini saja.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ─── Warna Utama ──────────────────────────────────────────────
  static const Color primaryBlue = Color(0xFF4169E1);
  static const Color primaryBlueDark = Color(0xFF3155CC);
  static const Color primaryBlueLight = Color(0xFFEEF2FF);

  // Background & Permukaan
  static const Color scaffoldBg = Color(0xFFF2F2F7); // iOS-style light gray
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color inputBg = Color(0xFFF8F8FC);

  // Teks
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textHint = Color(0xFFC7C7CC);

  // Tombol spesial
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color whatsappGreenDark = Color(0xFF1DA851);

  // Warna avatar peserta (merah, hijau, biru, oranye)
  static const Color avatarRed = Color(0xFFFF3B30);
  static const Color avatarGreen = Color(0xFF34C759);
  static const Color avatarBlue = Color(0xFF007AFF);
  static const Color avatarOrange = Color(0xFFFF9500);
  static const Color avatarPurple = Color(0xFFAF52DE);
  static const Color avatarPink = Color(0xFFFF2D55);

  // Daftar warna avatar (digunakan otomatis berdasarkan urutan join)
  static const List<Color> avatarColors = [
    avatarRed,
    avatarGreen,
    avatarBlue,
    avatarOrange,
    avatarPurple,
    avatarPink,
  ];

  // Divider
  static const Color divider = Color(0xFFE5E5EA);

  // ─── Theme Utama ──────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        surface: cardBg,
      ),
      scaffoldBackgroundColor: scaffoldBg,

      // App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(
          color: primaryBlue,
          size: 22,
        ),
      ),

      // Tombol Primary (biru solid)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Color(0xFFB0BEC5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          elevation: 0,
        ),
      ),

      // Tombol Outlined (putih dengan border)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: divider, width: 1.5),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),

      // Input field
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: textHint,
          fontSize: 17,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  // ─── Helper Widget Styles ──────────────────────────────────────
  
  // Card dengan shadow iOS-style
  static BoxDecoration get cardDecoration => const BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 2,
            offset: Offset(0, 0),
          ),
        ],
      );

  // Card tanpa shadow (untuk list item)
  static BoxDecoration get flatCardDecoration => const BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      );
}
