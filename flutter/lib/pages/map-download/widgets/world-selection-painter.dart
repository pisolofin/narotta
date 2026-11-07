import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../constants/app-sizes.dart';
import '../../../services/geo-cell-service.dart';
import '../../../services/map-download-service.dart';

import 'world-cities-data.dart';
import 'world-continents-data.dart';

/// Custom painter rendering the zoomable world map, adaptive degree grid, downloaded zones by detail level, active selection, and freehand lasso.
class WorldSelectionPainter extends CustomPainter {
  static const double latitudeAspectFactor = 1.22;

  final double cameraLongitude;
  final double cameraLatitude;
  final double pixelsPerDegree;
  final List<Offset> currentLassoScreenPointList;
  final List<GeoCellModel> selectedCellList;
  final Map<String, MapDetailLevel> downloadedCellLevelMap;
  final bool isDrawingLasso;
  final double? userLongitude;
  final double? userLatitude;
  final Color backgroundColor;
  final Color continentFillColor;
  final Color continentBorderColor;
  final Color minorGridColor;
  final Color majorGridColor;
  final Color selectionColor;
  final Color selectionContrastColor;
  final Color detailBaseColor;
  final Color detailDetailedColor;
  final Color detailCompleteColor;
  final Color userMarkerColor;
  final Color textColor;
  final Color mapHighwayColor;
  final Color mapCityMarkerColor;
  final Color mapCityLabelColor;

  const WorldSelectionPainter({
    required this.cameraLongitude,
    required this.cameraLatitude,
    required this.pixelsPerDegree,
    required this.currentLassoScreenPointList,
    required this.selectedCellList,
    required this.downloadedCellLevelMap,
    required this.isDrawingLasso,
    required this.userLongitude,
    required this.userLatitude,
    required this.backgroundColor,
    required this.continentFillColor,
    required this.continentBorderColor,
    required this.minorGridColor,
    required this.majorGridColor,
    required this.selectionColor,
    required this.selectionContrastColor,
    required this.detailBaseColor,
    required this.detailDetailedColor,
    required this.detailCompleteColor,
    required this.userMarkerColor,
    required this.textColor,
    required this.mapHighwayColor,
    required this.mapCityMarkerColor,
    required this.mapCityLabelColor,
  });

  /// Projects geographic (longitude, latitude) coordinates onto canvas screen coordinates.
  Offset _geoToScreen(double longitude, double latitude, Offset canvasCenter) {
    final double screenX = canvasCenter.dx + ((longitude - this.cameraLongitude) * this.pixelsPerDegree);
    final double screenY = canvasCenter.dy - ((latitude - this.cameraLatitude) * this.pixelsPerDegree * latitudeAspectFactor);
    return Offset(screenX, screenY);
  }

