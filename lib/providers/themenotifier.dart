import 'package:flutter/material.dart';

class ThemeNotifier with ChangeNotifier {
  Color _themeColor = Colors.purple;

  Color get themeColor => _themeColor;

  void updateThemeColor(Color color) {
    _themeColor = color;
    notifyListeners();
  }
}
