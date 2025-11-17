import 'package:flutter/material.dart';

class AppColors {
  // Base colors matching JavaFX theme
  static const Color backgroundDark = Color(0xFF3C3F41);  // RGB(60, 63, 65)
  static const Color backgroundLight = Color(0xFFF5F5F5);

  static const Color surfaceDark = Color(0xFF2B2B2B);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  static const Color border = Color(0xFF6F7375);
  static const Color borderLight = Color(0xFFE0E0E0);

  // Primary colors
  static const Color primary = Color(0xFF4A90E2);
  static const Color primaryDark = Color(0xFF357ABD);
  static const Color secondary = Color(0xFF50C878);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textLight = Color(0xFF212121);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF29B6F6);

  // Kubernetes status colors
  static const Color statusRunning = Color(0xFF4CAF50);
  static const Color statusPending = Color(0xFFFFA726);
  static const Color statusFailed = Color(0xFFEF5350);
  static const Color statusSucceeded = Color(0xFF66BB6A);
  static const Color statusUnknown = Color(0xFF9E9E9E);
}