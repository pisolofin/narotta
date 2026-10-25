import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../constants/app-sizes.dart';

/// Custom painter rendering the cartographic void grid and the user's position indicator.
class MapGridPainter extends CustomPainter {
  final Offset cameraWorldMeters;
  final double zoom;
  final Offset? userWorldMeters;
  final double? userAccuracy;
  final double? userHeading;
  final double pulseProgress;
  final Color mapVoidColor;
  final Color gridMajorColor;
  final Color gridMinorColor;
  final Color gridCrosshairColor;
  final Color userPulseColor;
  final Color userAccuracyColor;
  final Color primaryColor;
  final Color whiteColor;

  const MapGridPainter({
    required this.cameraWorldMeters,
    required this.zoom,
    required this.userWorldMeters,
    required this.userAccuracy,
    required this.userHeading,
    required this.pulseProgress,
    required this.mapVoidColor,
    required this.gridMajorColor,
    required this.gridMinorColor,
    required this.gridCrosshairColor,
    required this.userPulseColor,
    required this.userAccuracyColor,
    required this.primaryColor,
    required this.whiteColor,
  });

  /// Computes a power-of-two metric grid step in meters for the scale indicator.
  static double calculateGridMetersStep(double zoom) {
    if (zoom <= 0.0) {
      return 10.0;
    }
    final double rawMeters = 80.0 / zoom;
    final double exponent = (math.log(rawMeters) / math.ln2).floorToDouble();
    return math.pow(2.0, exponent).toDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Fill the cartographic void background
    final Paint backgroundPaint = Paint()
      ..color = this.mapVoidColor
      ..style = PaintingStyle.fill
    ;
    canvas.drawRect(
      Rect.fromLTWH(0.0, 0.0, size.width, size.height),
      backgroundPaint,
    );

    final Offset center = Offset(size.width / 2.0, size.height / 2.0);

    // Continuous octave calculation for seamless multi-resolution grid scaling
    final double fineMetersStep = calculateGridMetersStep(this.zoom);
    final double majorMetersStep = fineMetersStep * 2.0;

    final double majorPixelsStep = majorMetersStep * this.zoom;
    final double minorPixelsStep = fineMetersStep * this.zoom;

    // Continuous opacity fade for minor lines so they never pop abruptly
    const double fadeStartPixels = 40.0;
    const double fadeEndPixels = 65.0;
    final double minorAlpha = ((minorPixelsStep - fadeStartPixels) / (fadeEndPixels - fadeStartPixels)).clamp(0.0, 1.0);

    final Paint majorLinePaint = Paint()
      ..color       = this.gridMajorColor
      ..strokeWidth = AppSizes.mapStrokeRegular
      ..style       = PaintingStyle.stroke
    ;

    final Paint minorLinePaint = Paint()
      ..color       = this.gridMinorColor.withValues(
        alpha: this.gridMinorColor.a * minorAlpha,
      )
      ..strokeWidth = AppSizes.mapStrokeThin
      ..style       = PaintingStyle.stroke
    ;

    final Paint crosshairPaint = Paint()
      ..color       = this.gridCrosshairColor
      ..strokeWidth = AppSizes.mapStrokeRegular
      ..style       = PaintingStyle.stroke
    ;

    // Calculate grid origin in screen coordinates
    final double originScreenX = center.dx - (this.cameraWorldMeters.dx * this.zoom);
    final double originScreenY = center.dy + (this.cameraWorldMeters.dy * this.zoom);

    // 1. Draw vertical minor grid lines with continuous alpha fade
    if (minorAlpha > 0.01) {
      final double minorStartX = (originScreenX % minorPixelsStep) - minorPixelsStep;
      for (double screenX = minorStartX; screenX <= (size.width + minorPixelsStep); screenX += minorPixelsStep) {
        final double distToMajor = ((screenX - originScreenX) % majorPixelsStep).abs();
        final bool onMajorLine = (distToMajor < 1.0) || ((majorPixelsStep - distToMajor).abs() < 1.0);
        if (!onMajorLine) {
          canvas.drawLine(
            Offset(screenX, 0.0),
            Offset(screenX, size.height),
            minorLinePaint,
          );
        }
      }
    }

    // 2. Draw vertical major grid lines
    final double majorStartX = (originScreenX % majorPixelsStep) - majorPixelsStep;
    for (double screenX = majorStartX; screenX <= (size.width + majorPixelsStep); screenX += majorPixelsStep) {
      canvas.drawLine(
        Offset(screenX, 0.0),
        Offset(screenX, size.height),
        majorLinePaint,
      );
    }

    // 3. Draw horizontal minor grid lines with continuous alpha fade
    if (minorAlpha > 0.01) {
      final double minorStartY = (originScreenY % minorPixelsStep) - minorPixelsStep;
      for (double screenY = minorStartY; screenY <= (size.height + minorPixelsStep); screenY += minorPixelsStep) {
        final double distToMajor = ((screenY - originScreenY) % majorPixelsStep).abs();
        final bool onMajorLine = (distToMajor < 1.0) || ((majorPixelsStep - distToMajor).abs() < 1.0);
        if (!onMajorLine) {
          canvas.drawLine(
            Offset(0.0, screenY),
            Offset(size.width, screenY),
            minorLinePaint,
          );
        }
      }
    }

    // 4. Draw horizontal major grid lines
    final double majorStartY = (originScreenY % majorPixelsStep) - majorPixelsStep;
    for (double screenY = majorStartY; screenY <= (size.height + majorPixelsStep); screenY += majorPixelsStep) {
      canvas.drawLine(
        Offset(0.0, screenY),
        Offset(size.width, screenY),
        majorLinePaint,
      );
    }

    // 5. Draw coordinate intersection crosshairs at major grid vertices
    const double halfCrosshair = AppSizes.mapCrosshairLength / 2.0;
    for (double crossX = majorStartX; crossX <= (size.width + majorPixelsStep); crossX += majorPixelsStep) {
      for (double crossY = majorStartY; crossY <= (size.height + majorPixelsStep); crossY += majorPixelsStep) {
        // Horizontal arm
        canvas.drawLine(
          Offset(crossX - halfCrosshair, crossY),
          Offset(crossX + halfCrosshair, crossY),
          crosshairPaint,
        );
        // Vertical arm
        canvas.drawLine(
          Offset(crossX, crossY - halfCrosshair),
          Offset(crossX, crossY + halfCrosshair),
          crosshairPaint,
        );
      }
    }

    // Draw subtle viewport center reticle
    final Paint centerReticlePaint = Paint()
      ..color       = this.gridMajorColor
      ..strokeWidth = AppSizes.mapStrokeThin
      ..style       = PaintingStyle.stroke
    ;
    const double reticleGap = AppSizes.p4;
    const double reticleLength = AppSizes.p12;

    canvas.drawLine(
      Offset(center.dx - reticleLength, center.dy),
      Offset(center.dx - reticleGap, center.dy),
      centerReticlePaint,
    );
    canvas.drawLine(
      Offset(center.dx + reticleGap, center.dy),
      Offset(center.dx + reticleLength, center.dy),
      centerReticlePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - reticleLength),
      Offset(center.dx, center.dy - reticleGap),
      centerReticlePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + reticleGap),
      Offset(center.dx, center.dy + reticleLength),
      centerReticlePaint,
    );

    // Draw the user's position indicator in the cartographic void
    if (this.userWorldMeters != null) {
      final double userScreenX = center.dx + ((this.userWorldMeters!.dx - this.cameraWorldMeters.dx) * this.zoom);
      final double userScreenY = center.dy - ((this.userWorldMeters!.dy - this.cameraWorldMeters.dy) * this.zoom);
      final Offset userScreenPos = Offset(userScreenX, userScreenY);

      // Only draw if within reasonable bounds of the screen
      const double margin = AppSizes.icon64;
      final bool isInsideViewport = (userScreenX >= -margin) &&
        (userScreenX <= (size.width + margin)) &&
        (userScreenY >= -margin) &&
        (userScreenY <= (size.height + margin));

      if (isInsideViewport) {
        // Draw GPS accuracy radius halo
        if ((this.userAccuracy != null) && (this.userAccuracy! > 0.0)) {
          final double accuracyPixels = math.max(
            this.userAccuracy! * this.zoom,
            AppSizes.mapUserMarkerRadius + AppSizes.p4,
          );

          final Paint accuracyFillPaint = Paint()
            ..color = this.userAccuracyColor
            ..style = PaintingStyle.fill
          ;
          canvas.drawCircle(userScreenPos, accuracyPixels, accuracyFillPaint);

          final Paint accuracyStrokePaint = Paint()
            ..color       = this.primaryColor.withValues(alpha: 0.4)
            ..strokeWidth = AppSizes.mapStrokeThin
            ..style       = PaintingStyle.stroke
          ;
          canvas.drawCircle(userScreenPos, accuracyPixels, accuracyStrokePaint);
        }

        // Draw animated radar pulse wave
        final double pulseRadius = AppSizes.mapUserMarkerRadius +
          (this.pulseProgress * AppSizes.mapUserPulseMaxRadius);
        final double pulseOpacity = (1.0 - this.pulseProgress) * 0.7;

        final Paint pulsePaint = Paint()
          ..color = this.userPulseColor.withValues(alpha: pulseOpacity)
          ..style = PaintingStyle.fill
        ;
        canvas.drawCircle(userScreenPos, pulseRadius, pulsePaint);

        // Draw directional navigation arrow or stationary beacon
        if ((this.userHeading != null) && (this.userHeading! >= 0.0)) {
          canvas.save();
          canvas.translate(userScreenPos.dx, userScreenPos.dy);
          canvas.rotate(this.userHeading! * math.pi / 180.0);

          // Outer directional cone / arrow
          final Path arrowPath = Path()
            ..moveTo(0.0, -AppSizes.icon20)
            ..lineTo(AppSizes.mapUserMarkerRadius, AppSizes.mapUserMarkerRadius)
            ..lineTo(0.0, AppSizes.p4)
            ..lineTo(-AppSizes.mapUserMarkerRadius, AppSizes.mapUserMarkerRadius)
            ..close()
          ;

          final Paint arrowShadowPaint = Paint()
            ..color      = this.userPulseColor
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, AppSizes.p4)
          ;
          canvas.drawPath(arrowPath, arrowShadowPaint);

          final Paint arrowPaint = Paint()
            ..color = this.primaryColor
            ..style = PaintingStyle.fill
          ;
          canvas.drawPath(arrowPath, arrowPaint);

          final Paint arrowBorderPaint = Paint()
            ..color       = this.whiteColor
            ..strokeWidth = AppSizes.mapStrokeThin
            ..style       = PaintingStyle.stroke
          ;
          canvas.drawPath(arrowPath, arrowBorderPaint);

          // Inner center white core
          final Paint innerDotPaint = Paint()
            ..color = this.whiteColor
            ..style = PaintingStyle.fill
          ;
          canvas.drawCircle(const Offset(0.0, AppSizes.p2), AppSizes.p4, innerDotPaint);

          canvas.restore();
        }else {
          // Stationary circular position beacon
          final Paint glowPaint = Paint()
            ..color      = this.primaryColor.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, AppSizes.p6)
          ;
          canvas.drawCircle(userScreenPos, AppSizes.mapUserMarkerRadius + AppSizes.p4, glowPaint);

          final Paint markerPaint = Paint()
            ..color = this.primaryColor
            ..style = PaintingStyle.fill
          ;
          canvas.drawCircle(userScreenPos, AppSizes.mapUserMarkerRadius, markerPaint);

          final Paint borderPaint = Paint()
            ..color       = this.whiteColor
            ..strokeWidth = AppSizes.mapUserMarkerBorder
            ..style       = PaintingStyle.stroke
          ;
          canvas.drawCircle(userScreenPos, AppSizes.mapUserMarkerRadius, borderPaint);

          final Paint centerCorePaint = Paint()
            ..color = this.whiteColor
            ..style = PaintingStyle.fill
          ;
          canvas.drawCircle(userScreenPos, AppSizes.p4, centerCorePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant MapGridPainter oldDelegate) {
    return (oldDelegate.cameraWorldMeters != this.cameraWorldMeters) ||
      (oldDelegate.zoom != this.zoom) ||
      (oldDelegate.userWorldMeters != this.userWorldMeters) ||
      (oldDelegate.userAccuracy != this.userAccuracy) ||
      (oldDelegate.userHeading != this.userHeading) ||
      (oldDelegate.pulseProgress != this.pulseProgress) ||
      (oldDelegate.mapVoidColor != this.mapVoidColor) ||
      (oldDelegate.gridMajorColor != this.gridMajorColor) ||
      (oldDelegate.gridMinorColor != this.gridMinorColor) ||
      (oldDelegate.gridCrosshairColor != this.gridCrosshairColor) ||
      (oldDelegate.userPulseColor != this.userPulseColor) ||
      (oldDelegate.userAccuracyColor != this.userAccuracyColor) ||
      (oldDelegate.primaryColor != this.primaryColor) ||
      (oldDelegate.whiteColor != this.whiteColor);
  }
}
