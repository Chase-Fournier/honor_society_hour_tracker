import 'package:flutter/material.dart';
import 'app_design.dart';
import 'dart:ui';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Main theme configuration for the application
class AppTheme {
  // In app_theme.dart - Update createThemeData method
  static ThemeData createThemeData(Color primaryColor, {bool isDark = false}) {
    // Generate extended color scheme from seed color with more vibrant tones
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: isDark ? Brightness.dark : Brightness.light,
      // Increase contrast for more expressive appearance
      primary: primaryColor,
      primaryContainer: Color.alphaBlend(
          primaryColor.withOpacity(0.35), isDark ? Colors.black : Colors.white),
      secondary: HSLColor.fromColor(primaryColor)
          .withHue((HSLColor.fromColor(primaryColor).hue + 40) % 360)
          .toColor(),
      // Create a more vibrant tertiary color for accent elements
      tertiary: HSLColor.fromColor(primaryColor)
          .withLightness(0.7)
          .withSaturation(0.8)
          .toColor(),
    );

    // More expressive base theme with Material 3
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,

      // Enhanced text theme with more expressive typography
      textTheme: TextTheme(
        displayLarge: GoogleFonts.workSans(
          fontSize: 57,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.workSans(
          fontSize: 45,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        titleLarge: GoogleFonts.workSans(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.15,
        ),
        titleMedium: GoogleFonts.workSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        bodyLarge: GoogleFonts.workSans(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.workSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),

      // More expressive card design
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Updated button themes for pill-shaped designs
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          side: BorderSide(color: colorScheme.outline, width: 1.5),
        ),
      ),

      // Updated app bar with more expressive design
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface.withOpacity(0.95),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.workSans(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.primary),
      ),

      // More expressive dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        elevation: 3,
      ),

      // More expressive chip theme
      chipTheme: ChipThemeData(
        shape: StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: colorScheme.secondaryContainer,
        selectedColor: colorScheme.primary,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          color: colorScheme.onSecondaryContainer,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // Update floating action button to be more expressive
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        extendedPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
      ),
    );
  }
}
