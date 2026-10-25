import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'world-continents-data.dart';
import '../../../constants/app-sizes.dart';
import '../../../services/geo-cell-service.dart';
import '../../../services/map-download-service.dart';

/// Painter rendering the world continent landmasses, 0.5° × 0.5° cell grid, already downloaded cells with detail colors, user drawn lasso, and selected cell highlights.
class CircleDownloadPainter extends CustomPainter {
  final Offset cameraWorldMeters;
  final double zoom;
  final double referenceLat;
  final double referenceLon;
  final List<Offset> currentLassoScreenPointList;
  final List<GeoCellModel> selectedCellList;
  final Map<String, MapDetailLevel> downloadedCellLevelMap;
  final bool isDrawing;
  final Color backgroundColor;
  final Color continentFillColor;
  final Color continentBorderColor;
  final Color gridLineColor;
  final Color lassoStrokeColor;
  final Color lassoFillColor;
  final Color cellSelectedFillColor;
  final Color cellSelectedBorderColor;
  final Color detailBaseColor;
  final Color detailDetailedColor;
  final Color detailCompleteColor;
  final Color textColor;

  const CircleDownloadPainter({
    required this.cameraWorldMeters,
    required this.zoom,
    required this.referenceLat,
    required this.referenceLon,
    required this.currentLassoScreenPointList,
    required this.selectedCellList,
    required this.downloadedCellLevelMap,
    required this.isDrawing,
    required this.backgroundColor,
    required this.continentFillColor,
    required this.continentBorderColor,
    required this.gridLineColor,
    required this.lassoStrokeColor,
    required this.lassoFillColor,
    required this.cellSelectedFillColor,
    required this.cellSelectedBorderColor,
    required this.detailBaseColor,
    required this.detailDetailedColor,
    required this.detailCompleteColor,
    required this.textColor,
  });

  static const double _metersPerDegreeLat = 111320.0;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fill ocean/canvas void background
    final Paint bgPaint = Paint()
      ..color = this.backgroundColor
      ..style = PaintingStyle.fill
    ;
    canvas.drawRect(Rect.fromLTWH(0.0, 0.0, size.width, size.height), bgPaint);

    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final double latRadians = this.referenceLat * math.pi / 180.0;
    final double metersPerDegreeLon = _metersPerDegreeLat * math.cos(latRadians);

    // Helper: converts lon/lat to screen Offset
    Offset geoToScreen(double lon, double lat) {
      final double worldX = (lon - this.referenceLon) * metersPerDegreeLon;
      final double worldY = (lat - this.referenceLat) * _metersPerDegreeLat;
      final double screenX = center.dx + ((worldX - this.cameraWorldMeters.dx) * this.zoom);
      final double screenY = center.dy - ((worldY - this.cameraWorldMeters.dy) * this.zoom);
      return Offset(screenX, screenY);
    }

    // 2. Draw world continent landmasses
    final Paint continentFillPaint = Paint()
      ..color = this.continentFillColor
      ..style = PaintingStyle.fill
    ;

    final Paint continentBorderPaint = Paint()
      ..color       = this.continentBorderColor
      ..strokeWidth = AppSizes.mapStrokeRegular
      ..style       = PaintingStyle.stroke
    ;

