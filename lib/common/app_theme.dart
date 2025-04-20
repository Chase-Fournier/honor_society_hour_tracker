import 'package:flutter/material.dart';
import 'app_design.dart';

/// Main theme configuration for the application
class AppTheme {
  static ThemeData createThemeData(Color primaryColor, {bool isDark = false}) {
    // Create a ColorScheme based on the primary color
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
    
    // Base theme with Material 3
    final baseTheme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
    
    // Define text theme
    final textTheme = baseTheme.textTheme.copyWith(
      titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
        height: 1.5,
      ),
    );
    
    // Create custom theme with standardized components
    return baseTheme.copyWith(
      textTheme: textTheme,
      
      // Card theme
      cardTheme: CardTheme(
        elevation: AppDesign.elevationSmall,
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.borderLarge,
        ),
        clipBehavior: Clip.antiAlias,
      ),
      
      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: AppDesign.spacingM,
            horizontal: AppDesign.spacingL,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppDesign.borderMedium,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: AppDesign.spacingM,
            horizontal: AppDesign.spacingL,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppDesign.borderMedium,
          ),
        ),
      ),
      
      // Dialog theme
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.borderLarge,
        ),
        elevation: AppDesign.elevationMedium,
      ),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: AppDesign.elevationNone,
        scrolledUnderElevation: AppDesign.elevationSmall,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppDesign.radiusMedium),
          ),
        ),
      ),
      
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: AppDesign.borderMedium,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spacingM,
          vertical: AppDesign.spacingM,
        ),
      ),
      
      // Chip theme
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.borderSmall,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spacingS,
          vertical: AppDesign.spacingXS,
        ),
      ),
    );
  }
}