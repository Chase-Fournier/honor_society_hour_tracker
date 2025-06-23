import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NavigationBarType {
  google,
  circle,
  floating,
}

/// Provider for managing navigation bar preferences throughout the app
class NavigationProvider extends ChangeNotifier {
  NavigationBarType _navigationBarType = NavigationBarType.google;

  NavigationBarType get navigationBarType => _navigationBarType;

  NavigationProvider() {
    _loadNavigationPreference();
  }

  /// Load navigation bar preference from SharedPreferences
  Future<void> _loadNavigationPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final typeIndex = prefs.getInt('navigation_bar_type') ?? 0;
      _navigationBarType = NavigationBarType.values[typeIndex];
      notifyListeners();
    } catch (e) {
      print('Error loading navigation preference: $e');
    }
  }

  /// Set navigation bar type and save to preferences
  Future<void> setNavigationBarType(NavigationBarType type) async {
    try {
      _navigationBarType = type;
      notifyListeners();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('navigation_bar_type', type.index);
    } catch (e) {
      print('Error saving navigation preference: $e');
    }
  }

  /// Get display name for navigation type
  String getNavigationTypeName(NavigationBarType type) {
    switch (type) {
      case NavigationBarType.google:
        return 'Google Nav Bar';
      case NavigationBarType.circle:
        return 'Circle Nav Bar';
      case NavigationBarType.floating:
        return 'Floating Nav Bar';
    }
  }
}