    final List<List<math.Point<double>>> polygonList = WorldContinentsData.getContinentPolygonList();
    for (final List<math.Point<double>> points in polygonList) {
      if (points.length < 3) {
        continue;
      }
      final Path path = Path();
      final Offset first = geoToScreen(points.first.x, points.first.y);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < points.length; i++) {
        final Offset pt = geoToScreen(points[i].x, points[i].y);
        path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, continentFillPaint);
      canvas.drawPath(path, continentBorderPaint);
    }

    // 3. Visible 0.5° grid lines
    final double halfViewWidthMeters = (size.width / 2.0) / this.zoom;
    final double halfViewHeightMeters = (size.height / 2.0) / this.zoom;

    final double viewMinLon = this.referenceLon + ((this.cameraWorldMeters.dx - halfViewWidthMeters) / metersPerDegreeLon);
    final double viewMaxLon = this.referenceLon + ((this.cameraWorldMeters.dx + halfViewWidthMeters) / metersPerDegreeLon);
    final double viewMinLat = this.referenceLat + ((this.cameraWorldMeters.dy - halfViewHeightMeters) / _metersPerDegreeLat);
    final double viewMaxLat = this.referenceLat + ((this.cameraWorldMeters.dy + halfViewHeightMeters) / _metersPerDegreeLat);

    final int startLonIdx = ((viewMinLon.clamp(-180.0, 180.0) + 180.0) / GeoCellService.cellSizeDegrees).floor() - 1;
    final int endLonIdx = ((viewMaxLon.clamp(-180.0, 180.0) + 180.0) / GeoCellService.cellSizeDegrees).ceil() + 1;
    final int startLatIdx = ((viewMinLat.clamp(-90.0, 90.0) + 90.0) / GeoCellService.cellSizeDegrees).floor() - 1;
    final int endLatIdx = ((viewMaxLat.clamp(-90.0, 90.0) + 90.0) / GeoCellService.cellSizeDegrees).ceil() + 1;

    final Paint gridPaint = Paint()
      ..color       = this.gridLineColor
      ..strokeWidth = AppSizes.mapStrokeRegular
      ..style       = PaintingStyle.stroke
    ;

    // Draw longitude grid lines
    for (int lonIdx = startLonIdx; lonIdx <= endLonIdx; lonIdx++) {
      final double lon = -180.0 + (lonIdx * GeoCellService.cellSizeDegrees);
      final Offset topPt = geoToScreen(lon, viewMaxLat);
      final Offset btmPt = geoToScreen(lon, viewMinLat);
      canvas.drawLine(topPt, btmPt, gridPaint);
    }

    // Draw latitude grid lines
    for (int latIdx = startLatIdx; latIdx <= endLatIdx; latIdx++) {
      final double lat = -90.0 + (latIdx * GeoCellService.cellSizeDegrees);
      final Offset lftPt = geoToScreen(viewMinLon, lat);
      final Offset rgtPt = geoToScreen(viewMaxLon, lat);
      canvas.drawLine(lftPt, rgtPt, gridPaint);
    }

    // 4. Draw already downloaded cells with their respective detail level colors
    for (final MapEntry<String, MapDetailLevel> entry in this.downloadedCellLevelMap.entries) {
      final String cellId = entry.key;
      final MapDetailLevel level = entry.value;

      Color levelColor;
      if (level == MapDetailLevel.base) {
        levelColor = this.detailBaseColor;
      }else if (level == MapDetailLevel.detailed) {
        levelColor = this.detailDetailedColor;
      }else {
        levelColor = this.detailCompleteColor;
      }

      // Try to parse cell bounding box
      final GeoCellModel cell = _parseCellIdToModel(cellId);
      final Offset topLeft = geoToScreen(cell.minLongitude, cell.maxLatitude);
      final Offset btmRight = geoToScreen(cell.maxLongitude, cell.minLatitude);
      final Rect cellRect = Rect.fromPoints(topLeft, btmRight);

      final Paint cellFillPaint = Paint()
        ..color = levelColor.withValues(alpha: 0.38)
        ..style = PaintingStyle.fill
      ;

      final Paint cellBorderPaint = Paint()
        ..color       = levelColor
        ..strokeWidth = AppSizes.mapStrokeThick
        ..style       = PaintingStyle.stroke
      ;

      canvas.drawRect(cellRect, cellFillPaint);
      canvas.drawRect(cellRect, cellBorderPaint);
    }

    // 5. Highlight selected cells (currently circled by lasso)
    final Paint cellSelectedFillPaint = Paint()
      ..color = this.cellSelectedFillColor
      ..style = PaintingStyle.fill
    ;

    final Paint cellSelectedBorderPaint = Paint()
      ..color       = this.cellSelectedBorderColor
      ..strokeWidth = AppSizes.mapStrokeThick
      ..style       = PaintingStyle.stroke
    ;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final GeoCellModel cell in this.selectedCellList) {
      final Offset topLeft = geoToScreen(cell.minLongitude, cell.maxLatitude);
      final Offset btmRight = geoToScreen(cell.maxLongitude, cell.minLatitude);

      final Rect cellRect = Rect.fromPoints(topLeft, btmRight);
      canvas.drawRect(cellRect, cellSelectedFillPaint);
      canvas.drawRect(cellRect, cellSelectedBorderPaint);

      // Draw cell identifier label if cell rect is large enough
      if (cellRect.width > 60.0) {
        textPainter.text = TextSpan(
          text : cell.cellId,
          style: TextStyle(
            fontSize  : AppSizes.font12,
            fontWeight: FontWeight.bold,
            color     : this.textColor,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(cellRect.left + AppSizes.p8, cellRect.top + AppSizes.p8),
        );
      }
    }

    // 6. Draw active finger lasso
    if (this.currentLassoScreenPointList.length >= 2) {
      final Path lassoPath = Path();
      lassoPath.moveTo(
        this.currentLassoScreenPointList.first.dx,
        this.currentLassoScreenPointList.first.dy,
      );

      for (int i = 1; i < this.currentLassoScreenPointList.length; i++) {
        lassoPath.lineTo(
          this.currentLassoScreenPointList[i].dx,
          this.currentLassoScreenPointList[i].dy,
        );
      }

      if (!this.isDrawing) {
        lassoPath.close();
        final Paint fillPaint = Paint()
          ..color = this.lassoFillColor
          ..style = PaintingStyle.fill
        ;
        canvas.drawPath(lassoPath, fillPaint);
      }

      final Paint strokePaint = Paint()
        ..color       = this.lassoStrokeColor
        ..strokeWidth = AppSizes.mapStrokeThick
        ..style       = PaintingStyle.stroke
      ;
      canvas.drawPath(lassoPath, strokePaint);
    }
  }

  /// Helper to convert a cellId string into a [GeoCellModel] with bounds.
  GeoCellModel _parseCellIdToModel(String cellId) {
    try {
      final RegExp regExp = RegExp(r'^([NS])(\d{ 2 })_(\d{ 2 })_([EW])(\d{ 3 })_(\d{ 2 })$');
      final RegExpMatch? match = regExp.firstMatch(cellId);
      if (match != null) {
        final double latDeg = double.parse(match.group(2)!) + (double.parse(match.group(3)!) / 100.0);
        final double lonDeg = double.parse(match.group(5)!) + (double.parse(match.group(6)!) / 100.0);
        final double minLat = (match.group(1) == 'N') ? latDeg : -latDeg;
        final double minLon = (match.group(4) == 'E') ? lonDeg : -lonDeg;
        return GeoCellModel(
          cellId      : cellId,
          minLongitude: minLon,
          minLatitude : minLat,
          maxLongitude: minLon + GeoCellService.cellSizeDegrees,
          maxLatitude : minLat + GeoCellService.cellSizeDegrees,
        );
      }
    }catch (_) {
      // Fallback
    }
    return GeoCellModel(
      cellId      : cellId,
      minLongitude: 0.0,
      minLatitude : 0.0,
      maxLongitude: 0.5,
      maxLatitude : 0.5,
    );
  }

  @override
  bool shouldRepaint(covariant CircleDownloadPainter oldDelegate) {
    return true;
  }
}
