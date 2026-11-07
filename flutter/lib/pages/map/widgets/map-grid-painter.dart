import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../constants/app-sizes.dart';
import '../../../services/geo-cell-service.dart';
import '../../../services/map-download-service.dart';

import '../../map-download/widgets/world-cities-data.dart';
import '../../map-download/widgets/world-continents-data.dart';

/// Custom painter rendering the cartographic void grid, world continents, downloaded cells, and the user's position indicator.
class MapGridPainter extends CustomPainter {
  static const double _metersPerDegreeLat = 111320.0;

  final Offset cameraWorldMeters;
  final double zoom;
  final Offset? userWorldMeters;
  final double? userAccuracy;
  final double? userHeading;
  final double pulseProgress;
  final bool isWorldMapDownloaded;
  final Map<String, MapDetailLevel> downloadedCellLevelMap;
  final double referenceLat;
  final double referenceLon;
  final Color mapVoidColor;
  final Color mapContinentColor;
  final Color mapContinentBorderColor;
  final Color gridMajorColor;
  final Color gridMinorColor;
  final Color gridCrosshairColor;
  final Color userPulseColor;
  final Color userAccuracyColor;
  final Color primaryColor;
  final Color whiteColor;
  final Color detailBaseColor;
  final Color detailDetailedColor;
  final Color detailCompleteColor;
  final Color mapHighwayColor;
  final Color mapCityMarkerColor;
  final Color mapCityLabelColor;

  const MapGridPainter({
    required this.cameraWorldMeters,
    required this.zoom,
    required this.userWorldMeters,
    required this.userAccuracy,
    required this.userHeading,
    required this.pulseProgress,
    required this.isWorldMapDownloaded,
    required this.downloadedCellLevelMap,
    required this.referenceLat,
    required this.referenceLon,
    required this.mapVoidColor,
    required this.mapContinentColor,
    required this.mapContinentBorderColor,
    required this.gridMajorColor,
    required this.gridMinorColor,
    required this.gridCrosshairColor,
    required this.userPulseColor,
    required this.userAccuracyColor,
    required this.primaryColor,
    required this.whiteColor,
    required this.detailBaseColor,
    required this.detailDetailedColor,
    required this.detailCompleteColor,
    required this.mapHighwayColor,
    required this.mapCityMarkerColor,
    required this.mapCityLabelColor,
  });

  /// Computes a power-of-two metric grid step in meters for the scale indicator.
  static double calculateGridMetersStep(double zoom) {
    if (zoom <= 0.0) {
      return 10.0;
    }
    final double rawMeters = 80.0 / zoom;
    final double exponent  = (math.log(rawMeters) / math.ln2).floorToDouble();
    return math.pow(2.0, exponent).toDouble();
  }

  /// Converts geographic (longitude, latitude) coordinates into local world coordinates in meters.
  Offset _geoToWorldMeters(double longitude, double latitude) {
    final double latRadians         = this.referenceLat * math.pi / 180.0;
    final double metersPerDegreeLon = _metersPerDegreeLat * math.cos(latRadians);
    final double deltaX             = (longitude - this.referenceLon) * metersPerDegreeLon;
    final double deltaY             = (latitude - this.referenceLat) * _metersPerDegreeLat;
    return Offset(deltaX, deltaY);
  }

  /// Converts world meters into canvas screen coordinates.
  Offset _worldMetersToScreen(Offset worldMeters, Offset center) {
    final double screenX = center.dx + ((worldMeters.dx - this.cameraWorldMeters.dx) * this.zoom);
    final double screenY = center.dy - ((worldMeters.dy - this.cameraWorldMeters.dy) * this.zoom);
    return Offset(screenX, screenY);
  }

