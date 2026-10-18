import 'package:flutter/material.dart';

import '../data/models.dart';
import 'roles.dart';

/// Colours taken from the CONE logo.
abstract final class AppColors {
  static const navy = Color(0xFF052543);
  static const navyLight = Color(0xFF16406B);
  static const teal = Color(0xFF0E9F8E);
  static const tealBright = Color(0xFF1DE3D4);
  static const amber = Color(0xFFF5B04B);
  static const background = Color(0xFFF5F7FA);
  static const outline = Color(0xFFE1E6EE);
  static const textMuted = Color(0xFF5B6B7F);

  static const warningBg = Color(0xFFFDECEA);
  static const warningFg = Color(0xFFB3261E);
}

/// App theme. After sign-in, [role] tints the screen and app-bar background.
ThemeData buildAppTheme({Role? role}) {
  final background = role?.background ?? AppColors.background;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.teal,
    onSecondary: Colors.white,
    tertiary: AppColors.amber,
    surface: Colors.white,
    error: AppColors.warningFg,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return base.copyWith(
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: AppColors.navy,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: AppColors.navy,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: shape,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: shape,
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.outline, width: 1.5),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.teal, width: 2),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outline, space: 1),
  );
}
