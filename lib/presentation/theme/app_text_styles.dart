import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/theme/app_colors.dart';

class AppTextStyles {
  static TextTheme get textTheme {
    return TextTheme(
      displayLarge: heading1,
      displayMedium: heading2,
      displaySmall: heading3,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: buttonText,
    );
  }

  static TextStyle get heading1 => GoogleFonts.roboto(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle get heading2 => GoogleFonts.roboto(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get heading3 => GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodySmall => GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static TextStyle get buttonText => GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle get monospaceLarge => GoogleFonts.robotoMono(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static TextStyle get monospaceSmall => GoogleFonts.robotoMono(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );
}