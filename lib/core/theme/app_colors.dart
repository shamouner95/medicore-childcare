import 'package:flutter/material.dart';

class AppColors {
  // New "Warm Organic" Palette (inspired by the design)
  static const Color background = Color(0xFFFBF7F0); // Warm Cream
  static const Color backgroundDark = Color(0xFF1C1B19); // Deep Warm Gray
  
  static const Color primary = Color(0xFFD67B52);    // Terracotta / Earthy Red
  static const Color primaryLight = Color(0xFFF2E9E1); // Very Light Cream/Orange
  
  static const Color secondary = Color(0xFFA9C5C8);  // Soft Muted Blue/Teal
  static const Color secondaryDark = Color(0xFF7A9FA3);
  
  static const Color accent = Color(0xFFB2B9A1);     // Sage Green
  static const Color accentLight = Color(0xFFE9EBE0);
  
  static const Color success = Color(0xFF8DA399);    // Muted Emerald
  static const Color warning = Color(0xFFD67B52);    // Using primary for warnings to keep palette tight
  static const Color error = Color(0xFFE57373);      // Muted Red
  
  static const Color surface = Color(0xFFFEFEFE);    // Off White
  static const Color surfaceDark = Color(0xFF2D2926);  // Deep Charcoal
  
  static const Color textDeep = Color(0xFF2D2926);   // Deep Brownish Charcoal
  static const Color textLight = Color(0xFFFBF7F0);  // Warm Cream

  static const Color shelf = Color(0xFFE8E3D9); // Subtle divider/background color

  // Custom Gradients for the new Palette
  static const LinearGradient organicGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD67B52), // Terracotta
      Color(0xFFA9C5C8), // Muted Blue
    ],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFBF7F0),
      Color(0xFFF2E9E1),
    ],
  );

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF2D2926).withValues(alpha: 0.05),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> premiumShadow = [
    BoxShadow(
      color: const Color(0xFFD67B52).withValues(alpha: 0.1),
      blurRadius: 25,
      offset: const Offset(0, 8),
    ),
  ];

  static const Color glassBackground = Color(0xB3FBF7F0);
  static const Color glassBorder = Color(0x332D2926);

  // Compatibility Aliases for "Warm Organic" Transition
  static const LinearGradient premiumGradient = organicGradient;
  static const LinearGradient medicalGradient = organicGradient;
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFB2B9A1), // Sage Green
      Color(0xFF8DA399), // Muted Emerald
    ],
  );

  static const LinearGradient coolGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFA9C5C8), // Soft Blue
      Color(0xFF7A9FA3), // Muted Teal
    ],
  );

  static const Color accentSecondary = secondary;
  static const Color navyDepth = textDeep;
}
