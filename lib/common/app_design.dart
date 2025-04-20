// Create a new file: lib/design/app_design.dart

import 'package:flutter/material.dart';

/// Core design constants for the application
class AppDesign {
  // Border radius values
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  static const double radiusRound = 30.0;
  
  // Standard circular border radius
  static BorderRadius borderSmall = BorderRadius.circular(radiusSmall);
  static BorderRadius borderMedium = BorderRadius.circular(radiusMedium);
  static BorderRadius borderLarge = BorderRadius.circular(radiusLarge);
  static BorderRadius borderXLarge = BorderRadius.circular(radiusXLarge);
  static BorderRadius borderRound = BorderRadius.circular(radiusRound);
  
  // Spacing/padding values
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  
  // Standard paddings
  static const EdgeInsets paddingSmall = EdgeInsets.all(spacingS);
  static const EdgeInsets paddingMedium = EdgeInsets.all(spacingM);
  static const EdgeInsets paddingLarge = EdgeInsets.all(spacingL);
  
  // Standard elevation values
  static const double elevationNone = 0.0;
  static const double elevationSmall = 1.0;
  static const double elevationMedium = 2.0;
  static const double elevationLarge = 4.0;
  
  // Shadow styles
  static List<BoxShadow> shadowSmall(BuildContext context) => [
    BoxShadow(
      color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> shadowMedium(BuildContext context) => [
    BoxShadow(
      color: Theme.of(context).colorScheme.shadow.withOpacity(0.15),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  // Animation durations
  static const Duration animationShort = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 500);
  static const Duration animationLong = Duration(milliseconds: 800);
}