  /// Resolves the color associated with a downloaded [MapDetailLevel].
  Color _getColorForLevel(MapDetailLevel level) {
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

    // 1. Fill ocean background
    final Paint backgroundPaint = Paint()
      ..color = this.backgroundColor
      ..style = PaintingStyle.fill
    ;
    canvas.drawRect(viewportRect, backgroundPaint);

    final Offset canvasCenter    = Offset(size.width / 2.0, size.height / 2.0);
    final double pixelsPerLatDeg = this.pixelsPerDegree * latitudeAspectFactor;
    final double halfSpanLon     = (size.width / 2.0) / this.pixelsPerDegree;
    final double halfSpanLat     = (size.height / 2.0) / pixelsPerLatDeg;
    final double visibleMinLon   = (this.cameraLongitude - halfSpanLon).clamp(-180.0, 180.0);
    final double visibleMaxLon   = (this.cameraLongitude + halfSpanLon).clamp(-180.0, 180.0);
    final double visibleMinLat   = (this.cameraLatitude - halfSpanLat).clamp(-90.0, 90.0);
    final double visibleMaxLat   = (this.cameraLatitude + halfSpanLat).clamp(-90.0, 90.0);

    // 2. Render world landmasses and major islands
    final Paint continentFillPaint = Paint()
      ..color = this.continentFillColor
      ..style = PaintingStyle.fill
    ;
    final Paint continentBorderPaint = Paint()
      ..color       = this.continentBorderColor
      ..strokeWidth = AppSizes.mapStrokeThin
      ..style       = PaintingStyle.stroke
    ;

    final List<List<math.Point<double>>> polygonList = WorldContinentsData.getContinentPolygonList();
    for (final List<math.Point<double>> pointList in polygonList) {
      if (pointList.length < 3) {
        continue;
      }
      final Path landmassPath = Path();
      final Offset firstPoint = _geoToScreen(pointList.first.x, pointList.first.y, canvasCenter);
      landmassPath.moveTo(firstPoint.dx, firstPoint.dy);
      for (int pointIndex = 1; pointIndex < pointList.length; pointIndex++) {
        final Offset nextPoint = _geoToScreen(pointList[pointIndex].x, pointList[pointIndex].y, canvasCenter);
        landmassPath.lineTo(nextPoint.dx, nextPoint.dy);
      }
      landmassPath.close();
      canvas.drawPath(landmassPath, continentFillPaint);
      canvas.drawPath(landmassPath, continentBorderPaint);
    }

    // Arterial highway spines
    final Paint highwayPaint = Paint()
      ..color       = this.mapHighwayColor
      ..strokeWidth = (this.pixelsPerDegree >= 20.0) ? 2.0 : 1.2
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round
    ;

    for (final WorldHighwayModel highway in WorldCitiesData.getHighwayList()) {
      if (highway.pointList.length < 2) {
        continue;
      }

      final Path highwayPath  = Path();
      final Offset firstPoint = _geoToScreen(highway.pointList.first.x, highway.pointList.first.y, canvasCenter);
      highwayPath.moveTo(firstPoint.dx, firstPoint.dy);
      for (int i = 1; i < highway.pointList.length; i++) {
        final Offset nextPoint = _geoToScreen(highway.pointList[i].x, highway.pointList[i].y, canvasCenter);
        highwayPath.lineTo(nextPoint.dx, nextPoint.dy);
      }
      canvas.drawPath(highwayPath, highwayPaint);
    }

    // 3. Render adaptive geographic grid (0.5° cells when zoomed in, graticule when zoomed out)
    final double cellPixelWidth = GeoCellService.cellSizeDegrees * this.pixelsPerDegree;
    if (cellPixelWidth >= 5.5) {
      _paintFineCellGrid(
        canvas,
        canvasCenter,
        visibleMinLon,
        visibleMaxLon,
        visibleMinLat,
        visibleMaxLat,
      );
    }else {
      _paintGlobalGraticule(
        canvas,
        canvasCenter,
        visibleMinLon,
        visibleMaxLon,
        visibleMinLat,
        visibleMaxLat,
      );
    }

    // 4. Render already downloaded cells with legend level colors
    for (final MapEntry<String, MapDetailLevel> entry in this.downloadedCellLevelMap.entries) {
      final GeoCellModel? parsedCell = GeoCellService.tryParseCellId(entry.key);
      if (parsedCell == null) {
        continue;
      }
      if ((parsedCell.maxLongitude < visibleMinLon) ||
          (parsedCell.minLongitude > visibleMaxLon) ||
          (parsedCell.maxLatitude < visibleMinLat) ||
          (parsedCell.minLatitude > visibleMaxLat)) {
        continue;
      }

      final Color levelColor = _getColorForLevel(entry.value);
      final Rect rawRect     = Rect.fromPoints(
        _geoToScreen(parsedCell.minLongitude, parsedCell.maxLatitude, canvasCenter),
        _geoToScreen(parsedCell.maxLongitude, parsedCell.minLatitude, canvasCenter),
      );
      final Rect visibleCellRect = _ensureMinimumCellRect(rawRect, 3.0);

      final Paint downloadedFillPaint = Paint()
        ..color = levelColor.withValues(alpha: 0.42)
        ..style = PaintingStyle.fill
      ;
      canvas.drawRect(visibleCellRect, downloadedFillPaint);

      if (visibleCellRect.width >= 4.0) {
        final Paint downloadedBorderPaint = Paint()
          ..color       = levelColor
          ..strokeWidth = (visibleCellRect.width >= 14.0) ? AppSizes.mapStrokeRegular : AppSizes.mapStrokeThin
          ..style       = PaintingStyle.stroke
        ;
        canvas.drawRect(visibleCellRect, downloadedBorderPaint);
      }
    }

    // 5. Render currently selected cells
    if (this.selectedCellList.isNotEmpty) {
      final Paint selectedFillPaint = Paint()
        ..color = this.selectionColor.withValues(alpha: 0.30)
        ..style = PaintingStyle.fill
      ;
      final Paint selectedBorderPaint = Paint()
        ..color       = this.selectionColor
        ..strokeWidth = (cellPixelWidth >= 8.0) ? AppSizes.mapStrokeThick : AppSizes.mapStrokeRegular
        ..style       = PaintingStyle.stroke
      ;
      final Paint selectedInnerContrastPaint = Paint()
        ..color       = this.selectionContrastColor.withValues(alpha: 0.85)
        ..strokeWidth = AppSizes.mapStrokeThin
        ..style       = PaintingStyle.stroke
      ;

      final TextPainter labelPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );

      for (final GeoCellModel cell in this.selectedCellList) {
        if ((cell.maxLongitude < visibleMinLon) ||
            (cell.minLongitude > visibleMaxLon) ||
            (cell.maxLatitude < visibleMinLat) ||
            (cell.minLatitude > visibleMaxLat)) {
          continue;
        }

        final Rect rawRect         = Rect.fromPoints(
          _geoToScreen(cell.minLongitude, cell.maxLatitude, canvasCenter),
          _geoToScreen(cell.maxLongitude, cell.minLatitude, canvasCenter),
        );
        final Rect visibleCellRect = _ensureMinimumCellRect(rawRect, 3.5);

        canvas.drawRect(visibleCellRect, selectedFillPaint);
        if (visibleCellRect.width >= 14.0) {
          canvas.drawRect(visibleCellRect.deflate(1.5), selectedInnerContrastPaint);
        }
        canvas.drawRect(visibleCellRect, selectedBorderPaint);

        if (visibleCellRect.width >= 68.0) {
          labelPainter.text = TextSpan(
            text : cell.cellId,
            style: TextStyle(
              fontSize  : AppSizes.font10,
              fontWeight: FontWeight.bold,
              color     : this.textColor,
            ),
          );
          labelPainter.layout();
          labelPainter.paint(
            canvas,
            Offset(visibleCellRect.left + AppSizes.p4, visibleCellRect.top + AppSizes.p4),
          );
        }
      }
    }

