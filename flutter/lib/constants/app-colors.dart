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

  /// Retrieves the map void / canvas background color.
  static Color mapVoid(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  }

  /// Retrieves the map grid major line color.
  static Color mapGridMajor(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0x3338BDF8) : const Color(0x330284C7);
  }

  /// Retrieves the map grid minor line color.
  static Color mapGridMinor(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0x1A64748B) : const Color(0x1994A3B8);
  }

  /// Retrieves the map grid intersection crosshair color.
  static Color mapGridCrosshair(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0x6638BDF8) : const Color(0x660284C7);
  }

  /// Retrieves the user location pulse / radar color.
  static Color userPulse(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0x4D38BDF8) : const Color(0x4D2563EB);
  }

  /// Retrieves the user location accuracy circle color.
  static Color userAccuracy(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0x2638BDF8) : const Color(0x262563EB);
  }

  /// Retrieves the color for Level 1 Base download (Roads and navigation).
  static Color detailBase(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
  }

  /// Retrieves the color for Level 2 Detailed download (Roads and pedestrian/trails).
  static Color detailDetailed(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
  }

  /// Retrieves the color for Level 3 Complete download (Roads, trails, 3D buildings, HD terrain).
  static Color detailComplete(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFF10B981) : const Color(0xFF059669);
  }

  /// Retrieves the landmass continent fill color on the world map.
  static Color mapContinent(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  }

  /// Retrieves the landmass continent outline border color on the world map.
  static Color mapContinentBorder(BuildContext context, { Brightness? brightness }) {
    final Brightness effectiveBrightness = _getBrightness(context, brightness);
    return effectiveBrightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
  }
}
