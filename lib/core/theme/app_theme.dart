import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Шрифты приложения лежат в assets/fonts и объявлены в pubspec.yaml,
/// поэтому работают сразу и без интернета.
///
/// hand — рукописный Caveat (заголовки, цифры),
/// body — «тетрадный» Neucha с кириллицей.
class AppText {
  AppText._();

  static const String handFamily = 'Caveat';
  static const String bodyFamily = 'Neucha';

  static TextStyle hand(
    double size, {
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w700,
  }) =>
      TextStyle(
        fontFamily: handFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.1,
      );

  static TextStyle body(double size, {Color color = AppColors.ink}) =>
      TextStyle(fontFamily: bodyFamily, fontSize: size, color: color);
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

  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: AppText.bodyFamily,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
  );
}