  /// Resolves the semantic color for a downloaded [MapDetailLevel].
  Color _getLevelColor(MapDetailLevel level) {
    if (level == MapDetailLevel.base) {
      return this.detailBaseColor;
    }
    if (level == MapDetailLevel.detailed) {
      return this.detailDetailedColor;
    }
    return this.detailCompleteColor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect viewportRect = Rect.fromLTWH(0.0, 0.0, size.width, size.height);
    canvas.save();
    canvas.clipRect(viewportRect);

    // 1. Fill the cartographic void background
    final Paint backgroundPaint = Paint()
      ..color = this.mapVoidColor
      ..style = PaintingStyle.fill
    ;
    canvas.drawRect(viewportRect, backgroundPaint);

    final Offset center = Offset(size.width / 2.0, size.height / 2.0);

    // 2. Render cartographic void grid lines and coordinate crosshairs on the void background
    final double fineMetersStep  = calculateGridMetersStep(this.zoom);
    final double majorMetersStep = fineMetersStep * 2.0;

    final double majorPixelsStep = majorMetersStep * this.zoom;
    final double minorPixelsStep = fineMetersStep * this.zoom;

    const double fadeStartPixels = 40.0;
    const double fadeEndPixels   = 65.0;
    final double minorAlpha      = ((minorPixelsStep - fadeStartPixels) / (fadeEndPixels - fadeStartPixels)).clamp(0.0, 1.0);

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

    final double originScreenX = center.dx - (this.cameraWorldMeters.dx * this.zoom);
    final double originScreenY = center.dy + (this.cameraWorldMeters.dy * this.zoom);

    // Vertical minor grid lines
    if (minorAlpha > 0.01) {
      final double minorStartX = (originScreenX % minorPixelsStep) - minorPixelsStep;
      for (double screenX = minorStartX; screenX <= (size.width + minorPixelsStep); screenX += minorPixelsStep) {
        final double distToMajor = ((screenX - originScreenX) % majorPixelsStep).abs();
        final bool onMajorLine   = (distToMajor < 1.0) || ((majorPixelsStep - distToMajor).abs() < 1.0);
        if (!onMajorLine) {
          canvas.drawLine(
            Offset(screenX, 0.0),
            Offset(screenX, size.height),
            minorLinePaint,
          );
        }
      }
    }

    // Vertical major grid lines
    final double majorStartX = (originScreenX % majorPixelsStep) - majorPixelsStep;
    for (double screenX = majorStartX; screenX <= (size.width + majorPixelsStep); screenX += majorPixelsStep) {
      canvas.drawLine(
        Offset(screenX, 0.0),
        Offset(screenX, size.height),
        majorLinePaint,
      );
    }

    // Horizontal minor grid lines
    if (minorAlpha > 0.01) {
      final double minorStartY = (originScreenY % minorPixelsStep) - minorPixelsStep;
      for (double screenY = minorStartY; screenY <= (size.height + minorPixelsStep); screenY += minorPixelsStep) {
        final double distToMajor = ((screenY - originScreenY) % majorPixelsStep).abs();
        final bool onMajorLine   = (distToMajor < 1.0) || ((majorPixelsStep - distToMajor).abs() < 1.0);
        if (!onMajorLine) {
          canvas.drawLine(
            Offset(0.0, screenY),
            Offset(size.width, screenY),
            minorLinePaint,
          );
        }
      }
    }

    // Horizontal major grid lines
    final double majorStartY = (originScreenY % majorPixelsStep) - majorPixelsStep;
    for (double screenY = majorStartY; screenY <= (size.height + majorPixelsStep); screenY += majorPixelsStep) {
      canvas.drawLine(
        Offset(0.0, screenY),
        Offset(size.width, screenY),
        majorLinePaint,
      );
    }

    // Major grid intersections crosshairs
    const double halfArm = AppSizes.mapCrosshairLength;
    for (double screenX = majorStartX; screenX <= (size.width + majorPixelsStep); screenX += majorPixelsStep) {
      for (double screenY = majorStartY; screenY <= (size.height + majorPixelsStep); screenY += majorPixelsStep) {
        canvas.drawLine(
          Offset(screenX - halfArm, screenY),
          Offset(screenX + halfArm, screenY),
          crosshairPaint,
        );
        canvas.drawLine(
          Offset(screenX, screenY - halfArm),
          Offset(screenX, screenY + halfArm),
          crosshairPaint,
        );
      }
    }

    // 3. Render global continent landmasses if the world base map is downloaded
    if (this.isWorldMapDownloaded) {
      final Paint continentFillPaint = Paint()
        ..color = this.mapContinentColor
        ..style = PaintingStyle.fill
      ;
      final Paint continentBorderPaint = Paint()
        ..color       = this.mapContinentBorderColor
        ..strokeWidth = AppSizes.mapStrokeThin
        ..style       = PaintingStyle.stroke
      ;

      final List<List<math.Point<double>>> polygonList = WorldContinentsData.getContinentPolygonList();
      for (final List<math.Point<double>> pointList in polygonList) {
        if (pointList.length < 3) {
          continue;
        }

        final Path landmassPath  = Path();
        final Offset firstWorld  = _geoToWorldMeters(pointList.first.x, pointList.first.y);
        final Offset firstScreen = _worldMetersToScreen(firstWorld, center);
        landmassPath.moveTo(firstScreen.dx, firstScreen.dy);

        for (int pointIndex = 1; pointIndex < pointList.length; pointIndex++) {
          final Offset nextWorld  = _geoToWorldMeters(pointList[pointIndex].x, pointList[pointIndex].y);
          final Offset nextScreen = _worldMetersToScreen(nextWorld, center);
          landmassPath.lineTo(nextScreen.dx, nextScreen.dy);
        }
        landmassPath.close();

        canvas.drawPath(landmassPath, continentFillPaint);
        canvas.drawPath(landmassPath, continentBorderPaint);
      }

      // Render continental arterial highways on the base map
      final Paint highwayPaint = Paint()
        ..color       = this.mapHighwayColor
        ..strokeWidth = (this.zoom >= 0.0005) ? 2.5 : 1.5
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round
      ;

      for (final WorldHighwayModel highway in WorldCitiesData.getHighwayList()) {
        if (highway.pointList.length < 2) {
          continue;
        }

        final Path highwayPath   = Path();
        final Offset firstWorld  = _geoToWorldMeters(highway.pointList.first.x, highway.pointList.first.y);
        final Offset firstScreen = _worldMetersToScreen(firstWorld, center);
        highwayPath.moveTo(firstScreen.dx, firstScreen.dy);

        for (int i = 1; i < highway.pointList.length; i++) {
          final Offset nextWorld  = _geoToWorldMeters(highway.pointList[i].x, highway.pointList[i].y);
          final Offset nextScreen = _worldMetersToScreen(nextWorld, center);
          highwayPath.lineTo(nextScreen.dx, nextScreen.dy);
        }

        canvas.drawPath(highwayPath, highwayPaint);
      }
    }

    // 4. Render downloaded regional cells with full cartographic details (roads, streets, parks, 3D buildings)
    if (this.downloadedCellLevelMap.isNotEmpty) {
      for (final MapEntry<String, MapDetailLevel> entry in this.downloadedCellLevelMap.entries) {
        final GeoCellModel? parsedCell = GeoCellService.tryParseCellId(entry.key);
        if (parsedCell == null) {
          continue;
        }

        final Offset topLeftWorld     = _geoToWorldMeters(parsedCell.minLongitude, parsedCell.maxLatitude);
        final Offset bottomRightWorld = _geoToWorldMeters(parsedCell.maxLongitude, parsedCell.minLatitude);

        final Offset topLeftScreen     = _worldMetersToScreen(topLeftWorld, center);
        final Offset bottomRightScreen = _worldMetersToScreen(bottomRightWorld, center);

        final Rect cellRect = Rect.fromPoints(topLeftScreen, bottomRightScreen);

        // Viewport intersection check with margin
        const double margin = 100.0;
        if ((cellRect.right < -margin) ||
            (cellRect.left > (size.width + margin)) ||
            (cellRect.bottom < -margin) ||
            (cellRect.top > (size.height + margin))) {
          continue;
        }

        _paintDownloadedCellDetails(
          canvas    : canvas,
          center    : center,
          parsedCell: parsedCell,
          cellRect  : cellRect,
          level     : entry.value,
        );
      }
    }

    // 4b. Render city landmarks and toponyms if the world base map is downloaded
    if (this.isWorldMapDownloaded) {
      final Paint cityDotPaint = Paint()
        ..color = this.mapCityMarkerColor
        ..style = PaintingStyle.fill
      ;
      final Paint cityStrokePaint = Paint()
        ..color       = this.whiteColor
        ..strokeWidth = AppSizes.mapStrokeThin
        ..style       = PaintingStyle.stroke
      ;

      for (final WorldCityModel city in WorldCitiesData.getCityList()) {
        if ((city.tier == 2) && (this.zoom < 0.0002)) {
          continue;
        }
        if ((city.tier == 1) && (this.zoom < 0.00003)) {
          continue;
        }

        final Offset cityWorld  = _geoToWorldMeters(city.longitude, city.latitude);
        final Offset cityScreen = _worldMetersToScreen(cityWorld, center);

        if ((cityScreen.dx < -50.0) ||
            (cityScreen.dx > (size.width + 50.0)) ||
            (cityScreen.dy < -50.0) ||
            (cityScreen.dy > (size.height + 50.0))) {
          continue;
        }

        final double dotRadius = (city.tier == 1) ? 3.5 : 2.5;
        canvas.drawCircle(cityScreen, dotRadius, cityDotPaint);
        canvas.drawCircle(cityScreen, dotRadius, cityStrokePaint);

        if (this.zoom >= 0.00007) {
          final TextSpan textSpan = TextSpan(
            text : city.name,
            style: TextStyle(
              fontSize  : (city.tier == 1) ? AppSizes.font11 : AppSizes.font10,
              fontWeight: (city.tier == 1) ? FontWeight.bold : FontWeight.w600,
              color     : this.mapCityLabelColor,
              shadows   : [
                Shadow(
                  color     : this.mapVoidColor,
                  blurRadius: AppSizes.p2,
                  offset    : const Offset(1.0, 1.0),
                ),
              ],
            ),
          );

          final TextPainter textPainter = TextPainter(
            text         : textSpan,
            textDirection: TextDirection.ltr,
          )..layout();

          textPainter.paint(
            canvas,
            Offset(cityScreen.dx + dotRadius + 3.0, cityScreen.dy - (textPainter.height / 2.0)),
          );
        }
      }
    }

    // 5. Draw the user's position indicator in the cartographic space
    if (this.userWorldMeters != null) {
      final double userScreenX   = center.dx + ((this.userWorldMeters!.dx - this.cameraWorldMeters.dx) * this.zoom);
      final double userScreenY   = center.dy - ((this.userWorldMeters!.dy - this.cameraWorldMeters.dy) * this.zoom);
      final Offset userScreenPos = Offset(userScreenX, userScreenY);

      const double margin         = AppSizes.icon64;
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

          final Paint innerDotPaint = Paint()
            ..color = this.whiteColor
            ..style = PaintingStyle.fill
          ;
          canvas.drawCircle(const Offset(0.0, AppSizes.p2), AppSizes.p4, innerDotPaint);

          canvas.restore();
        }else {
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

    canvas.restore();
  }

  /// Resolves the semantic name of a local district or city within [cell].
  String _resolveDistrictName(GeoCellModel cell) {
    for (final WorldCityModel city in WorldCitiesData.getCityList()) {
      if ((city.longitude >= cell.minLongitude) && (city.longitude <= cell.maxLongitude) &&
          (city.latitude >= cell.minLatitude) && (city.latitude <= cell.maxLatitude)) {
        return city.name;
      }
    }
    final String latStr = cell.centerLatitude.abs().toStringAsFixed(1);
    final String lonStr = cell.centerLongitude.abs().toStringAsFixed(1);
    final String latH   = (cell.centerLatitude >= 0) ? 'N' : 'S';
    final String lonH   = (cell.centerLongitude >= 0) ? 'E' : 'W';
    return '$latStr°$latH, $lonStr°$lonH';
  }

  /// Renders a circular POI pin with [symbol] and [color].
  void _paintPoiMarker(Canvas canvas, Offset position, String symbol, Color color) {
    final Paint bgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
    ;
    final Paint borderPaint = Paint()
      ..color       = this.whiteColor
      ..strokeWidth = 1.0
      ..style       = PaintingStyle.stroke
    ;
    canvas.drawCircle(position, 8.0, bgPaint);
    canvas.drawCircle(position, 8.0, borderPaint);

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text         : TextSpan(
        text : symbol,
        style: TextStyle(
          fontSize  : 8.5,
          fontWeight: FontWeight.bold,
          color     : this.whiteColor,
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - (textPainter.width / 2.0), position.dy - (textPainter.height / 2.0)),
    );
  }

  /// Paints rich cartographic details (land surface, arteries, street network, parks, rivers, 3D buildings, and POIs) for a downloaded cell.
  void _paintDownloadedCellDetails({
    required Canvas canvas,
    required Offset center,
    required GeoCellModel parsedCell,
    required Rect cellRect,
    required MapDetailLevel level,
  }) {
    final Color levelColor = _getLevelColor(level);

    // 1. Solid Cartographic Land Surface: fully replaces void in downloaded territory
    final Paint landFillPaint = Paint()
      ..color = this.mapContinentColor.withValues(alpha: 0.98)
      ..style = PaintingStyle.fill
    ;
    canvas.drawRect(cellRect, landFillPaint);

    // 2. Natural Features: Green park zone & Waterway
    final double parkLeft   = cellRect.left + (cellRect.width * 0.15);
    final double parkTop    = cellRect.top + (cellRect.height * 0.15);
    final double parkWidth  = cellRect.width * 0.28;
    final double parkHeight = cellRect.height * 0.28;
    final RRect parkRRect   = RRect.fromRectAndRadius(
      Rect.fromLTWH(parkLeft, parkTop, parkWidth, parkHeight),
      const Radius.circular(AppSizes.radius8),
    );

    final Paint parkPaint = Paint()
      ..color = const Color(0x3310B981)
      ..style = PaintingStyle.fill
    ;
    canvas.drawRRect(parkRRect, parkPaint);

    // Flowing river / waterway across the cell
    final Path riverPath = Path()
      ..moveTo(cellRect.left, cellRect.top + (cellRect.height * 0.65))
      ..cubicTo(
        cellRect.left + (cellRect.width * 0.35), cellRect.top + (cellRect.height * 0.55),
        cellRect.left + (cellRect.width * 0.65), cellRect.top + (cellRect.height * 0.85),
        cellRect.right, cellRect.top + (cellRect.height * 0.70),
      )
    ;
    final Paint riverPaint = Paint()
      ..color       = const Color(0x7338BDF8)
      ..strokeWidth = (this.zoom >= 0.005) ? 4.0 : 2.0
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
    ;
    canvas.drawPath(riverPath, riverPaint);

    // 3. Primary Arteries & Radial Corridors (Base, Detailed, Complete)
    final Offset cellCenter = cellRect.center;

    final Paint arteryCasingPaint = Paint()
      ..color       = this.mapVoidColor.withValues(alpha: 0.85)
      ..strokeWidth = (this.zoom >= 0.005) ? 5.0 : 3.0
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
    ;

    final Paint arteryFillPaint = Paint()
      ..color       = this.mapHighwayColor
      ..strokeWidth = (this.zoom >= 0.005) ? 3.5 : 2.0
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
    ;

    // East-West Primary Artery
    final Offset ewStart = Offset(cellRect.left, cellCenter.dy);
    final Offset ewEnd   = Offset(cellRect.right, cellCenter.dy);
    canvas.drawLine(ewStart, ewEnd, arteryCasingPaint);
    canvas.drawLine(ewStart, ewEnd, arteryFillPaint);

    // North-South Primary Artery
    final Offset nsStart = Offset(cellCenter.dx, cellRect.top);
    final Offset nsEnd   = Offset(cellCenter.dx, cellRect.bottom);
    canvas.drawLine(nsStart, nsEnd, arteryCasingPaint);
    canvas.drawLine(nsStart, nsEnd, arteryFillPaint);

    // Central Bypass / Ring Road
    final double ringRadius = (cellRect.width * 0.14).clamp(12.0, 160.0);
    canvas.drawCircle(cellCenter, ringRadius, arteryCasingPaint);
    canvas.drawCircle(cellCenter, ringRadius, arteryFillPaint);

    // 4. Urban Secondary Roads and Street Grid (Z >= 0.0004 or cellRect.width >= 60.0)
    if (cellRect.width >= 60.0) {
      final Paint secondaryRoadPaint = Paint()
        ..color       = this.whiteColor.withValues(alpha: 0.70)
        ..strokeWidth = (this.zoom >= 0.005) ? 2.2 : 1.2
        ..style       = PaintingStyle.stroke
      ;

      const int subdivisions = 6;
      final double stepX     = cellRect.width / subdivisions;
      final double stepY     = cellRect.height / subdivisions;

      for (int i = 1; i < subdivisions; i++) {
        if (i == 3) {
          continue; // Skip primary center artery already drawn
        }
        final double x = cellRect.left + (stepX * i);
        canvas.drawLine(Offset(x, cellRect.top), Offset(x, cellRect.bottom), secondaryRoadPaint);

        final double y = cellRect.top + (stepY * i);
        canvas.drawLine(Offset(cellRect.left, y), Offset(cellRect.right, y), secondaryRoadPaint);
      }
    }

    // 5. Pedestrian Trails & Local Paths (Detailed & Complete, Z >= 0.002)
    if ((level != MapDetailLevel.base) && (cellRect.width >= 120.0)) {
      final Paint trailPaint = Paint()
        ..color       = const Color(0xFF10B981)
        ..strokeWidth = 1.4
        ..style       = PaintingStyle.stroke
      ;

      final Path parkTrail = Path()
        ..moveTo(parkLeft, parkTop + (parkHeight * 0.5))
        ..lineTo(parkLeft + (parkWidth * 0.5), parkTop + (parkHeight * 0.8))
        ..lineTo(parkLeft + parkWidth, parkTop + (parkHeight * 0.3))
      ;
      canvas.drawPath(parkTrail, trailPaint);
    }

    // 6. 3D Isometric Buildings & Blocks (Complete, Z >= 0.005 or cellRect.width >= 250.0)
    if ((level == MapDetailLevel.complete) && (cellRect.width >= 250.0)) {
      final Paint buildingWallPaint = Paint()
        ..color = this.mapVoidColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill
      ;
      final Paint buildingRoofPaint = Paint()
        ..color = this.whiteColor.withValues(alpha: 0.88)
        ..style = PaintingStyle.fill
      ;
      final Paint buildingBorderPaint = Paint()
        ..color       = this.mapVoidColor
        ..strokeWidth = 0.8
        ..style       = PaintingStyle.stroke
      ;

      const double buildingWidth  = 24.0;
      const double buildingHeight = 16.0;
      const double extrudeY       = 6.0;

      final List<Offset> blockPosList = [
        Offset(cellCenter.dx + 40.0, cellCenter.dy + 35.0),
        Offset(cellCenter.dx + 80.0, cellCenter.dy + 35.0),
        Offset(cellCenter.dx + 40.0, cellCenter.dy + 70.0),
        Offset(cellCenter.dx - 90.0, cellCenter.dy - 60.0),
        Offset(cellCenter.dx - 55.0, cellCenter.dy - 60.0),
      ];

      for (final Offset pos in blockPosList) {
        if ((pos.dx > cellRect.left) && ((pos.dx + buildingWidth) < cellRect.right) &&
            (pos.dy > cellRect.top) && ((pos.dy + buildingHeight) < cellRect.bottom)) {
          final Path wallPath = Path()
            ..moveTo(pos.dx, pos.dy + buildingHeight)
            ..lineTo(pos.dx, pos.dy + buildingHeight - extrudeY)
            ..lineTo(pos.dx + buildingWidth, pos.dy + buildingHeight - extrudeY)
            ..lineTo(pos.dx + buildingWidth, pos.dy + buildingHeight)
            ..close()
          ;
          canvas.drawPath(wallPath, buildingWallPaint);

          final Rect roofRect = Rect.fromLTWH(pos.dx, pos.dy - extrudeY, buildingWidth, buildingHeight);
          canvas.drawRect(roofRect, buildingRoofPaint);
          canvas.drawRect(roofRect, buildingBorderPaint);
        }
      }
    }

    // 7. Toponomastic Labels (District / Town & Street Names)
    if (cellRect.width >= 80.0) {
      final String districtName      = _resolveDistrictName(parsedCell);
      final TextPainter labelPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text         : TextSpan(
          text : districtName,
          style: TextStyle(
            fontSize  : (cellRect.width >= 200.0) ? AppSizes.font13 : AppSizes.font11,
            fontWeight: FontWeight.bold,
            color     : this.mapCityLabelColor,
            shadows   : [
              Shadow(
                color     : this.mapVoidColor.withValues(alpha: 0.9),
                offset    : const Offset(1, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(cellCenter.dx - (labelPainter.width / 2.0), cellCenter.dy - ringRadius - labelPainter.height - 4.0),
      );

      // Street names when zoomed in close (Z >= 0.005)
      if (cellRect.width >= 260.0) {
        final TextPainter streetPainter = TextPainter(
          textDirection: TextDirection.ltr,
          text         : TextSpan(
            text : 'Corso Principale',
            style: TextStyle(
              fontSize  : AppSizes.font10,
              fontWeight: FontWeight.w600,
              color     : this.mapCityLabelColor.withValues(alpha: 0.8),
            ),
          ),
        );
        streetPainter.layout();
        streetPainter.paint(
          canvas,
          Offset(cellCenter.dx + 25.0, cellCenter.dy + 4.0),
        );
      }
    }

    // 8. Points of Interest (Complete, Z >= 0.003 or cellRect.width >= 180.0)
    if ((level == MapDetailLevel.complete) && (cellRect.width >= 180.0)) {
      _paintPoiMarker(canvas, Offset(cellCenter.dx - 35.0, cellCenter.dy - 35.0), 'P', const Color(0xFF2563EB));
      _paintPoiMarker(canvas, Offset(cellCenter.dx + 55.0, cellCenter.dy - 45.0), '+', const Color(0xFFDC2626));
      _paintPoiMarker(canvas, Offset(cellCenter.dx - 45.0, cellCenter.dy + 50.0), '⛽', const Color(0xFFD97706));
    }

    // 9. Outer Cell Border with semantic level color
    final Paint borderPaint = Paint()
      ..color       = levelColor.withValues(alpha: 0.85)
      ..strokeWidth = (cellRect.width >= 40.0) ? AppSizes.mapStrokeRegular : AppSizes.mapStrokeThin
      ..style       = PaintingStyle.stroke
    ;
    canvas.drawRect(cellRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant MapGridPainter oldDelegate) {
    return (oldDelegate.cameraWorldMeters != this.cameraWorldMeters) ||
      (oldDelegate.zoom != this.zoom) ||
      (oldDelegate.userWorldMeters != this.userWorldMeters) ||
      (oldDelegate.userAccuracy != this.userAccuracy) ||
      (oldDelegate.userHeading != this.userHeading) ||
      (oldDelegate.pulseProgress != this.pulseProgress) ||
      (oldDelegate.isWorldMapDownloaded != this.isWorldMapDownloaded) ||
      (oldDelegate.downloadedCellLevelMap != this.downloadedCellLevelMap) ||
      (oldDelegate.referenceLat != this.referenceLat) ||
      (oldDelegate.referenceLon != this.referenceLon) ||
      (oldDelegate.mapVoidColor != this.mapVoidColor) ||
      (oldDelegate.mapContinentColor != this.mapContinentColor) ||
      (oldDelegate.mapContinentBorderColor != this.mapContinentBorderColor) ||
      (oldDelegate.gridMajorColor != this.gridMajorColor) ||
      (oldDelegate.gridMinorColor != this.gridMinorColor) ||
      (oldDelegate.gridCrosshairColor != this.gridCrosshairColor) ||
      (oldDelegate.userPulseColor != this.userPulseColor) ||
      (oldDelegate.userAccuracyColor != this.userAccuracyColor) ||
      (oldDelegate.primaryColor != this.primaryColor) ||
      (oldDelegate.whiteColor != this.whiteColor) ||
      (oldDelegate.detailBaseColor != this.detailBaseColor) ||
      (oldDelegate.detailDetailedColor != this.detailDetailedColor) ||
      (oldDelegate.detailCompleteColor != this.detailCompleteColor) ||
      (oldDelegate.mapHighwayColor != this.mapHighwayColor) ||
      (oldDelegate.mapCityMarkerColor != this.mapCityMarkerColor) ||
      (oldDelegate.mapCityLabelColor != this.mapCityLabelColor);
  }
}
