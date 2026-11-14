import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Шрифты приложения.
/// hand — рукописный (заголовки, цифры), body — «тетрадный» текст с кириллицей.
class AppText {
  AppText._();

  static TextStyle hand(
    double size, {
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w700,
  }) =>
      GoogleFonts.caveat(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.1,
      );

  static TextStyle body(double size, {Color color = AppColors.ink}) =>
      GoogleFonts.neucha(fontSize: size, color: color);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.ink,
      secondary: AppColors.accent,
      surface: AppColors.paper,
      error: AppColors.red,
    ),
    scaffoldBackgroundColor: AppColors.cover,
  );

  // google_fonts 9 возвращает TextTheme из другого пакета, поэтому применяем
  // семейство шрифта к стандартной теме Flutter через apply().
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: GoogleFonts.neucha().fontFamily,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
  );
}
