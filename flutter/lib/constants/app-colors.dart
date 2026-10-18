import 'package:flutter/material.dart';

import '../services/settings-service.dart';

/// Defines the color palette for the application.
class AppColors {
  static Brightness _getBrightness(BuildContext context, Brightness? brightness) {
    if (brightness != null) {
      return brightness;
    }
    final Brightness? forcedBrightness = SettingsService().forcedBrightness;
    if (forcedBrightness != null) {
      return forcedBrightness;
    }
    try {
      return Theme.of(context).brightness;
    }catch (_) {
      return MediaQuery.platformBrightnessOf(context);
    }
  }

  /// Retrieves the dynamic background color.
  static Color background(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
  }

  /// Retrieves the dynamic surface color (e.g. for Cards and Navigation Bars).
  static Color surface(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFF1F2937) : const Color(0xFFFFFFFF);
  }

  /// Retrieves the dynamic primary color.
  static Color primary(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
  }

  /// Retrieves the dynamic primary text color.
  static Color textPrimary(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
  }

  /// Retrieves the dynamic secondary text color.
  static Color textSecondary(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  }

  /// Retrieves the dynamic border/divider color.
  static Color border(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
  }

  /// Retrieves the shadow color.
  static Color shadow(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0x33000000) : const Color(0x11000000);
  }

  /// Retrieves the error/destructive color.
  static Color error(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
  }

  /// Retrieves the success color.
  static Color success(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFF10B981) : const Color(0xFF059669);
  }

  /// Retrieves the disabled item color.
  static Color disabled(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
  }

  /// Retrieves pure white.
  static Color white(BuildContext context, { Brightness? brightness }) {
    return const Color(0xFFFFFFFF);
  }
}
