import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Forest & Cream palette — matches high-fidelity Muzhir home / weather design.
class MuzhirColors {
  MuzhirColors._();

  /// Deep forest green — primary CTAs, weather card, map healthy pins.
  static const Color forestGreen = Color(0xFF436639);

  /// Light cream — scaffold, app bar, page background.
  static const Color creamScaffold = Color(0xFFF9FBF7);

  /// Deep charcoal — headings and on-surface titles.
  static const Color titleCharcoal = Color(0xFF1D1D1D);

  /// Bottom nav icons when unselected — readable on cream.
  static const Color navBarUnselected = Color(0xFF707070);

  /// Pure white — elevated cards (stats, tiles).
  static const Color cardWhite = Color(0xFFFFFFFF);

  /// Mint chip fill — circular icon wells on the weather card.
  static const Color weatherIconCircle = Color(0xFFE0E8D9);

  /// Stronger sage — Healthy stat-card icon circle (visible on white).
  static const Color statHealthyIconWell = Color(0xFFC5D4B8);

  /// Soft fill behind the active [NavigationBar] indicator (M3 oval).
  static const Color navIndicatorFill = Color(0xFFE8F0E4);

  /// Earthy red — errors and diseased map markers.
  static const Color earthyClayRed = Color(0xFFB22222);

  // Legacy / semantic aliases (widgets reference these names).
  static const Color darkOliveGreen = forestGreen;
  static const Color midnightTechGreen = Color(0xFF304B2C);
  static const Color coreLeafGreen = forestGreen;
  static const Color vividSprout = weatherIconCircle;
  static const Color luminousLime = Color(0xFFE8EEDF);
  static const Color deepCharcoal = titleCharcoal;
  static const Color surface = creamScaffold;
  static const Color white = cardWhite;
  static const Color mutedGrey = Color(0xFF6B6B6B);
  static const Color tanSand = Color(0xFFC4D0B8);
  static const Color warmCream = creamScaffold;
  static const Color infectionSeriousOrange = Color(0xFFBC6C25);
  static const Color mapUserLocationBlue = Color(0xFF4A7C9E);
  static const Color materialError = earthyClayRed;
}

@immutable
class MuzhirFeatureColors extends ThemeExtension<MuzhirFeatureColors> {
  const MuzhirFeatureColors({required this.mapUserLocationBlue});

  final Color mapUserLocationBlue;

  static const light = MuzhirFeatureColors(
    mapUserLocationBlue: MuzhirColors.mapUserLocationBlue,
  );

  @override
  MuzhirFeatureColors copyWith({Color? mapUserLocationBlue}) {
    return MuzhirFeatureColors(
      mapUserLocationBlue: mapUserLocationBlue ?? this.mapUserLocationBlue,
    );
  }

  @override
  MuzhirFeatureColors lerp(ThemeExtension<MuzhirFeatureColors>? other, double t) {
    if (other is! MuzhirFeatureColors) return this;
    return MuzhirFeatureColors(
      mapUserLocationBlue:
          Color.lerp(mapUserLocationBlue, other.mapUserLocationBlue, t)!,
    );
  }
}

/// Material 3 [ThemeData] for Muzhir (Forest & Cream).
class MuzhirTheme {
  MuzhirTheme._();

  static const double _cardRadius = 24.0;

  static ThemeData get lightTheme {
    const primary = MuzhirColors.forestGreen;
    const cream = MuzhirColors.creamScaffold;
    const onSurface = MuzhirColors.titleCharcoal;
    const error = MuzhirColors.earthyClayRed;

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: MuzhirColors.cardWhite,
      primaryContainer: MuzhirColors.weatherIconCircle,
      onPrimaryContainer: const Color(0xFF2A3D26),
      secondary: MuzhirColors.tanSand,
      onSecondary: onSurface,
      secondaryContainer: MuzhirColors.weatherIconCircle.withValues(alpha: 0.65),
      onSecondaryContainer: const Color(0xFF3D4A38),
      tertiary: MuzhirColors.infectionSeriousOrange,
      onTertiary: MuzhirColors.cardWhite,
      error: error,
      onError: MuzhirColors.cardWhite,
      surface: cream,
      onSurface: onSurface,
      onSurfaceVariant: MuzhirColors.mutedGrey,
      outline: primary.withValues(alpha: 0.28),
      outlineVariant: MuzhirColors.mutedGrey.withValues(alpha: 0.22),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: MuzhirColors.midnightTechGreen,
      onInverseSurface: cream,
      inversePrimary: MuzhirColors.luminousLime,
      surfaceTint: primary.withValues(alpha: 0.06),
    );

    TextStyle lexend(double size, FontWeight weight, {Color? color}) {
      return GoogleFonts.lexend(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
    }

    final textTheme = GoogleFonts.lexendTextTheme().copyWith(
      headlineLarge: lexend(28, FontWeight.w700, color: onSurface),
      headlineMedium: lexend(22, FontWeight.w700, color: onSurface),
      titleLarge: lexend(18, FontWeight.w700, color: onSurface),
      titleMedium: lexend(16, FontWeight.w600, color: onSurface),
      bodyLarge: lexend(16, FontWeight.w500, color: onSurface),
      bodyMedium: lexend(14, FontWeight.w500, color: onSurface),
      bodySmall: lexend(12, FontWeight.w500, color: MuzhirColors.mutedGrey),
      labelLarge: lexend(14, FontWeight.w600, color: MuzhirColors.cardWhite),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: primary,
      extensions: const [MuzhirFeatureColors.light],
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: cream,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: onSurface.withValues(alpha: 0.85), size: 26),
        actionsIconTheme: IconThemeData(color: onSurface.withValues(alpha: 0.85), size: 26),
        titleTextStyle: lexend(20, FontWeight.w700, color: onSurface),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cream,
        elevation: 0,
        selectedItemColor: primary,
        unselectedItemColor: MuzhirColors.navBarUnselected,
        type: BottomNavigationBarType.fixed,
        selectedIconTheme: const IconThemeData(size: 29),
        unselectedIconTheme: const IconThemeData(size: 26),
        selectedLabelStyle: GoogleFonts.lexend(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.lexend(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      /// Material 3 bar with oval indicator ([NavigationBar] — see [MainScaffold]).
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cream,
        elevation: 0,
        height: 72,
        indicatorColor: MuzhirColors.navIndicatorFill,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 28);
          }
          return const IconThemeData(
            color: MuzhirColors.navBarUnselected,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = GoogleFonts.lexend(fontSize: 12);
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            );
          }
          return base.copyWith(
            color: MuzhirColors.navBarUnselected,
            fontWeight: FontWeight.w600,
          );
        }),
      ),

      cardTheme: CardThemeData(
        color: MuzhirColors.cardWhite,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: MuzhirColors.cardWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.lexend(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.85), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.lexend(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: MuzhirColors.cardWhite,
        elevation: 2,
        highlightElevation: 4,
        shape: StadiumBorder(),
      ),

      scaffoldBackgroundColor: cream,
    );
  }
}
