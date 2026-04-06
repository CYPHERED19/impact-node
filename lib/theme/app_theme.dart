import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFF0D0D0F);
  static const Color cardBg = Color.fromRGBO(255, 255, 255, 0.05);
  static const Color cardBorder = Color.fromRGBO(255, 255, 255, 0.09);
  static const Color activeRed = Color(0xFFE24B4A);
  static const Color sosBtnBg = Color.fromRGBO(226, 75, 74, 0.85);
  static const Color safeGreen = Color(0xFF1D9E75);
  static const Color safeGreenLight = Color(0xFF5DCAA5);
  static const Color warningAmber = Color(0xFFEF9F27);
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF777777);
  static const Color label = Color(0xFF555555);
  static const Color navInactive = Color(0xFF555555);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.background,
        primary: AppColors.activeRed,
        secondary: AppColors.safeGreen,
        error: AppColors.activeRed,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -2,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
          labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.label,
            letterSpacing: 0.8,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.activeRed,
        unselectedItemColor: AppColors.navInactive,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),
    );
  }

  static TextStyle get labelStyle => const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.label,
        letterSpacing: 0.8,
      );
}
