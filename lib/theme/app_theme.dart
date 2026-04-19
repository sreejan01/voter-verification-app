import 'package:flutter/material.dart';

class AppTheme {
  // ── Core Colors ──
  static const Color primary = Color(0xFF1A3E6E); // Government navy blue
  static const Color primaryLight = Color(0xFF2D5FA6); // Lighter navy
  static const Color accent = Color(0xFFE67E22); // Saffron accent
  static const Color success = Color(0xFF1A7A4A); // Government green
  static const Color danger = Color(0xFFC0392B); // Red for errors
  static const Color background = Color(0xFFF4F6F9); // Off-white background
  static const Color surface = Color(0xFFFFFFFF); // Card white
  static const Color textPrimary = Color(0xFF1A2B4A); // Dark navy text
  static const Color textSecondary = Color(0xFF6B7A94); // Grey text
  static const Color border = Color(0xFFDDE3ED); // Light border
  static const Color inputFill = Color(0xFFF0F4FA); // Input background

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: surface,
      error: danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
