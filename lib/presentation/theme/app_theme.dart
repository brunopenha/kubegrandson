import 'package:flutter/material.dart';

import '../providers/theme/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryLight,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        error: AppColors.error,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimaryLight),
        bodyMedium: TextStyle(color: AppColors.textPrimaryLight),
        titleMedium: TextStyle(color: AppColors.textPrimaryLight),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.borderLight)),
        labelStyle: const TextStyle(color: AppColors.textPrimaryLight),
      ),
      iconButtonTheme: IconButtonThemeData(
        style:
            IconButton.styleFrom(foregroundColor: AppColors.textPrimaryLight),
      ),
      checkboxTheme: _checkboxTheme(
        active: AppColors.primaryLight,
        check: Colors.white,
        border: AppColors.textPrimaryLight,
      ),
      radioTheme: _radioTheme(
        active: AppColors.primaryLight,
        border: AppColors.textPrimaryLight,
      ),
      switchTheme: _switchTheme(
        thumb: AppColors.primaryLight,
        track: AppColors.borderLight,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primaryLight,
          disabledForegroundColor: AppColors.textSecondary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryLight,
          side: const BorderSide(color: AppColors.textPrimaryLight),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(foregroundColor: AppColors.textPrimaryLight),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        onPrimary: AppColors.textPrimaryLight,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textPrimaryLight,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        titleMedium: TextStyle(color: AppColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        border:
            OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textPrimary),
      ),
      checkboxTheme: _checkboxTheme(
        active: AppColors.primary,
        check: Colors.white,
        border: AppColors.textPrimary,
      ),
      radioTheme: _radioTheme(
        active: AppColors.primary,
        border: AppColors.textPrimary,
      ),
      switchTheme: _switchTheme(
        thumb: AppColors.primary,
        track: AppColors.border,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textSecondary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: AppColors.textPrimaryLight,
          backgroundColor: AppColors.primaryDark,
          disabledForegroundColor: AppColors.textSecondary,
          disabledBackgroundColor: AppColors.border,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.textPrimary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
      ),
    );
  }

  static CheckboxThemeData _checkboxTheme({
    required Color active,
    required Color check,
    required Color border,
  }) {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return active;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(check),
      side: BorderSide(color: border, width: 1.5),
    );
  }

  static RadioThemeData _radioTheme({
    required Color active,
    required Color border,
  }) {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return active;
        return border;
      }),
    );
  }

  static SwitchThemeData _switchTheme({
    required Color thumb,
    required Color track,
  }) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return thumb;
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return thumb.withValues(alpha: 0.45);
        }
        return track;
      }),
      trackOutlineColor: WidgetStateProperty.all(track),
    );
  }
}
