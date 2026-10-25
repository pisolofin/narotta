using Microsoft.Data.Sqlite;
using NaRotta.MapBuilder.Core.Models;
using NetTopologySuite.Geometries;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Services {
    /// <summary>
    /// Manages the universal 0.5 x 0.5 degree (~50x50 km) geographical grid for finger-drawn lasso selection, smart route corridor downloads, and regional deduplication.
    /// </summary>
    public class GeoCellGridService {
        public const double CellSizeDegrees = GeoCellCoordinateModel.DefaultCellSizeDegrees;
        private const double KilometersPerDegreeLatitude = 111.32;

        private readonly GeometryFactory _geometryFactory;

        public GeoCellGridService() {
            _geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);
        }

        /// <summary>
        /// Computes the 0.5 x 0.5 degree <see cref="GeoCellCoordinateModel"/> containing the given (longitude, latitude) point.
        /// </summary>
        public GeoCellCoordinateModel GetCellForCoordinates(double longitude, double latitude) {
            double clampedLon = Math.Clamp(longitude, -180.0, 179.9999);
            double clampedLat = Math.Clamp(latitude, -90.0, 89.9999);

            int lonIndex = (int)Math.Floor((clampedLon + 180.0) / CellSizeDegrees);
            int latIndex = (int)Math.Floor((clampedLat + 90.0) / CellSizeDegrees);

            return CreateCellFromIndices(latIndex, lonIndex);
        }

        /// <summary>
        /// Parses a deterministic cell ID (e.g. "N45_50_E010_50") back into a <see cref="GeoCellCoordinateModel"/>.
        /// </summary>
        public GeoCellCoordinateModel? TryParseCellId(string cellId) {
            if (string.IsNullOrWhiteSpace(cellId)) {
                return null;
            }

            string[] partList = cellId.Trim().ToUpperInvariant().Split('_', StringSplitOptions.RemoveEmptyEntries);
            if (partList.Length != 4) {
                return null;
            }

            string latWholePart = partList[0];
            string latFracPart = partList[1];
            string lonWholePart = partList[2];
            string lonFracPart = partList[3];

            if ((latWholePart.Length < 2) || (lonWholePart.Length < 2)) {
                return null;
            }

            char latHemisphere = latWholePart[0];
            char lonHemisphere = lonWholePart[0];

            if ((!int.TryParse(latWholePart.Substring(1), NumberStyles.Integer, CultureInfo.InvariantCulture, out int latDegrees)) ||
                (!int.TryParse(latFracPart, NumberStyles.Integer, CultureInfo.InvariantCulture, out int latHundredths)) ||
                (!int.TryParse(lonWholePart.Substring(1), NumberStyles.Integer, CultureInfo.InvariantCulture, out int lonDegrees)) ||
                (!int.TryParse(lonFracPart, NumberStyles.Integer, CultureInfo.InvariantCulture, out int lonHundredths))) {
                return null;
            }

            double minLat = latDegrees + (latHundredths / 100.0);
            if (latHemisphere == 'S') {
                minLat = -minLat;
            }

            double minLon = lonDegrees + (lonHundredths / 100.0);
            if (lonHemisphere == 'W') {
                minLon = -minLon;
            }

            return this.GetCellForCoordinates(minLon + 0.001, minLat + 0.001);
        }

        /// <summary>
        /// Returns all 0.5 x 0.5 degree cells that intersect the specified geographic bounding box.
        /// </summary>
        public List<GeoCellCoordinateModel> GetIntersectingCellListForBoundingBox(
            double minLongitude,
            double minLatitude,
            double maxLongitude,
            double maxLatitude
        ) {
            var cellList = new List<GeoCellCoordinateModel>();

            double clampedMinLon = Math.Clamp(Math.Min(minLongitude, maxLongitude), -180.0, 179.9999);
            double clampedMaxLon = Math.Clamp(Math.Max(minLongitude, maxLongitude), -180.0, 179.9999);
            double clampedMinLat = Math.Clamp(Math.Min(minLatitude, maxLatitude), -90.0, 89.9999);
            double clampedMaxLat = Math.Clamp(Math.Max(minLatitude, maxLatitude), -90.0, 89.9999);

            int minLonIndex = (int)Math.Floor((clampedMinLon + 180.0) / CellSizeDegrees);
            int maxLonIndex = (int)Math.Floor((clampedMaxLon + 180.0) / CellSizeDegrees);
            int minLatIndex = (int)Math.Floor((clampedMinLat + 90.0) / CellSizeDegrees);
            int maxLatIndex = (int)Math.Floor((clampedMaxLat + 90.0) / CellSizeDegrees);

            for (int latIndex = minLatIndex; latIndex <= maxLatIndex; latIndex++) {
                for (int lonIndex = minLonIndex; lonIndex <= maxLonIndex; lonIndex++) {
                    cellList.Add(CreateCellFromIndices(latIndex, lonIndex));
                }
            }

            cellList.Sort((GeoCellCoordinateModel left, GeoCellCoordinateModel right) =>
                string.Compare(left.CellId, right.CellId, StringComparison.Ordinal)
            );
            return cellList;
        }

        /// <summary>
        /// Computes the exact 0.5 x 0.5 degree cells intersecting a region's polygon or bounding box.
        /// </summary>
        public List<GeoCellCoordinateModel> GetIntersectingCellListForRegion(GeofabrikRegionModel region) {
            if ((region.BoundingBoxList == null) || (region.BoundingBoxList.Count < 4)) {
                return new List<GeoCellCoordinateModel>();
            }

            List<GeoCellCoordinateModel> candidateList = this.GetIntersectingCellListForBoundingBox(
                region.BoundingBoxList[0],
                region.BoundingBoxList[1],
                region.BoundingBoxList[2],
                region.BoundingBoxList[3]
            );

            if (region.BoundaryGeometry == null) {
                return candidateList;
            }

            var filteredList = new List<GeoCellCoordinateModel>();
            foreach (GeoCellCoordinateModel cell in candidateList) {
                Polygon cellPolygon = CreateCellPolygon(cell);
                if (region.BoundaryGeometry.Intersects(cellPolygon)) {
                    filteredList.Add(cell);
                }
            }

            return filteredList;
        }

        /// <summary>
        /// Computes all 0.5 x 0.5 degree cells intersecting a freehand area circled by the user with their finger on the global map.
        /// </summary>
        public List<GeoCellCoordinateModel> GetIntersectingCellListForPolygon(
            List<(double Longitude, double Latitude)> fingerLassoCoordinateList
        ) {
            if ((fingerLassoCoordinateList == null) || (fingerLassoCoordinateList.Count == 0)) {
                return new List<GeoCellCoordinateModel>();
            }

            if (fingerLassoCoordinateList.Count == 1) {
                return new List<GeoCellCoordinateModel> {
                    this.GetCellForCoordinates(fingerLassoCoordinateList[0].Longitude, fingerLassoCoordinateList[0].Latitude)
                };
            }

            var coordinateList = new List<Coordinate>();
            foreach ((double Longitude, double Latitude) point in fingerLassoCoordinateList) {
                coordinateList.Add(new Coordinate(point.Longitude, point.Latitude));
            }

            Geometry selectionGeometry;
            if (coordinateList.Count >= 3) {
                Coordinate firstCoord = coordinateList[0];
                Coordinate lastCoord = coordinateList[coordinateList.Count - 1];
                if (!firstCoord.Equals2D(lastCoord)) {
                    coordinateList.Add(new Coordinate(firstCoord.X, firstCoord.Y));
                }

                if (coordinateList.Count >= 4) {
                    LinearRing ring = _geometryFactory.CreateLinearRing(coordinateList.ToArray());
                    selectionGeometry = _geometryFactory.CreatePolygon(ring);
                }else {
                    selectionGeometry = _geometryFactory.CreateLineString(coordinateList.ToArray());
                }
            }else {
                selectionGeometry = _geometryFactory.CreateLineString(coordinateList.ToArray());
            }

            Envelope envelope = selectionGeometry.EnvelopeInternal;
            List<GeoCellCoordinateModel> candidateList = this.GetIntersectingCellListForBoundingBox(
                envelope.MinX,
                envelope.MinY,
                envelope.MaxX,
                envelope.MaxY
            );

            var intersectingCellList = new List<GeoCellCoordinateModel>();
            foreach (GeoCellCoordinateModel candidateCell in candidateList) {
                Polygon cellPolygon = CreateCellPolygon(candidateCell);
                if (selectionGeometry.Intersects(cellPolygon)) {
                    intersectingCellList.Add(candidateCell);
                }
            }

            return intersectingCellList;
        }

        /// <summary>
        /// Computes the differentiated cell download plan for a navigation route ("Smart Route Corridor"):
        /// - Base driving resolution (Z8-14 + local routing + POIs) within ±corridorRadiusKilometers along the route.
        /// - High-Definition resolution (3D buildings + pedestrian Z13-15) within ±stopHdRadiusKilometers around the destination and intermediate stops.
        /// </summary>
        public RouteCorridorCellPlanModel ComputeRouteCorridorCellPlan(
            List<(double Longitude, double Latitude)> routePolylineCoordinateList,
            List<(double Longitude, double Latitude)>? intermediateAndDestinationStopList = null,
            double corridorRadiusKilometers = 15.0,
            double stopHdRadiusKilometers = 10.0
        ) {
            var plan = new RouteCorridorCellPlanModel {
                CorridorRadiusKilometers = corridorRadiusKilometers,
                StopHdRadiusKilometers = stopHdRadiusKilometers
            };

            if ((routePolylineCoordinateList == null) || (routePolylineCoordinateList.Count == 0)) {
                return plan;
            }

            // 1. Build route geometry and buffer by corridorRadiusKilometers
            var routeCoordList = new List<Coordinate>();
            foreach ((double Longitude, double Latitude) routePoint in routePolylineCoordinateList) {
                routeCoordList.Add(new Coordinate(routePoint.Longitude, routePoint.Latitude));
            }

            Geometry rawRouteGeometry = (routeCoordList.Count == 1)
                ? _geometryFactory.CreatePoint(routeCoordList[0])
                : _geometryFactory.CreateLineString(routeCoordList.ToArray());

            double corridorBufferDegrees = Math.Max(0.01, corridorRadiusKilometers / KilometersPerDegreeLatitude);
            Geometry corridorPolygon = rawRouteGeometry.Buffer(corridorBufferDegrees);
            Envelope corridorEnvelope = corridorPolygon.EnvelopeInternal;

            List<GeoCellCoordinateModel> corridorCandidateList = this.GetIntersectingCellListForBoundingBox(
                corridorEnvelope.MinX,
                corridorEnvelope.MinY,
                corridorEnvelope.MaxX,
                corridorEnvelope.MaxY
            );

            foreach (GeoCellCoordinateModel candidate in corridorCandidateList) {
                Polygon cellPolygon = CreateCellPolygon(candidate);
                if (corridorPolygon.Intersects(cellPolygon)) {
                    plan.CorridorBaseCellList.Add(candidate);
                }
            }

            // 2. Build stop/destination points and buffer by stopHdRadiusKilometers for HD layers (3D Buildings + Pedestrian)
            var effectiveStopList = new List<(double Longitude, double Latitude)>();
            if ((intermediateAndDestinationStopList != null) && (intermediateAndDestinationStopList.Count > 0)) {
                foreach ((double Longitude, double Latitude) stopItem in intermediateAndDestinationStopList) {
                    effectiveStopList.Add(stopItem);
                }
            }else {
                // Default to the final destination point of the route
                effectiveStopList.Add(routePolylineCoordinateList[routePolylineCoordinateList.Count - 1]);
            }

            double stopBufferDegrees = Math.Max(0.01, stopHdRadiusKilometers / KilometersPerDegreeLatitude);
            var hdCellMap = new Dictionary<string, GeoCellCoordinateModel>(StringComparer.Ordinal);

            foreach ((double Longitude, double Latitude) stopPoint in effectiveStopList) {
                Point pointGeometry = _geometryFactory.CreatePoint(new Coordinate(stopPoint.Longitude, stopPoint.Latitude));
                Geometry stopBufferPolygon = pointGeometry.Buffer(stopBufferDegrees);
                Envelope stopEnvelope = stopBufferPolygon.EnvelopeInternal;

                List<GeoCellCoordinateModel> stopCandidateList = this.GetIntersectingCellListForBoundingBox(
                    stopEnvelope.MinX,
                    stopEnvelope.MinY,
                    stopEnvelope.MaxX,
                    stopEnvelope.MaxY
                );

                foreach (GeoCellCoordinateModel candidate in stopCandidateList) {
                    Polygon cellPolygon = CreateCellPolygon(candidate);
                    if (stopBufferPolygon.Intersects(cellPolygon)) {
                        hdCellMap[candidate.CellId] = candidate;
                    }
                }
            }

            plan.DestinationHdCellList = new List<GeoCellCoordinateModel>(hdCellMap.Values);
            plan.DestinationHdCellList.Sort((GeoCellCoordinateModel left, GeoCellCoordinateModel right) =>
                string.Compare(left.CellId, right.CellId, StringComparison.Ordinal)
            );

            return plan;
        }

        /// <summary>
        /// Filters a target list of cell IDs by removing cells that are already installed on the user's device, preventing duplicate downloads.
        /// </summary>
        public List<string> ComputeMissingCellIdList(
            IEnumerable<string> targetCellIdList,
            IEnumerable<string> installedCellIdList
        ) {
            var installedSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (installedCellIdList != null) {
                foreach (string installedId in installedCellIdList) {
                    installedSet.Add(installedId);
                }
            }

            var missingList = new List<string>();
            if (targetCellIdList != null) {
                foreach (string targetId in targetCellIdList) {
                    if (!installedSet.Contains(targetId)) {
                        missingList.Add(targetId);
                        installedSet.Add(targetId);
                    }
                }
            }

            return missingList;
        }

        /// <summary>
        /// Slices a parent .mbtiles SQLite database into modular 0.5 x 0.5 degree cell .mbtiles packages under output/cells/<CELL_ID>/.
        /// </summary>
        public async Task<List<GeoCellCoordinateModel>> SliceMbtilesIntoGeoCellsAsync(
            string sourceMbtilesPath,
            GeofabrikRegionModel region,
            MapResolutionLayer resolutionLayer,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            if (!File.Exists(sourceMbtilesPath)) {
                throw new FileNotFoundException("Source .mbtiles file not found for cell slicing.", sourceMbtilesPath);
            }

            List<GeoCellCoordinateModel> regionCellList = this.GetIntersectingCellListForRegion(region);
            (string schemaFileName, string outputSuffix, int minZoom, int maxZoom) layerSpec =
                PlanetilerTileService.GetLayerSpecification(resolutionLayer);

            Console.WriteLine(
                "[GeoCells] Slicing " + Path.GetFileName(sourceMbtilesPath) + " into " +
                regionCellList.Count.ToString(CultureInfo.InvariantCulture) + " modular 0.5°x0.5° cells (" + layerSpec.outputSuffix + ")..."
            );

            var populatedCellList = new List<GeoCellCoordinateModel>();

            foreach (GeoCellCoordinateModel cell in regionCellList) {
                cancellationToken.ThrowIfCancellationRequested();

                string cellDirectory = Path.Combine(options.OutputDirectory, "cells", cell.CellId);
                Directory.CreateDirectory(cellDirectory);

                string cellMbtilesPath = Path.Combine(cellDirectory, cell.CellId + "_" + layerSpec.outputSuffix + ".mbtiles");
                if (File.Exists(cellMbtilesPath)) {
                    File.Delete(cellMbtilesPath);
                }

                long copiedTileCount = await ExtractCellMbtilesAsync(
                    sourceMbtilesPath,
                    cellMbtilesPath,
                    cell,
                    layerSpec.outputSuffix,
                    layerSpec.minZoom,
                    layerSpec.maxZoom,
                    cancellationToken
                );

                if (copiedTileCount > 0L) {
                    populatedCellList.Add(cell);
                }else {
                    if (File.Exists(cellMbtilesPath)) {
                        File.Delete(cellMbtilesPath);
                    }
                }
            }

            Console.WriteLine(
                "[GeoCells] Created " + populatedCellList.Count.ToString(CultureInfo.InvariantCulture) +
                " populated cell packages for '" + region.Id + "' (" + layerSpec.outputSuffix + ")."
            );

            return populatedCellList;
        }

        private static async Task<long> ExtractCellMbtilesAsync(
            string sourceMbtilesPath,
            string destinationCellMbtilesPath,
            GeoCellCoordinateModel cell,
            string layerSuffix,
            int minZoom,
            int maxZoom,
            CancellationToken cancellationToken
        ) {
            string connectionString = new SqliteConnectionStringBuilder {
                DataSource = destinationCellMbtilesPath,
                Mode = SqliteOpenMode.ReadWriteCreate,
                Pooling = false
            }.ToString();

            long totalInsertedTiles = 0L;

            await using (var connection = new SqliteConnection(connectionString)) {
                await connection.OpenAsync(cancellationToken);

                await ExecuteSqlAsync(
                    connection,
                    "CREATE TABLE metadata (name TEXT, value TEXT); " +
                    "CREATE UNIQUE INDEX name ON metadata (name); " +
                    "CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB); " +
                    "CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row);",
                    cancellationToken
                );

                string escapedSourcePath = sourceMbtilesPath.Replace("'", "''");
                await ExecuteSqlAsync(connection, "ATTACH DATABASE '" + escapedSourcePath + "' AS src_db;", cancellationToken);

                await ExecuteSqlAsync(
                    connection,
                    "INSERT OR REPLACE INTO metadata (name, value) VALUES ('name', '" + cell.CellId + "_" + layerSuffix + "'); " +
                    "INSERT OR REPLACE INTO metadata (name, value) VALUES ('format', 'pbf'); " +
                    "INSERT OR REPLACE INTO metadata (name, value) VALUES ('bounds', '" + cell.GetBoundingBoxString() + "');",
                    cancellationToken
                );

                await using SqliteTransaction transaction = (SqliteTransaction)await connection.BeginTransactionAsync(cancellationToken);

                for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
                    (int minTileX, int maxTileX, int minTmsY, int maxTmsY) tileRange = ComputeTmsTileBounds(
                        cell.MinLongitude,
                        cell.MinLatitude,
                        cell.MaxLongitude,
                        cell.MaxLatitude,
                        zoom
                    );

                    using var copyCmd = connection.CreateCommand();
                    copyCmd.Transaction = transaction;
                    copyCmd.CommandText =
                        "INSERT OR REPLACE INTO tiles (zoom_level, tile_column, tile_row, tile_data) " +
                        "SELECT zoom_level, tile_column, tile_row, tile_data FROM src_db.tiles " +
                        "WHERE zoom_level = $zoom " +
                        "AND tile_column BETWEEN $minX AND $maxX " +
                        "AND tile_row BETWEEN $minY AND $maxY;";

                    copyCmd.Parameters.AddWithValue("$zoom", zoom);
                    copyCmd.Parameters.AddWithValue("$minX", tileRange.minTileX);
                    copyCmd.Parameters.AddWithValue("$maxX", tileRange.maxTileX);
                    copyCmd.Parameters.AddWithValue("$minY", tileRange.minTmsY);
                    copyCmd.Parameters.AddWithValue("$maxY", tileRange.maxTmsY);

                    int affectedRows = await copyCmd.ExecuteNonQueryAsync(cancellationToken);
                    totalInsertedTiles += affectedRows;
                }

                await transaction.CommitAsync(cancellationToken);
                await ExecuteSqlAsync(connection, "DETACH DATABASE src_db;", cancellationToken);
                await connection.CloseAsync();
            }

            SqliteConnection.ClearAllPools();
            return totalInsertedTiles;
        }

        private static GeoCellCoordinateModel CreateCellFromIndices(int latIndex, int lonIndex) {
            double minLat = Math.Round(-90.0 + (latIndex * CellSizeDegrees), 4);
            double maxLat = Math.Round(minLat + CellSizeDegrees, 4);
            double minLon = Math.Round(-180.0 + (lonIndex * CellSizeDegrees), 4);
            double maxLon = Math.Round(minLon + CellSizeDegrees, 4);

            string latPrefix = (minLat >= 0.0) ? "N" : "S";
            string lonPrefix = (minLon >= 0.0) ? "E" : "W";

            double absLat = Math.Abs(minLat);
            double absLon = Math.Abs(minLon);

            int latDegrees = (int)Math.Floor(absLat + 1e-6);
            int latHundredths = (int)Math.Round((absLat - latDegrees) * 100.0);

            int lonDegrees = (int)Math.Floor(absLon + 1e-6);
            int lonHundredths = (int)Math.Round((absLon - lonDegrees) * 100.0);

            string cellId = string.Format(
                CultureInfo.InvariantCulture,
                "{0}{1:D2}_{2:D2}_{3}{4:D3}_{5:D2}",
                latPrefix,
                latDegrees,
                latHundredths,
                lonPrefix,
                lonDegrees,
                lonHundredths
            );

            return new GeoCellCoordinateModel {
                CellId = cellId,
                LatGridIndex = latIndex,
                LonGridIndex = lonIndex,
                MinLongitude = minLon,
                MinLatitude = minLat,
                MaxLongitude = maxLon,
                MaxLatitude = maxLat
            };
        }

        private Polygon CreateCellPolygon(GeoCellCoordinateModel cell) {
            var ringCoords = new Coordinate[] {
                new Coordinate(cell.MinLongitude, cell.MinLatitude),
                new Coordinate(cell.MaxLongitude, cell.MinLatitude),
                new Coordinate(cell.MaxLongitude, cell.MaxLatitude),
                new Coordinate(cell.MinLongitude, cell.MaxLatitude),
                new Coordinate(cell.MinLongitude, cell.MinLatitude)
            };
            return _geometryFactory.CreatePolygon(ringCoords);
        }

        private static (int minTileX, int maxTileX, int minTmsY, int maxTmsY) ComputeTmsTileBounds(
            double minLon,
            double minLat,
            double maxLon,
            double maxLat,
            int zoom
        ) {
            int tileCountPerAxis = 1 << zoom;
            int minTileX = LongitudeToTileX(minLon, tileCountPerAxis);
            int maxTileX = LongitudeToTileX(maxLon, tileCountPerAxis);

            int minOsmY = LatitudeToTileY(maxLat, tileCountPerAxis);
            int maxOsmY = LatitudeToTileY(minLat, tileCountPerAxis);

            int minTmsY = (tileCountPerAxis - 1) - maxOsmY;
            int maxTmsY = (tileCountPerAxis - 1) - minOsmY;

            return (minTileX, maxTileX, minTmsY, maxTmsY);
        }

        private static int LongitudeToTileX(double longitude, int tileCountPerAxis) {
            double clampedLon = Math.Clamp(longitude, -179.9999, 179.9999);
            int tileX = (int)Math.Floor(((clampedLon + 180.0) / 360.0) * tileCountPerAxis);
            return Math.Clamp(tileX, 0, tileCountPerAxis - 1);
        }

        private static int LatitudeToTileY(double latitude, int tileCountPerAxis) {
            double clampedLat = Math.Clamp(latitude, -85.0511, 85.0511);
            double latRad = (clampedLat * Math.PI) / 180.0;
            double mercatorN = Math.Log(Math.Tan(latRad) + (1.0 / Math.Cos(latRad)));
            int tileY = (int)Math.Floor(((1.0 - (mercatorN / Math.PI)) / 2.0) * tileCountPerAxis);
            return Math.Clamp(tileY, 0, tileCountPerAxis - 1);
        }

        private static async Task ExecuteSqlAsync(SqliteConnection connection, string sqlText, CancellationToken cancellationToken) {
            using var command = connection.CreateCommand();
            command.CommandText = sqlText;
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
    }
}
