import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'app-colors.dart';

/// Configures the light and dark themes for the application.
class AppTheme {
  /// Generates the Material ThemeData for the application.
  static ThemeData materialTheme(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = brightness ?? MediaQuery.platformBrightnessOf(context);

    return ThemeData(
      useMaterial3           : true,
      brightness             : effectiveBrightness,
      scaffoldBackgroundColor: AppColors.background(context, brightness: effectiveBrightness),
      colorScheme            : ColorScheme.fromSeed(
        seedColor : AppColors.primary(context, brightness: effectiveBrightness),
        brightness: effectiveBrightness,
        primary   : AppColors.primary(context, brightness: effectiveBrightness),
        surface   : AppColors.surface(context, brightness: effectiveBrightness),
        error     : AppColors.error(context, brightness: effectiveBrightness),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background(context, brightness: effectiveBrightness),
        foregroundColor: AppColors.textPrimary(context, brightness: effectiveBrightness),
        elevation      : 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor    : AppColors.surface(context, brightness: effectiveBrightness),
        selectedItemColor  : AppColors.primary(context, brightness: effectiveBrightness),
        unselectedItemColor: AppColors.textSecondary(context, brightness: effectiveBrightness),
      ),
    );
  }

  /// Generates the CupertinoThemeData for the application.
  static CupertinoThemeData cupertinoTheme(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = brightness ?? MediaQuery.platformBrightnessOf(context);

    return CupertinoThemeData(
      brightness             : effectiveBrightness,
      primaryColor           : AppColors.primary(context, brightness: effectiveBrightness),
      primaryContrastingColor: const Color(0xFFFFFFFF),
      scaffoldBackgroundColor: AppColors.background(context, brightness: effectiveBrightness),
      barBackgroundColor     : AppColors.surface(context, brightness: effectiveBrightness),
    );
  }
}
