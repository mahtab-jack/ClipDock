import 'package:flutter/material.dart';

class AppColors {
  // Pure AMOLED Dark Palette (True Pitch Black)
  static const Color darkGlassBg = Color(0x80000000); // Pure AMOLED black glass
  static const Color darkGlassSurface = Color(0x66121212); // Pure AMOLED surface
  static const Color darkGlassCard = Color(0x59181818); // Deep AMOLED card
  static const Color darkGlassCardHover = Color(0x8C262626); // Hover state
  static const Color darkBorder = Color(0x66404040); // Crisp dark border
  static const Color darkBorderSubtle = Color(0x332E2E2E); // Subtle separator
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // Pure white high-contrast
  static const Color darkTextSecondary = Color(0xFFA3A3A3); // Crisp silvery gray
  static const Color darkHandle = Color(0xFFE5E5E5); // Silver handle
  static const Color silverGlow = Color(0xFFFFFFFF);

  // Silvery High-Transparency Light palette
  static const Color lightGlassBg = Color(0x66F1F5F9); // ~40% opacity
  static const Color lightGlassSurface = Color(0x66FFFFFF); // ~40% opacity
  static const Color lightGlassCard = Color(0x4DE2E8F0); // ~30% opacity
  static const Color lightGlassCardHover = Color(0x73CBD5E1);
  static const Color lightBorder = Color(0x6694A3B8);
  static const Color lightBorderSubtle = Color(0x3D94A3B8);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightHandle = Color(0xFF64748B);

  // Accents
  static const Color accentSilver = Color(0xFFCBD5E1);
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color accentBlue = Color(0xFF38BDF8);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentAmber = Color(0xFFF59E0B);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentSilver,
        surface: AppColors.darkGlassSurface,
        onSurface: AppColors.darkTextPrimary,
        outline: AppColors.darkBorder,
      ),
      fontFamily: 'Google Sans',
      fontFamilyFallback: const ['Product Sans', 'Roboto', 'Segoe UI', 'sans-serif'],
      cardTheme: CardThemeData(
        color: AppColors.darkGlassCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.darkBorderSubtle, width: 1),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xF2000000),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.darkBorderSubtle, width: 1),
        ),
        textStyle: const TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightHandle,
        surface: AppColors.lightGlassSurface,
        onSurface: AppColors.lightTextPrimary,
        outline: AppColors.lightBorder,
      ),
      fontFamily: 'Google Sans',
      fontFamilyFallback: const ['Product Sans', 'Roboto', 'Segoe UI', 'sans-serif'],
      cardTheme: CardThemeData(
        color: AppColors.lightGlassCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.lightBorderSubtle, width: 1),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xD90F172A),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
