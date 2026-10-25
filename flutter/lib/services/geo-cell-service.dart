import 'dart:math' as math;

/// Represents a single 0.5 x 0.5 degree (~50x50 km) geographical grid cell.
class GeoCellModel {
  static const double defaultCellSizeDegrees = 0.5;

  final String cellId;
  final double minLongitude;
  final double minLatitude;
  final double maxLongitude;
  final double maxLatitude;
  final double estimatedSizeMb;

  const GeoCellModel({
    required this.cellId,
    required this.minLongitude,
    required this.minLatitude,
    required this.maxLongitude,
    required this.maxLatitude,
    this.estimatedSizeMb = 12.0,
  });

  /// Returns whether this cell intersects a given rectangular bounding box [minLon, minLat, maxLon, maxLat].
  bool intersectsBoundingBox(
    double queryMinLon,
    double queryMinLat,
    double queryMaxLon,
    double queryMaxLat,
  ) {
    if ((this.maxLongitude < queryMinLon) || (this.minLongitude > queryMaxLon)) {
      return false;
    }
    if ((this.maxLatitude < queryMinLat) || (this.minLatitude > queryMaxLat)) {
      return false;
    }
    return true;
  }
}

/// Helper service for local 0.5 x 0.5 degree geo-cell calculations.
class GeoCellService {
  static const double cellSizeDegrees = GeoCellModel.defaultCellSizeDegrees;

  /// Creates a cell from grid lat/lon indices matching the server-side formula.
  static GeoCellModel createCellFromIndices(int latIndex, int lonIndex) {
    final double minLat = (-90.0 + (latIndex * cellSizeDegrees));
    final double maxLat = minLat + cellSizeDegrees;
    final double minLon = (-180.0 + (lonIndex * cellSizeDegrees));
    final double maxLon = minLon + cellSizeDegrees;

    final String latPrefix = (minLat >= 0.0) ? 'N' : 'S';
    final String lonPrefix = (minLon >= 0.0) ? 'E' : 'W';

    final double absLat = minLat.abs();
    final double absLon = minLon.abs();

    final int latDegrees   = (absLat + 1e-6).floor();
    final int latHundredths = ((absLat - latDegrees) * 100.0).round();

    final int lonDegrees   = (absLon + 1e-6).floor();
    final int lonHundredths = ((absLon - lonDegrees) * 100.0).round();

    final String latStr = '${latDegrees.toString().padLeft(2, '0')}_${latHundredths.toString().padLeft(2, '0')}';
    final String lonStr = '${lonDegrees.toString().padLeft(3, '0')}_${lonHundredths.toString().padLeft(2, '0')}';
    final String cellId = '$latPrefix${latStr}_$lonPrefix$lonStr';

    return GeoCellModel(
      cellId      : cellId,
      minLongitude: minLon,
      minLatitude : minLat,
      maxLongitude: maxLon,
      maxLatitude : maxLat,
    );
  }

  /// Calculates the cell containing the given coordinate.
  static GeoCellModel getCellForCoordinates(double longitude, double latitude) {
    final double clampedLon = longitude.clamp(-180.0, 179.9999);
    final double clampedLat = latitude.clamp(-90.0, 89.9999);

    final int lonIndex = ((clampedLon + 180.0) / cellSizeDegrees).floor();
    final int latIndex = ((clampedLat + 90.0) / cellSizeDegrees).floor();

    return createCellFromIndices(latIndex, lonIndex);
  }

