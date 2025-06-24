import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeMode { 
  light, 
  dark, 
  midnight,
  // Custom themes
  sunset,
  sunrise,
  fullMoon,
  forest,
  ocean,
  reef,
  cherry,
  lavender,
  autumn,
  winter,
  desert,
  galaxy,
  emerald,
  ruby,
  sapphire,
  amber,
}

class ThemeProvider extends ChangeNotifier {
  // Current theme mode
  ThemeMode _themeMode = ThemeMode.light;

  // Getter for theme mode
  ThemeMode get themeMode => _themeMode;

  // Convenience getters
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isMidnightMode => _themeMode == ThemeMode.midnight;
  bool get isCustomTheme => !isLightMode && !isDarkMode && !isMidnightMode;

  ThemeProvider() {
    loadThemePreference();
  }

  /// Sets theme to specified mode
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    saveThemePreference();
    notifyListeners();
  }

  /// Loads saved theme preference from SharedPreferences.
  /// Defaults to light theme if no preference is saved.
  ///
  /// Returns:
  /// - Future<void>
  Future<void> loadThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 0;
    if (themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  /// Persists current theme preference to SharedPreferences.
  ///
  /// Returns:
  /// - Future<void>
  Future<void> saveThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _themeMode.index);
  }

  /// Get display name for theme mode
  String getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.midnight:
        return 'Midnight';
      case ThemeMode.sunset:
        return 'Sunset';
      case ThemeMode.sunrise:
        return 'Sunrise';
      case ThemeMode.fullMoon:
        return 'Full Moon';
      case ThemeMode.forest:
        return 'Forest';
      case ThemeMode.ocean:
        return 'Ocean';
      case ThemeMode.reef:
        return 'Reef';
      case ThemeMode.cherry:
        return 'Cherry Blossom';
      case ThemeMode.lavender:
        return 'Lavender';
      case ThemeMode.autumn:
        return 'Autumn';
      case ThemeMode.winter:
        return 'Winter';
      case ThemeMode.desert:
        return 'Desert';
      case ThemeMode.galaxy:
        return 'Galaxy';
      case ThemeMode.emerald:
        return 'Emerald';
      case ThemeMode.ruby:
        return 'Ruby';
      case ThemeMode.sapphire:
        return 'Sapphire';
      case ThemeMode.amber:
        return 'Amber';
    }
  }

  /// Get theme description
  String getThemeDescription(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Clean and bright';
      case ThemeMode.dark:
        return 'Easy on the eyes';
      case ThemeMode.midnight:
        return 'Pure black background';
      case ThemeMode.sunset:
        return 'Warm oranges and pinks';
      case ThemeMode.sunrise:
        return 'Golden yellows and soft pinks';
      case ThemeMode.fullMoon:
        return 'Deep blues and silver';
      case ThemeMode.forest:
        return 'Natural greens and browns';
      case ThemeMode.ocean:
        return 'Deep blues and teals';
      case ThemeMode.reef:
        return 'Vibrant coral colors';
      case ThemeMode.cherry:
        return 'Soft pinks and whites';
      case ThemeMode.lavender:
        return 'Purple and violet tones';
      case ThemeMode.autumn:
        return 'Warm reds and golds';
      case ThemeMode.winter:
        return 'Cool blues and whites';
      case ThemeMode.desert:
        return 'Sandy browns and warm tones';
      case ThemeMode.galaxy:
        return 'Deep purples and cosmic blues';
      case ThemeMode.emerald:
        return 'Rich greens and jewel tones';
      case ThemeMode.ruby:
        return 'Deep reds and crimson';
      case ThemeMode.sapphire:
        return 'Royal blues and navy';
      case ThemeMode.amber:
        return 'Golden yellows and honey';
    }
  }

  /// Get theme icon
  IconData getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.midnight:
        return Icons.nightlight_round;
      case ThemeMode.sunset:
        return Icons.wb_twilight;
      case ThemeMode.sunrise:
        return Icons.wb_sunny;
      case ThemeMode.fullMoon:
        return Icons.brightness_2;
      case ThemeMode.forest:
        return Icons.forest;
      case ThemeMode.ocean:
        return Icons.waves;
      case ThemeMode.reef:
        return Icons.scuba_diving;
      case ThemeMode.cherry:
        return Icons.local_florist;
      case ThemeMode.lavender:
        return Icons.spa;
      case ThemeMode.autumn:
        return Icons.park;
      case ThemeMode.winter:
        return Icons.ac_unit;
      case ThemeMode.desert:
        return Icons.landscape;
      case ThemeMode.galaxy:
        return Icons.auto_awesome;
      case ThemeMode.emerald:
        return Icons.diamond;
      case ThemeMode.ruby:
        return Icons.favorite;
      case ThemeMode.sapphire:
        return Icons.water_drop;
      case ThemeMode.amber:
        return Icons.wb_incandescent;
    }
  }

  // Get theme data based on current mode
  ThemeData getThemeData(Color themeColor) {
    switch (_themeMode) {
      case ThemeMode.light:
        return _createLightTheme(themeColor);
      case ThemeMode.dark:
        return _createDarkTheme(themeColor);
      case ThemeMode.midnight:
        return _createMidnightTheme(themeColor);
      case ThemeMode.sunset:
        return _createSunsetTheme();
      case ThemeMode.sunrise:
        return _createSunriseTheme();
      case ThemeMode.fullMoon:
        return _createFullMoonTheme();
      case ThemeMode.forest:
        return _createForestTheme();
      case ThemeMode.ocean:
        return _createOceanTheme();
      case ThemeMode.reef:
        return _createReefTheme();
      case ThemeMode.cherry:
        return _createCherryTheme();
      case ThemeMode.lavender:
        return _createLavenderTheme();
      case ThemeMode.autumn:
        return _createAutumnTheme();
      case ThemeMode.winter:
        return _createWinterTheme();
      case ThemeMode.desert:
        return _createDesertTheme();
      case ThemeMode.galaxy:
        return _createGalaxyTheme();
      case ThemeMode.emerald:
        return _createEmeraldTheme();
      case ThemeMode.ruby:
        return _createRubyTheme();
      case ThemeMode.sapphire:
        return _createSapphireTheme();
      case ThemeMode.amber:
        return _createAmberTheme();
    }
  }

  // Standard themes
  ThemeData _createLightTheme(Color themeColor) {
    return ThemeData(
      colorSchemeSeed: themeColor,
      useMaterial3: true,
      brightness: Brightness.light,
    );
  }

  ThemeData _createDarkTheme(Color themeColor) {
    return ThemeData.dark().copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: themeColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }

  ThemeData _createMidnightTheme(Color themeColor) {
    return ThemeData.dark().copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: themeColor,
        brightness: Brightness.dark,
        background: const Color(0xFF000000),
        surface: const Color(0xFF121212),
        surfaceVariant: const Color(0xFF1C1C1C),
        surfaceContainerLowest: const Color(0xFF080808),
        primaryContainer: themeColor.withOpacity(0.1),
      ),
      scaffoldBackgroundColor: const Color(0xFF000000),
      canvasColor: const Color(0xFF121212),
      useMaterial3: true,
    );
  }

  // Custom themed designs
    ThemeData _createSunsetTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFFFF6B35),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFFFE4DC),
        onPrimaryContainer: Color(0xFF7D2A00),
        secondary: Color(0xFFE91E63),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFFFD8E4),
        onSecondaryContainer: Color(0xFF3E001A),
        tertiary: Color(0xFFFF9800),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFFFF3C4),
        onTertiaryContainer: Color(0xFF7F4A00),
        surface: Color(0xFFFFF8F5),
        onSurface: Color(0xFF362F2A),
        surfaceVariant: Color(0xFFF7DED4),
        onSurfaceVariant: Color(0xFF52443C),
        surfaceContainerHighest: Color(0xFFFFE8DD),
        surfaceContainer: Color(0xFFFFF0E8),
        surfaceContainerHigh: Color(0xFFFFF4EF),
        surfaceContainerLow: Color(0xFFFFFBF8),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFF85736B),
        outlineVariant: Color(0xFFD8C2B8),
      ),
    );
  }

  ThemeData _createSunriseTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFFFFB74D),
        onPrimary: Color(0xFF3E2723),
        primaryContainer: Color(0xFFFFF8E1),
        onPrimaryContainer: Color(0xFF8F4700),
        secondary: Color(0xFFFF8A65),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFFFE0DB),
        onSecondaryContainer: Color(0xFF8C2E00),
        tertiary: Color(0xFFFFD54F),
        onTertiary: Color(0xFF6D4C41),
        tertiaryContainer: Color(0xFFFFF9C4),
        onTertiaryContainer: Color(0xFF6D4C41),
        surface: Color(0xFFFFFBF0),
        onSurface: Color(0xFF3E2723),
        surfaceVariant: Color(0xFFFFE8D6),
        onSurfaceVariant: Color(0xFF5D4037),
        surfaceContainerHighest: Color(0xFFFFE4C9),
        surfaceContainer: Color(0xFFFFF2E5),
        surfaceContainerHigh: Color(0xFFFFF7EC),
        surfaceContainerLow: Color(0xFFFFFCF7),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFF8D6E63),
        outlineVariant: Color(0xFFD7CCC8),
      ),
    );
  }

  ThemeData _createFullMoonTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: Color(0xFF90CAF9),
        onPrimary: Color(0xFF1A237E),
        primaryContainer: Color(0xFF283593),
        onPrimaryContainer: Color(0xFFE8EAF6),
        secondary: Color(0xFFB39DDB),
        onSecondary: Color(0xFF4A148C),
        secondaryContainer: Color(0xFF6A1B9A),
        onSecondaryContainer: Color(0xFFF3E5F5),
        tertiary: Color(0xFF81D4FA),
        onTertiary: Color(0xFF01579B),
        tertiaryContainer: Color(0xFF0277BD),
        onTertiaryContainer: Color(0xFFE1F5FE),
        surface: Color(0xFF0F1419),
        onSurface: Color(0xFFE3F2FD),
        surfaceVariant: Color(0xFF1E2328),
        onSurfaceVariant: Color(0xFFBBDEFB),
        surfaceContainerHighest: Color(0xFF2A3036),
        surfaceContainer: Color(0xFF1A1F25),
        surfaceContainerHigh: Color(0xFF242931),
        surfaceContainerLow: Color(0xFF151A20),
        surfaceContainerLowest: Color(0xFF0A0F14),
        outline: Color(0xFF6E7882),
        outlineVariant: Color(0xFF42474E),
      ),
    );
  }

  ThemeData _createForestTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFF2E7D32),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFC8E6C9),
        onPrimaryContainer: Color(0xFF1B5E20),
        secondary: Color(0xFF388E3C),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFDCEDC8),
        onSecondaryContainer: Color(0xFF33691E),
        tertiary: Color(0xFF689F38),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFE7F3DF),
        onTertiaryContainer: Color(0xFF33691E),
        surface: Color(0xFFF1F8E9),
        onSurface: Color(0xFF1B5E20),
        surfaceVariant: Color(0xFFE8F5E8),
        onSurfaceVariant: Color(0xFF2E7D32),
        surfaceContainerHighest: Color(0xFFDCEDD3),
        surfaceContainer: Color(0xFFE8F4E3),
        surfaceContainerHigh: Color(0xFFEDF7E8),
        surfaceContainerLow: Color(0xFFF6FBED),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFF5D7F5F),
        outlineVariant: Color(0xFFC8E6C9),
      ),
    );
  }

  ThemeData _createOceanTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFF0277BD),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFB3E5FC),
        onPrimaryContainer: Color(0xFF01579B),
        secondary: Color(0xFF00ACC1),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFB2EBF2),
        onSecondaryContainer: Color(0xFF006064),
        tertiary: Color(0xFF0288D1),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFBBE7FF),
        onTertiaryContainer: Color(0xFF00447A),
        surface: Color(0xFFE0F8FF),
        onSurface: Color(0xFF01579B),
        surfaceVariant: Color(0xFFE1F5FE),
        onSurfaceVariant: Color(0xFF0277BD),
        surfaceContainerHighest: Color(0xFFC3E8F3),
        surfaceContainer: Color(0xFFD6F2FF),
        surfaceContainerHigh: Color(0xFFE5F6FF),
        surfaceContainerLow: Color(0xFFF0FAFF),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFF4A7C95),
        outlineVariant: Color(0xFF81D4FA),
      ),
    );
  }

  ThemeData _createReefTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFFFF7043),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFFFE0B2),
        onPrimaryContainer: Color(0xFFBF360C),
        secondary: Color(0xFF26A69A),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFB2DFDB),
        onSecondaryContainer: Color(0xFF004D40),
        tertiary: Color(0xFFAB47BC),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFE1BEE7),
        onTertiaryContainer: Color(0xFF6A1B9A),
        surface: Color(0xFFFFF3E0),
        onSurface: Color(0xFFBF360C),
        surfaceVariant: Color(0xFFFFE0B2),
        onSurfaceVariant: Color(0xFFFF7043),
        surfaceContainerHighest: Color(0xFFFFCCAE),
        surfaceContainer: Color(0xFFFFE6CC),
        surfaceContainerHigh: Color(0xFFFFF0E0),
        surfaceContainerLow: Color(0xFFFFF8F0),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFFB8906D),
        outlineVariant: Color(0xFFFFCC9A),
      ),
    );
  }

  ThemeData _createCherryTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFFE91E63),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFFFE4E1),
        onPrimaryContainer: Color(0xFF880E4F),
        secondary: Color(0xFFF06292),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFFFE0E6),
        onSecondaryContainer: Color(0xFFAD1457),
        tertiary: Color(0xFFFFB3BA),
        onTertiary: Color(0xFF4A2C2A),
        tertiaryContainer: Color(0xFFFFE7E9),
        onTertiaryContainer: Color(0xFF6D1B7B),
        surface: Color(0xFFFFF0F5),
        onSurface: Color(0xFF880E4F),
        surfaceVariant: Color(0xFFFCE4EC),
        onSurfaceVariant: Color(0xFFE91E63),
        surfaceContainerHighest: Color(0xFFF8D7E4),
        surfaceContainer: Color(0xFFFBE7ED),
        surfaceContainerHigh: Color(0xFFFDEEF3),
        surfaceContainerLow: Color(0xFFFEF7F9),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFFB85450),
        outlineVariant: Color(0xFFE1BEE7),
      ),
    );
  }

  ThemeData _createLavenderTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFF9C27B0),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFF3E5F5),
        onPrimaryContainer: Color(0xFF4A148C),
        secondary: Color(0xFFBA68C8),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFE1BEE7),
        onSecondaryContainer: Color(0xFF6A1B9A),
        tertiary: Color(0xFFCE93D8),
        onTertiary: Color(0xFF4A148C),
        tertiaryContainer: Color(0xFFF8E5FF),
        onTertiaryContainer: Color(0xFF7B1FA2),
        surface: Color(0xFFFAF4FF),
        onSurface: Color(0xFF4A148C),
        surfaceVariant: Color(0xFFF3E5F5),
        onSurfaceVariant: Color(0xFF9C27B0),
        surfaceContainerHighest: Color(0xFFE8D5EA),
        surfaceContainer: Color(0xFFF0E7F2),
        surfaceContainerHigh: Color(0xFFF5EEF7),
        surfaceContainerLow: Color(0xFFFAF6FB),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFF8E24AA),
        outlineVariant: Color(0xFFD1C4E9),
      ),
    );
  }

  ThemeData _createAutumnTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFFD84315),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFFFCCBC),
        onPrimaryContainer: Color(0xFFBF360C),
        secondary: Color(0xFFFF8F00),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFFFE0B2),
        onSecondaryContainer: Color(0xFFE65100),
        tertiary: Color(0xFFFFB300),
        onTertiary: Color(0xFF5D4037),
        tertiaryContainer: Color(0xFFFFF3C4),
        onTertiaryContainer: Color(0xFF6D4C41),
        surface: Color(0xFFFFF8E1),
        onSurface: Color(0xFFBF360C),
        surfaceVariant: Color(0xFFFFE8CC),
        onSurfaceVariant: Color(0xFFD84315),
        surfaceContainerHighest: Color(0xFFFFD4A3),
        surfaceContainer: Color(0xFFFFE4CC),
        surfaceContainerHigh: Color(0xFFFFF0DB),
        surfaceContainerLow: Color(0xFFFFFAED),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFFBF7434),
        outlineVariant: Color(0xFFDCC7A4),
      ),
    );
  }

  ThemeData _createWinterTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFF1976D2),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFE3F2FD),
        onPrimaryContainer: Color(0xFF0D47A1),
        secondary: Color(0xFF42A5F5),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFE1F5FE),
        onSecondaryContainer: Color(0xFF01579B),
        tertiary: Color(0xFF81D4FA),
        onTertiary: Color(0xFF01579B),
        tertiaryContainer: Color(0xFFE0F2F1),
        onTertiaryContainer: Color(0xFF0277BD),
        surface: Color(0xFFF8FBFF),
        onSurface: Color(0xFF0D47A1),
        surfaceVariant: Color(0xFFE8F4FD),
        onSurfaceVariant: Color(0xFF1976D2),
        surfaceContainerHighest: Color(0xFFD6EAF8),
        surfaceContainer: Color(0xFFE5F2FA),
        surfaceContainerHigh: Color(0xFFF0F7FB),
        surfaceContainerLow: Color(0xFFFAFCFE),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFF5E85AB),
        outlineVariant: Color(0xFFBBDEFB),
      ),
    );
  }

  ThemeData _createDesertTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFF8D6E63),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFEFEBE9),
        onPrimaryContainer: Color(0xFF5D4037),
        secondary: Color(0xFFBCAAA4),
        onSecondary: Color(0xFF4E342E),
        secondaryContainer: Color(0xFFD7CCC8),
        onSecondaryContainer: Color(0xFF6D4C41),
        tertiary: Color(0xFFA1887F),
        onTertiary: Color(0xFF4E342E),
        tertiaryContainer: Color(0xFFEDEAE8),
        onTertiaryContainer: Color(0xFF3E2723),
        surface: Color(0xFFFBF8F5),
        onSurface: Color(0xFF3E2723),
        surfaceVariant: Color(0xFFF3E5AB),
        onSurfaceVariant: Color(0xFF5D4037),
        surfaceContainerHighest: Color(0xFFE6D8C5),
        surfaceContainer: Color(0xFFF0E5D0),
        surfaceContainerHigh: Color(0xFFF7F0E5),
        surfaceContainerLow: Color(0xFFFCF9F5),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFF9E7B6A),
        outlineVariant: Color(0xFFD7CCC8),
      ),
    );
  }

  ThemeData _createGalaxyTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: Color(0xFF7C4DFF),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFF5E35B1),
        onPrimaryContainer: Color(0xFFE8EAF6),
        secondary: Color(0xFF448AFF),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFF303F9F),
        onSecondaryContainer: Color(0xFFE8EAF6),
        tertiary: Color(0xFF18FFFF),
        onTertiary: Color(0xFF006064),
        tertiaryContainer: Color(0xFF00838F),
        onTertiaryContainer: Color(0xFFE0F2F1),
        surface: Color(0xFF0A0A23),
        onSurface: Color(0xFFE8EAF6),
        surfaceVariant: Color(0xFF1A1A3A),
        onSurfaceVariant: Color(0xFFB39DDB),
        surfaceContainerHighest: Color(0xFF2E2E4F),
        surfaceContainer: Color(0xFF161633),
        surfaceContainerHigh: Color(0xFF242442),
        surfaceContainerLow: Color(0xFF10102A),
        surfaceContainerLowest: Color(0xFF06061A),
        outline: Color(0xFF6E6B93),
        outlineVariant: Color(0xFF4A4458),
      ),
    );
  }

  ThemeData _createEmeraldTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFF00695C),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFB2DFDB),
        onPrimaryContainer: Color(0xFF004D40),
        secondary: Color(0xFF26A69A),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFE0F2F1),
        onSecondaryContainer: Color(0xFF00695C),
        tertiary: Color(0xFF4DB6AC),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFE6FFFA),
        onTertiaryContainer: Color(0xFF004D40),
        surface: Color(0xFFE0F8F8),
        onSurface: Color(0xFF004D40),
        surfaceVariant: Color(0xFFB2DFDB),
        onSurfaceVariant: Color(0xFF00695C),
        surfaceContainerHighest: Color(0xFF9FCFCB),
        surfaceContainer: Color(0xFFCBE7E4),
        surfaceContainerHigh: Color(0xFFDBEFEC),
        surfaceContainerLow: Color(0xFFEDF7F6),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFF52807A),
        outlineVariant: Color(0xFF80CBC4),
      ),
    );
  }

  ThemeData _createRubyTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFFC62828),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFFFCDD2),
        onPrimaryContainer: Color(0xFFB71C1C),
        secondary: Color(0xFFD32F2F),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFFFEBEE),
        onSecondaryContainer: Color(0xFFB71C1C),
        tertiary: Color(0xFFE57373),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFFFE8E8),
        onTertiaryContainer: Color(0xFF8C1D18),
        surface: Color(0xFFFFF5F5),
        onSurface: Color(0xFFB71C1C),
        surfaceVariant: Color(0xFFFFCDD2),
        onSurfaceVariant: Color(0xFFC62828),
        surfaceContainerHighest: Color(0xFFFFB3BA),
        surfaceContainer: Color(0xFFFFD6D9),
        surfaceContainerHigh: Color(0xFFFFE4E6),
        surfaceContainerLow: Color(0xFFFFF2F2),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFFAD4A47),
        outlineVariant: Color(0xFFEF9A9A),
      ),
    );
  }

  ThemeData _createSapphireTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFF1565C0),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFBBDEFB),
        onPrimaryContainer: Color(0xFF0D47A1),
        secondary: Color(0xFF1976D2),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFE3F2FD),
        onSecondaryContainer: Color(0xFF0D47A1),
        tertiary: Color(0xFF42A5F5),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFE8F4FF),
        onTertiaryContainer: Color(0xFF0D47A1),
        surface: Color(0xFFF3F8FF),
        onSurface: Color(0xFF0D47A1),
        surfaceVariant: Color(0xFFE3F2FD),
        onSurfaceVariant: Color(0xFF1565C0),
        surfaceContainerHighest: Color(0xFFCDE7F0),
        surfaceContainer: Color(0xFFDBEDF7),
        surfaceContainerHigh: Color(0xFFE7F2FB),
        surfaceContainerLow: Color(0xFFF5F9FD),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFF5472A3),
        outlineVariant: Color(0xFF90CAF9),
      ),
    );
  }

  ThemeData _createAmberTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: Color(0xFFFF8F00),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFFFE0B2),
        onPrimaryContainer: Color(0xFFE65100),
        secondary: Color(0xFFFFB300),
        onSecondary: Color(0xFF3E2723),
        secondaryContainer: Color(0xFFFFF8E1),
        onSecondaryContainer: Color(0xFFFF6F00),
        tertiary: Color(0xFFFFD54F),
        onTertiary: Color(0xFF5D4037),
        tertiaryContainer: Color(0xFFFFFDE7),
        onTertiaryContainer: Color(0xFF8D6E63),
        surface: Color(0xFFFFFBF0),
        onSurface: Color(0xFFE65100),
        surfaceVariant: Color(0xFFFFE8B8),
        onSurfaceVariant: Color(0xFFFF8F00),
        surfaceContainerHighest: Color(0xFFFFD699),
        surfaceContainer: Color(0xFFFFE4B8),
        surfaceContainerHigh: Color(0xFFFFF0D4),
        surfaceContainerLow: Color(0xFFFFF9E8),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        outline: Color(0xFFB8860B),
        outlineVariant: Color(0xFFFFCC80),
      ),
    );
  }
}