import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Muzhir Brand Color Palette
/// "Nature meeting Technology" — Sustainable Agriculture theme.
class MuzhirColors {
  MuzhirColors._();

  // ── Primary Brand Colors ──────────────────────────────────────────
  /// Midnight Tech Green – headers, nav bars, footer backgrounds
  static const Color midnightTechGreen = Color(0xFF012623);

  /// Core Leaf Green – CTA buttons, links, active UI elements
  static const Color coreLeafGreen = Color(0xFF308C36);

  // ── Secondary & Accent Colors ─────────────────────────────────────
  /// Vivid Sprout – secondary buttons, icons, success, hover states
  static const Color vividSprout = Color(0xFF81BF54);

  /// Luminous Lime – highlights, badges, background accents
  static const Color luminousLime = Color(0xFFB6D96C);

  // ── Neutral Colors ────────────────────────────────────────────────
  /// Deep Charcoal – body text on light backgrounds, borders
  static const Color deepCharcoal = Color(0xFF0D0D0D);

  /// Off-white surface for cards and backgrounds
  static const Color surface = Color(0xFFF5F7F2);

  /// Pure white
  static const Color white = Color(0xFFFFFFFF);
}

/// Builds the Material 3 ThemeData for the Muzhir app.
class MuzhirTheme {
  MuzhirTheme._();

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: MuzhirColors.coreLeafGreen,
      brightness: Brightness.light,
      primary: MuzhirColors.coreLeafGreen,
      onPrimary: MuzhirColors.white,
      primaryContainer: MuzhirColors.luminousLime,
      onPrimaryContainer: MuzhirColors.midnightTechGreen,
      secondary: MuzhirColors.vividSprout,
      onSecondary: MuzhirColors.white,
      secondaryContainer: MuzhirColors.luminousLime.withValues(alpha: 0.3),
      surface: MuzhirColors.surface,
      onSurface: MuzhirColors.deepCharcoal,
      error: const Color(0xFFB3261E),
      onError: MuzhirColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // ── Typography ──────────────────────────────────────────────────
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        headlineLarge: GoogleFonts.cairo(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: MuzhirColors.midnightTechGreen,
        ),
        headlineMedium: GoogleFonts.cairo(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: MuzhirColors.midnightTechGreen,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: MuzhirColors.deepCharcoal,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: MuzhirColors.deepCharcoal,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: MuzhirColors.deepCharcoal,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: MuzhirColors.deepCharcoal,
        ),
        labelLarge: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: MuzhirColors.white,
        ),
      ),

      // ── AppBar ────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: MuzhirColors.midnightTechGreen,
        foregroundColor: MuzhirColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: MuzhirColors.white,
        ),
      ),

      // ── Bottom Navigation Bar ─────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: MuzhirColors.midnightTechGreen,
        selectedItemColor: MuzhirColors.luminousLime,
        unselectedItemColor: MuzhirColors.white.withValues(alpha: 0.55),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ── Cards ─────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: MuzhirColors.white,
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ── Elevated Button ───────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MuzhirColors.coreLeafGreen,
          foregroundColor: MuzhirColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Outlined Button ───────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MuzhirColors.coreLeafGreen,
          side: const BorderSide(color: MuzhirColors.coreLeafGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Floating Action Button ────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: MuzhirColors.coreLeafGreen,
        foregroundColor: MuzhirColors.white,
      ),

      // ── Scaffold ──────────────────────────────────────────────────
      scaffoldBackgroundColor: MuzhirColors.surface,
    );
  }
}
