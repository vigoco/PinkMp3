import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PinkSpotifyTheme {
  // Core colors
  static const Color primaryPink = Color(0xFFFF007F);
  static const Color bgTop = Color(0xFF000000);
  static const Color bgBottom = Color(0xFF2E003E);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFD1D1D1);

  // Gradients
  static const LinearGradient magentaGradient = LinearGradient(
    colors: [Color(0xFFFF3CAC), Color(0xFF784BA0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [bgTop, bgBottom],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData themeData() {
    final base = ThemeData.dark(useMaterial3: true);

    final colorScheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: primaryPink,
      primary: primaryPink,
      secondary: const Color(0xFF784BA0),
      surface: const Color(0xFF111015),
      background: bgTop,
      onPrimary: textPrimary,
      onSecondary: textPrimary,
      onSurface: textSecondary,
      onBackground: textPrimary,
    );

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      titleLarge: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      bodySmall: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary.withOpacity(0.8),
      ),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium,
        foregroundColor: textPrimary,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: primaryPink,
        inactiveTrackColor: Colors.white.withOpacity(0.15),
        thumbColor: primaryPink,
        overlayColor: const Color.fromRGBO(255, 0, 127, 0.25),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          foregroundColor: textPrimary,
          backgroundColor: Colors.transparent,
        ),
      ),
      iconTheme: const IconThemeData(color: textSecondary),
      useMaterial3: true,
    );
  }
}