    // Render cities landmarks and labels
    final Paint cityDotPaint = Paint()
      ..color = this.mapCityMarkerColor
      ..style = PaintingStyle.fill
    ;
    final Paint cityStrokePaint = Paint()
      ..color       = this.selectionContrastColor
      ..strokeWidth = AppSizes.mapStrokeThin
      ..style       = PaintingStyle.stroke
    ;

    final TextPainter cityTextPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final WorldCityModel city in WorldCitiesData.getCityList()) {
      if ((city.tier == 2) && (this.pixelsPerDegree < 8.0)) {
        continue;
      }
      if ((city.tier == 1) && (this.pixelsPerDegree < 2.0)) {
        continue;
      }

      final Offset cityScreen = _geoToScreen(city.longitude, city.latitude, canvasCenter);
      if ((cityScreen.dx < -50.0) ||
          (cityScreen.dx > (size.width + 50.0)) ||
          (cityScreen.dy < -50.0) ||
          (cityScreen.dy > (size.height + 50.0))) {
        continue;
      }

      final double dotRadius = (city.tier == 1) ? 3.5 : 2.5;
      canvas.drawCircle(cityScreen, dotRadius, cityDotPaint);
      canvas.drawCircle(cityScreen, dotRadius, cityStrokePaint);

      if ((this.pixelsPerDegree >= 4.0) || (city.tier == 1)) {
        cityTextPainter.text = TextSpan(
          text : city.name,
          style: TextStyle(
            fontSize  : (city.tier == 1) ? AppSizes.font11 : AppSizes.font10,
            fontWeight: (city.tier == 1) ? FontWeight.bold : FontWeight.w600,
            color     : this.mapCityLabelColor,
            shadows   : [
              Shadow(
                color     : this.backgroundColor.withValues(alpha: 0.9),
                offset    : const Offset(1, 1),
                blurRadius: 3,
              ),
            ],
          ),
        );
        cityTextPainter.layout();
        cityTextPainter.paint(
          canvas,
          Offset(cityScreen.dx + dotRadius + 3.0, cityScreen.dy - (cityTextPainter.height / 2.0)),
        );
      }
    }

    // 6. Render user GPS marker if available
    if ((this.userLongitude != null) && (this.userLatitude != null)) {
      final Offset markerCenter = _geoToScreen(this.userLongitude!, this.userLatitude!, canvasCenter);
      if (viewportRect.contains(markerCenter)) {
        final Paint haloPaint = Paint()
          ..color = this.userMarkerColor.withValues(alpha: 0.24)
          ..style = PaintingStyle.fill
        ;
        final Paint dotBorderPaint = Paint()
          ..color = this.selectionContrastColor
          ..style = PaintingStyle.fill
        ;
        final Paint dotFillPaint = Paint()
          ..color = this.userMarkerColor
          ..style = PaintingStyle.fill
        ;
        canvas.drawCircle(markerCenter, AppSizes.p10, haloPaint);
        canvas.drawCircle(markerCenter, AppSizes.p6, dotBorderPaint);
        canvas.drawCircle(markerCenter, AppSizes.p4, dotFillPaint);
      }
    }

    // 7. Render active freehand lasso stroke
    if (this.currentLassoScreenPointList.length >= 2) {
      final Path lassoPath = Path();
      lassoPath.moveTo(
        this.currentLassoScreenPointList.first.dx,
        this.currentLassoScreenPointList.first.dy,
      );
      for (int pointIndex = 1; pointIndex < this.currentLassoScreenPointList.length; pointIndex++) {
        lassoPath.lineTo(
          this.currentLassoScreenPointList[pointIndex].dx,
          this.currentLassoScreenPointList[pointIndex].dy,
        );
      }

      if (this.isDrawingLasso) {
        final Paint lassoFillPaint = Paint()
          ..color = this.selectionColor.withValues(alpha: 0.14)
          ..style = PaintingStyle.fill
        ;
        final Path closedPreviewPath = Path.from(lassoPath)..close();
        canvas.drawPath(closedPreviewPath, lassoFillPaint);
      }

      final Paint lassoStrokePaint = Paint()
        ..color       = this.selectionColor
        ..strokeWidth = AppSizes.mapStrokeThick
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round
        ..style       = PaintingStyle.stroke
      ;
      canvas.drawPath(lassoPath, lassoStrokePaint);
    }

    canvas.restore();
  }

  /// Ensures tiny cells remain visible when zoomed out to continental/global scale.
  Rect _ensureMinimumCellRect(Rect rawRect, double minDimension) {
    final double targetWidth  = math.max(rawRect.width, minDimension);
    final double targetHeight = math.max(rawRect.height, minDimension);
    return Rect.fromCenter(
      center: rawRect.center,
      width : targetWidth,
      height: targetHeight,
    );
  }

  /// Draws the 0.5° × 0.5° cell grid and 5° major lines when zoomed in.
  void _paintFineCellGrid(
    Canvas canvas,
    Offset canvasCenter,
    double visibleMinLon,
    double visibleMaxLon,
    double visibleMinLat,
    double visibleMaxLat,
  ) {
    final Paint minorPaint = Paint()
      ..color       = this.minorGridColor
      ..strokeWidth = AppSizes.borderWidthThin
      ..style       = PaintingStyle.stroke
    ;
    final Paint majorPaint = Paint()
      ..color       = this.majorGridColor
      ..strokeWidth = AppSizes.mapStrokeThin
      ..style       = PaintingStyle.stroke
    ;

    final int startLonIndex = ((visibleMinLon + 180.0) / GeoCellService.cellSizeDegrees).floor();
    final int endLonIndex   = ((visibleMaxLon + 180.0) / GeoCellService.cellSizeDegrees).ceil();
    final int startLatIndex = ((visibleMinLat + 90.0) / GeoCellService.cellSizeDegrees).floor();
    final int endLatIndex   = ((visibleMaxLat + 90.0) / GeoCellService.cellSizeDegrees).ceil();

    for (int lonIndex = startLonIndex; lonIndex <= endLonIndex; lonIndex++) {
      final double lon      = -180.0 + (lonIndex * GeoCellService.cellSizeDegrees);
      final Offset topPoint = _geoToScreen(lon, visibleMaxLat, canvasCenter);
      final Offset btmPoint = _geoToScreen(lon, visibleMinLat, canvasCenter);
      final bool isMajor    = (lonIndex % 10) == 0;
      canvas.drawLine(topPoint, btmPoint, isMajor ? majorPaint : minorPaint);
    }

    for (int latIndex = startLatIndex; latIndex <= endLatIndex; latIndex++) {
      final double lat      = -90.0 + (latIndex * GeoCellService.cellSizeDegrees);
      final Offset lftPoint = _geoToScreen(visibleMinLon, lat, canvasCenter);
      final Offset rgtPoint = _geoToScreen(visibleMaxLon, lat, canvasCenter);
      final bool isMajor    = (latIndex % 10) == 0;
      canvas.drawLine(lftPoint, rgtPoint, isMajor ? majorPaint : minorPaint);
    }
  }

  /// Draws a clean 15° graticule when viewing the whole world or continents.
  void _paintGlobalGraticule(
    Canvas canvas,
    Offset canvasCenter,
    double visibleMinLon,
    double visibleMaxLon,
    double visibleMinLat,
    double visibleMaxLat,
  ) {
    const double graticuleStepDegrees = 15.0;
    final Paint graticulePaint        = Paint()
      ..color       = this.majorGridColor
      ..strokeWidth = AppSizes.borderWidthThin
      ..style       = PaintingStyle.stroke
    ;

    final int startLonStep = (visibleMinLon / graticuleStepDegrees).floor();
    final int endLonStep   = (visibleMaxLon / graticuleStepDegrees).ceil();
    final int startLatStep = (visibleMinLat / graticuleStepDegrees).floor();
    final int endLatStep   = (visibleMaxLat / graticuleStepDegrees).ceil();

    for (int lonStep = startLonStep; lonStep <= endLonStep; lonStep++) {
      final double lon = (lonStep * graticuleStepDegrees).clamp(-180.0, 180.0);
      canvas.drawLine(
        _geoToScreen(lon, 85.0, canvasCenter),
        _geoToScreen(lon, -85.0, canvasCenter),
        graticulePaint,
      );
    }

    for (int latStep = startLatStep; latStep <= endLatStep; latStep++) {
      final double lat = (latStep * graticuleStepDegrees).clamp(-75.0, 75.0);
      canvas.drawLine(
        _geoToScreen(-180.0, lat, canvasCenter),
        _geoToScreen(180.0, lat, canvasCenter),
        graticulePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WorldSelectionPainter oldDelegate) {
    return true;
  }
}
