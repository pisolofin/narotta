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

  /// Returns the center longitude of the cell.
  double get centerLongitude => (this.minLongitude + this.maxLongitude) / 2.0;

  /// Returns the center latitude of the cell.
  double get centerLatitude => (this.minLatitude + this.maxLatitude) / 2.0;

  /// Returns whether this cell intersects a given rectangular bounding box [queryMinLon, queryMinLat, queryMaxLon, queryMaxLat].
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
    final double minLat = -90.0 + (latIndex * cellSizeDegrees);
    final double maxLat = minLat + cellSizeDegrees;
    final double minLon = -180.0 + (lonIndex * cellSizeDegrees);
    final double maxLon = minLon + cellSizeDegrees;

    final String latPrefix = (minLat >= 0.0) ? 'N' : 'S';
    final String lonPrefix = (minLon >= 0.0) ? 'E' : 'W';

    final double absLat = minLat.abs();
    final double absLon = minLon.abs();

    final int latDegrees    = (absLat + 1e-6).floor();
    final int latHundredths = ((absLat - latDegrees) * 100.0).round();

    final int lonDegrees    = (absLon + 1e-6).floor();
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

  /// Parses a cell identifier (e.g. `N45_50_E010_50`) back into a [GeoCellModel], or returns null if invalid.
  static GeoCellModel? tryParseCellId(String cellId) {
    final List<String> partList = cellId.split('_');
    if (partList.length != 4) {
      return null;
    }

    final String latDegPart = partList[0];
    final String latDecPart = partList[1];
    final String lonDegPart = partList[2];
    final String lonDecPart = partList[3];

    if ((latDegPart.length < 2) || (lonDegPart.length < 2)) {
      return null;
    }

    final String latHemisphere = latDegPart.substring(0, 1);
    final String lonHemisphere = lonDegPart.substring(0, 1);
    if (((latHemisphere != 'N') && (latHemisphere != 'S')) ||
        ((lonHemisphere != 'E') && (lonHemisphere != 'W'))) {
      return null;
    }

    final int? latDeg = int.tryParse(latDegPart.substring(1));
    final int? latDec = int.tryParse(latDecPart);
    final int? lonDeg = int.tryParse(lonDegPart.substring(1));
    final int? lonDec = int.tryParse(lonDecPart);

    if ((latDeg == null) || (latDec == null) || (lonDeg == null) || (lonDec == null)) {
      return null;
    }

    final double absLat = latDeg + (latDec / 100.0);
    final double absLon = lonDeg + (lonDec / 100.0);
    final double minLat = (latHemisphere == 'N') ? absLat : -absLat;
    final double minLon = (lonHemisphere == 'E') ? absLon : -absLon;

    return GeoCellModel(
      cellId      : cellId,
      minLongitude: minLon,
      minLatitude : minLat,
      maxLongitude: minLon + cellSizeDegrees,
      maxLatitude : minLat + cellSizeDegrees,
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

    cellList.sort((GeoCellModel firstCell, GeoCellModel secondCell) => firstCell.cellId.compareTo(secondCell.cellId));
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

    final List<GeoCellModel> candidateList = getIntersectingCellListForBoundingBox(
      minLon,
      minLat,
      maxLon,
      maxLat,
    );

    final List<GeoCellModel> matchedCellList = [];
    for (final GeoCellModel cell in candidateList) {
      if (cellIntersectsPolygon(cell, coordinateList)) {
        matchedCellList.add(cell);
      }
    }

    if (matchedCellList.isEmpty) {
      return candidateList;
    }

    return matchedCellList;
  }

  /// Calculates all cells intersecting any polygon in [polygonList].
  static List<GeoCellModel> getIntersectingCellListForMultiPolygon(
    List<List<math.Point<double>>> polygonList,
  ) {
    final Map<String, GeoCellModel> uniqueCellMap = {};
    for (final List<math.Point<double>> polygon in polygonList) {
      final List<GeoCellModel> polygonCellList = getIntersectingCellListForPolygon(polygon);
      for (final GeoCellModel cell in polygonCellList) {
        uniqueCellMap[cell.cellId] = cell;
      }
    }

    final List<GeoCellModel> sortedList = uniqueCellMap.values.toList()
      ..sort((GeoCellModel firstCell, GeoCellModel secondCell) => firstCell.cellId.compareTo(secondCell.cellId))
    ;
    return sortedList;
  }

  /// Determines if a cell intersects the polygon formed by [polygonPointList].
  static bool cellIntersectsPolygon(
    GeoCellModel cell,
    List<math.Point<double>> polygonPointList,
  ) {
    // 1. Check if any polygon vertex lies inside the cell
    for (final math.Point<double> point in polygonPointList) {
      if ((point.x >= cell.minLongitude) &&
          (point.x <= cell.maxLongitude) &&
          (point.y >= cell.minLatitude) &&
          (point.y <= cell.maxLatitude)) {
        return true;
      }
    }

    // 2. Check if cell center or corners lie inside the polygon
    final List<math.Point<double>> samplePointList = [
      math.Point<double>(cell.centerLongitude, cell.centerLatitude),
      math.Point<double>(cell.minLongitude, cell.minLatitude),
      math.Point<double>(cell.maxLongitude, cell.minLatitude),
      math.Point<double>(cell.minLongitude, cell.maxLatitude),
      math.Point<double>(cell.maxLongitude, cell.maxLatitude),
    ];

    for (final math.Point<double> samplePoint in samplePointList) {
      if (_isPointInsidePolygon(samplePoint.x, samplePoint.y, polygonPointList)) {
        return true;
      }
    }

    // 3. Check if any polygon edge crosses any of the 4 cell boundary segments
    final int vertexCount = polygonPointList.length;
    for (int currentIdx = 0; currentIdx < vertexCount; currentIdx++) {
      final int nextIdx                 = (currentIdx + 1) % vertexCount;
      final math.Point<double> segStart = polygonPointList[currentIdx];
      final math.Point<double> segEnd   = polygonPointList[nextIdx];
      if (_segmentIntersectsRect(segStart, segEnd, cell)) {
        return true;
      }
    }

    return false;
  }

  /// Checks whether line segment [segStart]-[segEnd] intersects the rectangle of [cell].
  static bool _segmentIntersectsRect(
    math.Point<double> segStart,
    math.Point<double> segEnd,
    GeoCellModel cell,
  ) {
    final math.Point<double> bottomLeft  = math.Point<double>(cell.minLongitude, cell.minLatitude);
    final math.Point<double> bottomRight = math.Point<double>(cell.maxLongitude, cell.minLatitude);
    final math.Point<double> topRight    = math.Point<double>(cell.maxLongitude, cell.maxLatitude);
    final math.Point<double> topLeft     = math.Point<double>(cell.minLongitude, cell.maxLatitude);

    if (_segmentsIntersect(segStart, segEnd, bottomLeft, bottomRight)) {
      return true;
    }
    if (_segmentsIntersect(segStart, segEnd, bottomRight, topRight)) {
      return true;
    }
    if (_segmentsIntersect(segStart, segEnd, topRight, topLeft)) {
      return true;
    }
    if (_segmentsIntersect(segStart, segEnd, topLeft, bottomLeft)) {
      return true;
    }
    return false;
  }

  /// Returns true if two 2D segments [firstStart]-[firstEnd] and [secondStart]-[secondEnd] intersect.
  static bool _segmentsIntersect(
    math.Point<double> firstStart,
    math.Point<double> firstEnd,
    math.Point<double> secondStart,
    math.Point<double> secondEnd,
  ) {
    final double dir1 = _crossProductDirection(secondStart, secondEnd, firstStart);
    final double dir2 = _crossProductDirection(secondStart, secondEnd, firstEnd);
    final double dir3 = _crossProductDirection(firstStart, firstEnd, secondStart);
    final double dir4 = _crossProductDirection(firstStart, firstEnd, secondEnd);

    if ((((dir1 > 0.0) && (dir2 < 0.0)) || ((dir1 < 0.0) && (dir2 > 0.0))) &&
        (((dir3 > 0.0) && (dir4 < 0.0)) || ((dir3 < 0.0) && (dir4 > 0.0)))) {
      return true;
    }
    return false;
  }

  /// Computes cross-product orientation of three 2D points.
  static double _crossProductDirection(
    math.Point<double> origin,
    math.Point<double> target,
    math.Point<double> testPoint,
  ) {
    return ((testPoint.x - origin.x) * (target.y - origin.y)) -
        ((target.x - origin.x) * (testPoint.y - origin.y));
  }

  /// Ray-casting algorithm to test point in polygon.
  static bool _isPointInsidePolygon(
    double testX,
    double testY,
    List<math.Point<double>> polygonPointList,
  ) {
    bool inside     = false;
    final int count = polygonPointList.length;
    for (int currentIdx = 0, prevIdx = count - 1; currentIdx < count; prevIdx = currentIdx++) {
      final double currentX = polygonPointList[currentIdx].x;
      final double currentY = polygonPointList[currentIdx].y;
      final double prevX    = polygonPointList[prevIdx].x;
      final double prevY    = polygonPointList[prevIdx].y;

      final bool intersect = ((currentY > testY) != (prevY > testY)) &&
          (testX < ((((prevX - currentX) * (testY - currentY)) / (prevY - currentY)) + currentX));
      if (intersect) {
        inside = !inside;
      }
    }
    return inside;
  }
}
