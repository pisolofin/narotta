using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Core.Services;
using NaRotta.MapServer.Models;
using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapServer.Services {
    /// <summary>
    /// Service responsible for managing the map catalog manifest, querying 0.5 x 0.5 degree cells, and resolving downloadable assets.
    /// </summary>
    public class MapDistributionService {
        private readonly MapServerSettingsModel _settings;
        private readonly GeoCellGridService _geoCellGridService;
        private readonly ILogger<MapDistributionService> _logger;
        private ManifestRootModel? _cachedManifest;
        private DateTime _lastManifestReadTime = DateTime.MinValue;
        private readonly object _manifestLock = new object();

        public MapDistributionService(
            IOptions<MapServerSettingsModel> options,
            GeoCellGridService geoCellGridService,
            ILogger<MapDistributionService> logger
        ) {
            _settings = options.Value;
            _geoCellGridService = geoCellGridService;
            _logger = logger;
        }

        /// <summary>
        /// Retrieves the current map manifest catalog, reading it from disk or generating a fallback manifest if absent.
        /// </summary>
        public async Task<ManifestRootModel> GetManifestAsync(CancellationToken cancellationToken = default) {
            lock (_manifestLock) {
                if ((_cachedManifest != null) && ((DateTime.UtcNow - _lastManifestReadTime).TotalSeconds < 30.0)) {
                    return _cachedManifest;
                }
            }

            string manifestPath = Path.Combine(_settings.StorageDirectory, "manifest.json");
            if (File.Exists(manifestPath)) {
                try {
                    string jsonContent = await File.ReadAllTextAsync(manifestPath, cancellationToken);
                    ManifestRootModel? parsedManifest = JsonSerializer.Deserialize<ManifestRootModel>(
                        jsonContent,
                        new JsonSerializerOptions {
                            PropertyNameCaseInsensitive = true
                        }
                    );

                    if (parsedManifest != null) {
                        lock (_manifestLock) {
                            _cachedManifest = parsedManifest;
                            _lastManifestReadTime = DateTime.UtcNow;
                        }
                        return parsedManifest;
                    }
                }catch (Exception exception) {
                    _logger.LogWarning(exception, "Failed to read existing manifest from {Path}. Using default manifest.", manifestPath);
                }
            }

            ManifestRootModel fallbackManifest = this.CreateFallbackManifest();
            lock (_manifestLock) {
                _cachedManifest = fallbackManifest;
                _lastManifestReadTime = DateTime.UtcNow;
            }
            return fallbackManifest;
        }

        /// <summary>
        /// Retrieves the list of available regions from the manifest.
        /// </summary>
        public async Task<List<ManifestRegionModel>> GetRegionListAsync(CancellationToken cancellationToken = default) {
            ManifestRootModel manifest = await this.GetManifestAsync(cancellationToken);
            return manifest.RegionList;
        }

        /// <summary>
        /// Retrieves a specific region by its identifier (e.g. "europe/italy").
        /// </summary>
        public async Task<ManifestRegionModel?> GetRegionByIdAsync(string regionId, CancellationToken cancellationToken = default) {
            ManifestRootModel manifest = await this.GetManifestAsync(cancellationToken);
            foreach (ManifestRegionModel region in manifest.RegionList) {
                if (string.Equals(region.Id, regionId, StringComparison.OrdinalIgnoreCase)) {
                    return region;
                }
            }
            return null;
        }

        /// <summary>
        /// Calculates intersecting 0.5 x 0.5 degree cells for a polygon drawn by the user on the map.
        /// </summary>
        public async Task<QueryPolygonResponseModel> QueryCellsForPolygonAsync(
            List<GeoPointModel> pointList,
            List<string>? requestedLayerList,
            CancellationToken cancellationToken = default
        ) {
            var coordinateList = new List<(double Longitude, double Latitude)>();
            foreach (GeoPointModel point in pointList) {
                coordinateList.Add((point.Longitude, point.Latitude));
            }

            List<GeoCellCoordinateModel> matchedCellList = _geoCellGridService.GetIntersectingCellListForPolygon(coordinateList);
            return await this.BuildCellResponseAsync(matchedCellList, requestedLayerList, cancellationToken);
        }

        /// <summary>
        /// Calculates intersecting 0.5 x 0.5 degree cells for a bounding box.
        /// </summary>
        public async Task<QueryPolygonResponseModel> QueryCellsForBoundingBoxAsync(
            double minLongitude,
            double minLatitude,
            double maxLongitude,
            double maxLatitude,
            List<string>? requestedLayerList,
            CancellationToken cancellationToken = default
        ) {
            List<GeoCellCoordinateModel> matchedCellList = _geoCellGridService.GetIntersectingCellListForBoundingBox(
                minLongitude,
                minLatitude,
                maxLongitude,
                maxLatitude
            );
            return await this.BuildCellResponseAsync(matchedCellList, requestedLayerList, cancellationToken);
        }

        /// <summary>
        /// Retrieves details for a specific cell ID.
        /// </summary>
        public async Task<GeoCellDetailModel?> GetCellByIdAsync(string cellId, CancellationToken cancellationToken = default) {
            GeoCellCoordinateModel? cell = _geoCellGridService.TryParseCellId(cellId);
            if (cell == null) {
                return null;
            }

            ManifestRootModel manifest = await this.GetManifestAsync(cancellationToken);
            return this.MapCellToDetailModel(cell, manifest, null);
        }

        /// <summary>
        /// Resolves a requested relative file path securely, preventing directory traversal attacks.
        /// </summary>
        public bool TryResolveFilePath(
            string relativePath,
            out string fullPath,
            out string contentType
        ) {
            fullPath = string.Empty;
            contentType = "application/octet-stream";

            if (string.IsNullOrWhiteSpace(relativePath)) {
                return false;
            }

            string sanitizedRelative = relativePath.Replace('/', Path.DirectorySeparatorChar).Replace('\\', Path.DirectorySeparatorChar);
            string baseDirectory = Path.GetFullPath(_settings.StorageDirectory);
            string candidateFullPath = Path.GetFullPath(Path.Combine(baseDirectory, sanitizedRelative.TrimStart(Path.DirectorySeparatorChar)));

            if (!candidateFullPath.StartsWith(baseDirectory, StringComparison.OrdinalIgnoreCase)) {
                _logger.LogWarning("Forbidden directory traversal attempt: {Path}", relativePath);
                return false;
            }

            if (!File.Exists(candidateFullPath)) {
                return false;
            }

            fullPath = candidateFullPath;
            string extension = Path.GetExtension(candidateFullPath).ToLowerInvariant();
            if ((extension == ".mbtiles") || (extension == ".db")) {
                contentType = "application/vnd.sqlite3";
            }else if (extension == ".tar") {
                contentType = "application/x-tar";
            }else if (extension == ".zip") {
                contentType = "application/zip";
            }else if (extension == ".json") {
                contentType = "application/json";
            }else if (extension == ".pbf") {
                contentType = "application/x-protobuf";
            }

            return true;
        }

        /// <summary>
        /// Builds a <see cref="QueryPolygonResponseModel"/> from a list of intersected cells.
        /// </summary>
        private async Task<QueryPolygonResponseModel> BuildCellResponseAsync(
            List<GeoCellCoordinateModel> cellCoordinateList,
            List<string>? requestedLayerList,
            CancellationToken cancellationToken
        ) {
            ManifestRootModel manifest = await this.GetManifestAsync(cancellationToken);
            var response = new QueryPolygonResponseModel();
            var detailList = new List<GeoCellDetailModel>();
            long totalBytes = 0;

            foreach (GeoCellCoordinateModel coordinate in cellCoordinateList) {
                GeoCellDetailModel detail = this.MapCellToDetailModel(coordinate, manifest, requestedLayerList);
                totalBytes += detail.SizeBytes;
                detailList.Add(detail);
            }

            response.TotalCells = detailList.Count;
            response.TotalSizeBytes = totalBytes;
            response.CellList = detailList;

            return response;
        }

        /// <summary>
        /// Maps a <see cref="GeoCellCoordinateModel"/> to a <see cref="GeoCellDetailModel"/> with calculated sizes and layer URLs.
        /// </summary>
        private GeoCellDetailModel MapCellToDetailModel(
            GeoCellCoordinateModel cell,
            ManifestRootModel manifest,
            List<string>? requestedLayerList
        ) {
            var detail = new GeoCellDetailModel {
                CellId = cell.CellId,
                BoundingBoxList = cell.GetBoundingBoxList()
            };

            ManifestCellModel? manifestCell = null;
            foreach (ManifestCellModel existingCell in manifest.CellList) {
                if (string.Equals(existingCell.CellId, cell.CellId, StringComparison.OrdinalIgnoreCase)) {
                    manifestCell = existingCell;
                    break;
                }
            }

            string baseUrl = _settings.PublicBaseUrl.TrimEnd('/') + "/api/v1/download";
            var availableLayerList = new List<string>();
            var downloadUrlDictionary = new Dictionary<string, string>();
            long totalSizeBytes = 0;

            // Base driving layer (~12 MB average per 50x50 km cell)
            bool wantBase = (requestedLayerList == null) || (requestedLayerList.Count == 0) || requestedLayerList.Contains("transit_and_driving");
            if (wantBase) {
                long baseSize = 12582912L;
                if ((manifestCell != null) && manifestCell.Layers.TryGetValue("transit_and_driving", out ManifestLayerModel? baseLayer)) {
                    baseSize = baseLayer.TilesSizeBytes ?? baseSize;
                }
                totalSizeBytes += baseSize;
                availableLayerList.Add("transit_and_driving");
                downloadUrlDictionary["transit_and_driving"] = baseUrl + "/cells/" + cell.CellId + "/" + cell.CellId + "_tiles_base.mbtiles";
            }

            // 3D buildings layer (~8 MB average)
            bool wantBuildings = (requestedLayerList != null) && requestedLayerList.Contains("buildings_3d");
            if (wantBuildings) {
                long buildingsSize = 8388608L;
                if ((manifestCell != null) && manifestCell.Layers.TryGetValue("buildings_3d", out ManifestLayerModel? bldLayer)) {
                    buildingsSize = bldLayer.TilesSizeBytes ?? buildingsSize;
                }
                totalSizeBytes += buildingsSize;
                availableLayerList.Add("buildings_3d");
                downloadUrlDictionary["buildings_3d"] = baseUrl + "/cells/" + cell.CellId + "/" + cell.CellId + "_tiles_buildings.mbtiles";
            }

            // Pedestrian layer (~4 MB average)
            bool wantPedestrian = (requestedLayerList != null) && requestedLayerList.Contains("pedestrian");
            if (wantPedestrian) {
                long pedestrianSize = 4194304L;
                if ((manifestCell != null) && manifestCell.Layers.TryGetValue("pedestrian", out ManifestLayerModel? pedLayer)) {
                    pedestrianSize = pedLayer.TilesSizeBytes ?? pedestrianSize;
                }
                totalSizeBytes += pedestrianSize;
                availableLayerList.Add("pedestrian");
                downloadUrlDictionary["pedestrian"] = baseUrl + "/cells/" + cell.CellId + "/" + cell.CellId + "_tiles_pedestrian.mbtiles";
            }

            detail.SizeBytes = totalSizeBytes;
            detail.LayerList = availableLayerList;
            detail.DownloadUrlDictionary = downloadUrlDictionary;

            return detail;
        }

        /// <summary>
        /// Creates a default fallback manifest for development and offline testing when no storage manifest exists yet.
        /// </summary>
        private ManifestRootModel CreateFallbackManifest() {
            var manifest = new ManifestRootModel {
                SchemaVersion = "2.2",
                GeneratedAt = DateTime.UtcNow.ToString("o"),
                BaseUrl = _settings.PublicBaseUrl.TrimEnd('/') + "/api/v1/download/",
                CellSizeDegrees = 0.5,
                Overview = new ManifestOverviewModel {
                    Filename = "overview/world_overview.mbtiles",
                    MinZoom = 0,
                    MaxZoom = 7,
                    SizeBytes = 41943040L,
                    Sha256 = "overview-dummy-hash"
                },
                Assets = new ManifestAssetsModel {
                    Filename = "assets/map_assets.zip",
                    Version = "20261020",
                    SizeBytes = 6291456L,
                    Sha256 = "assets-dummy-hash"
                }
            };

            var italyRegion = new ManifestRegionModel {
                Id = "europe/italy",
                ParentId = "europe",
                CountryCode = "IT",
                Name = "Italia",
                Version = "20261020",
                BoundingBoxList = new List<double> { 6.62, 35.49, 18.52, 47.09 },
                CellIdList = new List<string> { "N45_50_E010_50", "N45_50_E011_00", "N45_00_E009_00", "N41_50_E012_50" },
                Search = new ManifestSearchModel {
                    Filename = "regions/europe/italy/italy_search.db",
                    SizeBytes = 262144000L,
                    Sha256 = "search-dummy-hash"
                }
            };

            italyRegion.Layers["transit_and_driving"] = new ManifestLayerModel {
                Description = "Rete stradale completa (Z8-14) e routing auto/moto",
                MinZoom = 8,
                MaxZoom = 14,
                TilesFilename = "regions/europe/italy/italy_tiles_base.mbtiles",
                TilesSizeBytes = 629145600L,
                TilesSha256 = "tiles-dummy-hash",
                RoutingFilename = "regions/europe/italy/italy_routing_auto.tar",
                RoutingSizeBytes = 367001600L,
                RoutingSha256 = "routing-dummy-hash"
            };

            manifest.RegionList.Add(italyRegion);
            return manifest;
        }
    }
}
