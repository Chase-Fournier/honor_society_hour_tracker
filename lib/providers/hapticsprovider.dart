import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaimon/gaimon.dart';

/// Provider for managing haptic feedback throughout the app
class HapticsProvider extends ChangeNotifier {
  bool _isHapticsEnabled = true;

  bool get isHapticsEnabled => _isHapticsEnabled;

  HapticsProvider() {
    _loadHapticsPreference();
  }

  /// Load haptics preference from SharedPreferences
  Future<void> _loadHapticsPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isHapticsEnabled = prefs.getBool('haptics_enabled') ?? true;
      notifyListeners();
    } catch (e) {
      print('Error loading haptics preference: $e');
    }
  }

  /// Toggle haptics on/off and save to preferences
  Future<void> toggleHaptics(bool enabled) async {
    try {
      _isHapticsEnabled = enabled;
      notifyListeners();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('haptics_enabled', enabled);
      
      // Provide immediate feedback when enabling
      if (enabled) {
        selection();
      }
    } catch (e) {
      print('Error saving haptics preference: $e');
    }
  }

  /// Trigger selection haptic (for taps, selections)
  void selection() {
    if (_isHapticsEnabled) {
      Gaimon.selection();
    }
  }

  /// Trigger success haptic (for successful actions)
  void success() {
    if (_isHapticsEnabled) {
      Gaimon.success();
    }
  }

  /// Trigger error haptic (for errors, validation failures)
  void error() {
    if (_isHapticsEnabled) {
      Gaimon.error();
    }
  }

  /// Trigger warning haptic (for warnings, confirmations)
  void warning() {
    if (_isHapticsEnabled) {
      Gaimon.warning();
    }
  }

  /// Trigger light haptic (for subtle interactions)
  void light() {
    if (_isHapticsEnabled) {
      Gaimon.light();
    }
  }

  /// Trigger medium haptic (for standard interactions)
  void medium() {
    if (_isHapticsEnabled) {
      Gaimon.medium();
    }
  }

  /// Trigger heavy haptic (for important interactions)
  void heavy() {
    if (_isHapticsEnabled) {
      Gaimon.heavy();
    }
  }

  /// Trigger rigid haptic (for quick, strong feedback)
  void rigid() {
    if (_isHapticsEnabled) {
      Gaimon.rigid();
    }
  }

  /// Trigger soft haptic (for gentle feedback)
  void soft() {
    if (_isHapticsEnabled) {
      Gaimon.soft();
    }
  }
}