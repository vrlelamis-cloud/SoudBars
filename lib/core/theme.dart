import 'package:flutter/material.dart';

/// Jetons de couleur sémantiques (noir et blanc comme l'image d'origine).
class AppColors {
  static const background = Colors.black;
  static const onBackground = Colors.white;
  static const secondaryText = Color(0xFFA1A1A6); // ≈ 8:1 sur noir
  static const surface = Color(0xFF1C1C1E);
  static const divider = Color(0xFF3A3A3C);
  static const recording = Color(0xFFFF453A);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      surface: AppColors.background,
      onSurface: Colors.white,
      error: AppColors.recording,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.onBackground,
      displayColor: AppColors.onBackground,
    ),
    dividerColor: AppColors.divider,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.onBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 15),
      actionTextColor: Colors.white,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
    popupMenuTheme: const PopupMenuThemeData(color: AppColors.surface),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
      ),
    ),
  );
}
