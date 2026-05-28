import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaimon/gaimon.dart';

/// Provider for managing haptic feedback throughout the app
class HapticsProvider extends ChangeNotifier {
  bool _isHapticsEnabled = true;

  bool get isHapticsEnabled => _isHapticsEnabled;

  /// gaimon only ships iOS/Android implementations. On web and desktop the
  /// platform channel is missing, so calling it throws MissingPluginException.
  /// Gate every call so haptics are a silent no-op off mobile.
  static final bool _platformSupportsHaptics = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  bool get _canVibrate => _isHapticsEnabled && _platformSupportsHaptics;

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
    if (_canVibrate) {
      Gaimon.selection();
    }
  }

  /// Trigger success haptic (for successful actions)
  void success() {
    if (_canVibrate) {
      Gaimon.success();
    }
  }

  /// Trigger error haptic (for errors, validation failures)
  void error() {
    if (_canVibrate) {
      Gaimon.error();
    }
  }

  /// Trigger warning haptic (for warnings, confirmations)
  void warning() {
    if (_canVibrate) {
      Gaimon.warning();
    }
  }

  /// Trigger light haptic (for subtle interactions)
  void light() {
    if (_canVibrate) {
      Gaimon.light();
    }
  }

  /// Trigger medium haptic (for standard interactions)
  void medium() {
    if (_canVibrate) {
      Gaimon.medium();
    }
  }

  /// Trigger heavy haptic (for important interactions)
  void heavy() {
    if (_canVibrate) {
      Gaimon.heavy();
    }
  }

  /// Trigger rigid haptic (for quick, strong feedback)
  void rigid() {
    if (_canVibrate) {
      Gaimon.rigid();
    }
  }

  /// Trigger soft haptic (for gentle feedback)
  void soft() {
    if (_canVibrate) {
      Gaimon.soft();
    }
  }
}
