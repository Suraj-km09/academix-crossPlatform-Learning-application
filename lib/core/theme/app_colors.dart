import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(
    0xFFB45309,
  ); // Amber 700 — bold, warm authority
  static const Color primaryLight = Color(
    0xFFFCD34D,
  ); // Amber 300 — bright golden accent
  static const Color primaryDark = Color(
    0xFF92400E,
  ); // Amber 800 — deep press state

  // Light theme backgrounds
  static const Color scaffoldLight = Color(
    0xFFFFFBEB,
  ); // Amber 50 — warm parchment feel
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Dark theme backgrounds — untouched
  static const Color scaffoldDark = Color(0xFF071226);
  static const Color surfaceDark = Color(0xFF0B1A2B);

  static const Color textLight = Color(
    0xFF1C1407,
  ); // Warm amber-black — rich, grounded
  static const Color textDark = Color(0xFFEAF8FF);

  static const Color borderLight = Color(
    0xFFFDE68A,
  ); // Amber 200 — warm, visible border
  static const Color borderDark = Color(0xFF203A54);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
}