  /// Calculates all cells intersecting the given bounding box.
  static List<GeoCellModel> getIntersectingCellListForBoundingBox(
    double minLon,
    double minLat,
    double maxLon,
    double maxLat,
  ) {
    final double clampedMinLon = math.min(minLon, maxLon).clamp(-180.0, 179.9999);
    final double clampedMaxLon = math.max(minLon, maxLon).clamp(-180.0, 179.9999);
    final double clampedMinLat = math.min(minLat, maxLat).clamp(-90.0, 89.9999);
    final double clampedMaxLat = math.max(minLat, maxLat).clamp(-90.0, 89.9999);

    final int minLonIndex = ((clampedMinLon + 180.0) / cellSizeDegrees).floor();
    final int maxLonIndex = ((clampedMaxLon + 180.0) / cellSizeDegrees).floor();
    final int minLatIndex = ((clampedMinLat + 90.0) / cellSizeDegrees).floor();
    final int maxLatIndex = ((clampedMaxLat + 90.0) / cellSizeDegrees).floor();

    final List<GeoCellModel> cellList = [];
    for (int latIndex = minLatIndex; latIndex <= maxLatIndex; latIndex++) {
      for (int lonIndex = minLonIndex; lonIndex <= maxLonIndex; lonIndex++) {
        cellList.add(createCellFromIndices(latIndex, lonIndex));
      }
    }

    cellList.sort((GeoCellModel a, GeoCellModel b) => a.cellId.compareTo(b.cellId));
    return cellList;
  }

  /// Calculates all cells intersecting a freehand polygon drawn on the map.
  static List<GeoCellModel> getIntersectingCellListForPolygon(
    List<math.Point<double>> coordinateList,
  ) {
    if (coordinateList.isEmpty) {
      return [];
    }

    if (coordinateList.length == 1) {
      return [getCellForCoordinates(coordinateList[0].x, coordinateList[0].y)];
    }

    double minLon = double.infinity;
    double maxLon = -double.infinity;
    double minLat = double.infinity;
    double maxLat = -double.infinity;

    for (final math.Point<double> point in coordinateList) {
      if (point.x < minLon) {
        minLon = point.x;
      }
      if (point.x > maxLon) {
        maxLon = point.x;
      }
      if (point.y < minLat) {
        minLat = point.y;
      }
      if (point.y > maxLat) {
        maxLat = point.y;
      }
    }

    // Candidate bounding box cells
    final List<GeoCellModel> candidateList = getIntersectingCellListForBoundingBox(
      minLon,
      minLat,
      maxLon,
      maxLat,
    );

    // Filter candidate cells that intersect the polygon
    final List<GeoCellModel> matchedCellList = [];
    for (final GeoCellModel cell in candidateList) {
      if (_cellIntersectsPolygon(cell, coordinateList)) {
        matchedCellList.add(cell);
      }
    }

    if (matchedCellList.isEmpty) {
      return candidateList;
    }

    return matchedCellList;
  }

  /// Determines if a cell intersects the polygon formed by [polygonPoints].
  static bool _cellIntersectsPolygon(
    GeoCellModel cell,
    List<math.Point<double>> polygonPointList,
  ) {
    // 1. Check if any polygon vertex is inside the cell
    for (final math.Point<double> point in polygonPointList) {
      if ((point.x >= cell.minLongitude) &&
          (point.x <= cell.maxLongitude) &&
          (point.y >= cell.minLatitude) &&
          (point.y <= cell.maxLatitude)) {
        return true;
      }
    }

    // 2. Check if cell center is inside polygon (ray casting)
    final double centerLon = (cell.minLongitude + cell.maxLongitude) / 2.0;
    final double centerLat = (cell.minLatitude + cell.maxLatitude) / 2.0;
    if (_isPointInsidePolygon(centerLon, centerLat, polygonPointList)) {
      return true;
    }

    return false;
  }

  /// Ray-casting algorithm to test point in polygon.
  static bool _isPointInsidePolygon(
    double testX,
    double testY,
    List<math.Point<double>> polygonPointList,
  ) {
    bool inside = false;
    final int count = polygonPointList.length;
    for (int i = 0, j = count - 1; i < count; j = i++) {
      final double xi = polygonPointList[i].x;
      final double yi = polygonPointList[i].y;
      final double xj = polygonPointList[j].x;
      final double yj = polygonPointList[j].y;

      final bool intersect = ((yi > testY) != (yj > testY)) &&
          (testX < (((xj - xi) * (testY - yi)) / (yj - yi)) + xi);
      if (intersect) {
        inside = !inside;
      }
    }
    return inside;
  }
}
