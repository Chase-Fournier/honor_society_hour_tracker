import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


enum ThemeMode { light, dark, midnight }

class ThemeProvider extends ChangeNotifier {
  // Current theme mode
  ThemeMode _themeMode = ThemeMode.light;

  // Getter for theme mode
  ThemeMode get themeMode => _themeMode;

  // Convenience getters
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isMidnightMode => _themeMode == ThemeMode.midnight;

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
    _themeMode = ThemeMode.values[themeIndex];
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

  // Get theme data based on current mode
  ThemeData getThemeData(Color themeColor) {
    switch (_themeMode) {
      case ThemeMode.light:
        return ThemeData(
          colorSchemeSeed: themeColor,
          useMaterial3: true,
          brightness: Brightness.light,
        );
      case ThemeMode.dark:
        return ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: themeColor,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        );
      case ThemeMode.midnight:
        // Create a truly dark "midnight" theme with deep blacks
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
          cardTheme: const CardTheme(
            color: Color(0xFF121212),
          ),
          dialogTheme: const DialogTheme(
            backgroundColor: Color(0xFF121212),
          ),
        );
    }
  }
}
