import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../constants/app-sizes.dart';
import '../../../services/geo-cell-service.dart';

/// Painter rendering the map canvas, 0.5° × 0.5° cell grid, user drawn lasso, and selected cell highlights.
class CircleDownloadPainter extends CustomPainter {
  final Offset cameraWorldMeters;
  final double zoom;
  final double referenceLat;
  final double referenceLon;
  final List<Offset> currentLassoScreenPointList;
  final List<GeoCellModel> selectedCellList;
  final bool isDrawing;
  final Color backgroundColor;
  final Color gridLineColor;
  final Color lassoStrokeColor;
  final Color lassoFillColor;
  final Color cellSelectedFillColor;
  final Color cellSelectedBorderColor;
  final Color textColor;

  const CircleDownloadPainter({
    required this.cameraWorldMeters,
    required this.zoom,
    required this.referenceLat,
    required this.referenceLon,
    required this.currentLassoScreenPointList,
    required this.selectedCellList,
    required this.isDrawing,
    required this.backgroundColor,
    required this.gridLineColor,
    required this.lassoStrokeColor,
    required this.lassoFillColor,
    required this.cellSelectedFillColor,
    required this.cellSelectedBorderColor,
    required this.textColor,
  });

  static const double _metersPerDegreeLat = 111320.0;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background
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

    // 2. Visible 0.5° grid lines
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

    // 3. Highlight selected cells
    final Paint cellFillPaint = Paint()
      ..color = this.cellSelectedFillColor
      ..style = PaintingStyle.fill
    ;

    final Paint cellBorderPaint = Paint()
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
      canvas.drawRect(cellRect, cellFillPaint);
      canvas.drawRect(cellRect, cellBorderPaint);

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

    // 4. Draw active finger lasso
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

  @override
  bool shouldRepaint(covariant CircleDownloadPainter oldDelegate) {
    return true;
  }
}
