import 'package:flutter/material.dart';

class Responsive {
  static bool isWideScreen(BuildContext context) => 
      MediaQuery.of(context).size.width >= 900;
      
  static bool isTabletScreen(BuildContext context) => 
      MediaQuery.of(context).size.width >= 600 && 
      MediaQuery.of(context).size.width < 900;
      
  static bool isMobileScreen(BuildContext context) => 
      MediaQuery.of(context).size.width < 600;
      
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1400) return 1200;
    if (width >= 900) return 900;
    if (width >= 600) return 600;
    return double.infinity;
  }
  
  static Widget responsiveBuilder({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    required Widget desktop,
  }) {
    if (isWideScreen(context)) return desktop;
    if (isTabletScreen(context)) return tablet ?? mobile;
    return mobile;
  }
}