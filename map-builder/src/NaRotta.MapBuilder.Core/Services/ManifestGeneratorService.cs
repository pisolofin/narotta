using NaRotta.MapBuilder.Core.Models;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Services {
    /// <summary>
    /// Computes SHA-256 digests and byte sizes of generated map artifacts and updates the root manifest.json catalog (including 0.5x0.5 degree Geo-Cells).
    /// </summary>
    public class ManifestGeneratorService {
        private readonly GeoCellGridService _geoCellGridService;

        public ManifestGeneratorService() {
            _geoCellGridService = new GeoCellGridService();
        }

        /// <summary>
        /// Loads the existing manifest.json if present or creates a new <see cref="ManifestRootModel"/>, updates regions and cells, and writes it atomically to disk.
        /// </summary>
        public async Task<string> UpdateManifestAsync(
            BuildOptionsModel options,
            List<GeofabrikRegionModel> updatedRegionList,
            CancellationToken cancellationToken
        ) {
            Directory.CreateDirectory(options.OutputDirectory);
            string manifestPath = Path.Combine(options.OutputDirectory, "manifest.json");

            ManifestRootModel manifest = await LoadOrCreateManifestAsync(manifestPath, options.BaseUrl, cancellationToken);
            manifest.SchemaVersion = "2.2";
            manifest.GeneratedAt = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ", CultureInfo.InvariantCulture);
            manifest.BaseUrl = options.BaseUrl;
            manifest.CellSizeDegrees = GeoCellCoordinateModel.DefaultCellSizeDegrees;

            string versionTag = DateTime.UtcNow.ToString("yyyyMMdd", CultureInfo.InvariantCulture);

            // 1. Check global overview file if present
            string overviewPath = Path.Combine(options.OutputDirectory, "overview", "world_overview.mbtiles");
            if (File.Exists(overviewPath)) {
                manifest.Overview = new ManifestOverviewModel {
                    Filename = "overview/world_overview.mbtiles",
                    MinZoom = 0,
                    MaxZoom = 7,
                    SizeBytes = new FileInfo(overviewPath).Length,
                    Sha256 = await ComputeSha256Async(overviewPath, cancellationToken)
                };
            }

            // 2. Check offline assets package if present
            string assetsZipPath = Path.Combine(options.OutputDirectory, "assets", "map_assets.zip");
            if (File.Exists(assetsZipPath)) {
                manifest.Assets = new ManifestAssetsModel {
                    Filename = "assets/map_assets.zip",
                    Version = versionTag,
                    SizeBytes = new FileInfo(assetsZipPath).Length,
                    Sha256 = await ComputeSha256Async(assetsZipPath, cancellationToken)
                };
            }

            // 3. Inspect and update each target region
            if (updatedRegionList != null) {
                foreach (GeofabrikRegionModel region in updatedRegionList) {
                    int existingIndex = manifest.RegionList.FindIndex((ManifestRegionModel item) =>
                        string.Equals(item.Id, region.Id, StringComparison.OrdinalIgnoreCase)
                    );
                    ManifestRegionModel? existingRegion = (existingIndex >= 0) ? manifest.RegionList[existingIndex] : null;

                    ManifestRegionModel regionManifest = await BuildRegionManifestEntryAsync(
                        region,
                        versionTag,
                        options.OutputDirectory,
                        existingRegion,
                        cancellationToken
                    );

                    if (existingIndex >= 0) {
                        manifest.RegionList[existingIndex] = regionManifest;
                    }else {
                        manifest.RegionList.Add(regionManifest);
                    }
                }
            }

            manifest.RegionList.Sort((ManifestRegionModel left, ManifestRegionModel right) =>
                string.Compare(left.Id, right.Id, StringComparison.OrdinalIgnoreCase)
            );

            // 4. Inspect and index any 0.5x0.5 degree Geo-Cells in output/cells/
            string cellsRootDirectory = Path.Combine(options.OutputDirectory, "cells");
            if (Directory.Exists(cellsRootDirectory)) {
                manifest.CellList = await UpdateCellManifestListAsync(
                    cellsRootDirectory,
                    manifest.CellList,
                    updatedRegionList,
                    cancellationToken
                );
            }

            var serializerOptions = new JsonSerializerOptions {
                WriteIndented = true,
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
            };

            string jsonText = JsonSerializer.Serialize(manifest, serializerOptions);
            await File.WriteAllTextAsync(manifestPath, jsonText, cancellationToken);

            Console.WriteLine("[Manifest] Updated catalog written to " + manifestPath);
            return manifestPath;
        }

        /// <summary>
        /// Checks whether a region ID is already present and built inside the local manifest.json.
        /// </summary>
        public async Task<bool> IsRegionAlreadyBuiltInManifestAsync(
            string outputDirectory,
            string regionId,
            CancellationToken cancellationToken
        ) {
            string manifestPath = Path.Combine(outputDirectory, "manifest.json");
            if (!File.Exists(manifestPath)) {
                return false;
            }

            ManifestRootModel manifest = await LoadOrCreateManifestAsync(manifestPath, string.Empty, cancellationToken);
            foreach (ManifestRegionModel item in manifest.RegionList) {
                if (string.Equals(item.Id, regionId, StringComparison.OrdinalIgnoreCase)) {
                    bool hasData = (item.Search != null) || (item.Layers.Count > 0);
                    return hasData;
                }
            }

            return false;
        }

        /// <summary>
        /// Inspects generated files on disk for a specific region and builds its <see cref="ManifestRegionModel"/>, reusing SHA-256 digests if file sizes are unchanged.
        /// </summary>
        private async Task<ManifestRegionModel> BuildRegionManifestEntryAsync(
            GeofabrikRegionModel region,
            string versionTag,
            string outputDirectory,
            ManifestRegionModel? existingRegion,
            CancellationToken cancellationToken
        ) {
            string fileSlug = region.GetFileSlug();
            string relativeRegionDir = "regions/" + region.Id.Trim('/');
            string localRegionDir = Path.Combine(outputDirectory, "regions", region.Id.Replace('/', Path.DirectorySeparatorChar));

            List<GeoCellCoordinateModel> intersectingCellList = _geoCellGridService.GetIntersectingCellListForRegion(region);
            var cellIdList = new List<string>();
            foreach (GeoCellCoordinateModel cell in intersectingCellList) {
                cellIdList.Add(cell.CellId);
            }

            var regionManifest = new ManifestRegionModel {
                Id = region.Id,
                ParentId = region.ParentId,
                CountryCode = region.IsoCountryCode,
                Name = region.Name,
                Version = versionTag,
                BoundingBoxList = region.BoundingBoxList,
                CellIdList = cellIdList
            };

            // Search DB
            string searchDbPath = Path.Combine(localRegionDir, fileSlug + "_search.db");
            if (File.Exists(searchDbPath)) {
                long fileSizeBytes = new FileInfo(searchDbPath).Length;
                string? cachedSha = existingRegion?.Search?.Sha256;
                long? cachedSize = existingRegion?.Search?.SizeBytes;
                regionManifest.Search = new ManifestSearchModel {
                    Filename = relativeRegionDir + "/" + fileSlug + "_search.db",
                    SizeBytes = fileSizeBytes,
                    Sha256 = await ComputeOrReuseSha256Async(searchDbPath, fileSizeBytes, cachedSha, cachedSize, cancellationToken)
                };
            }

            // Layer 1: transit_and_driving (Base tiles Z8-14 + Auto routing)
            string baseTilesPath = Path.Combine(localRegionDir, fileSlug + "_tiles_base.mbtiles");
            string autoRoutingPath = Path.Combine(localRegionDir, fileSlug + "_routing_auto.tar");
            if (File.Exists(baseTilesPath) || File.Exists(autoRoutingPath)) {
                var drivingLayer = new ManifestLayerModel {
                    Description = "Complete road network (Z8-14) and car/motorcycle routing",
                    MinZoom = 8,
                    MaxZoom = 14
                };
                if (File.Exists(baseTilesPath)) {
                    long fileSizeBytes = new FileInfo(baseTilesPath).Length;
                    string? cachedSha = null;
                    long? cachedSize = null;
                    if ((existingRegion != null) && existingRegion.Layers.TryGetValue("transit_and_driving", out ManifestLayerModel? cachedLayer)) {
                        cachedSha = cachedLayer.TilesSha256;
                        cachedSize = cachedLayer.TilesSizeBytes;
                    }

                    drivingLayer.TilesFilename = relativeRegionDir + "/" + fileSlug + "_tiles_base.mbtiles";
                    drivingLayer.TilesSizeBytes = fileSizeBytes;
                    drivingLayer.TilesSha256 = await ComputeOrReuseSha256Async(baseTilesPath, fileSizeBytes, cachedSha, cachedSize, cancellationToken);
                }
                if (File.Exists(autoRoutingPath)) {
                    long fileSizeBytes = new FileInfo(autoRoutingPath).Length;
                    string? cachedSha = null;
                    long? cachedSize = null;
                    if ((existingRegion != null) && existingRegion.Layers.TryGetValue("transit_and_driving", out ManifestLayerModel? cachedLayer)) {
                        cachedSha = cachedLayer.RoutingSha256;
                        cachedSize = cachedLayer.RoutingSizeBytes;
                    }

                    drivingLayer.RoutingFilename = relativeRegionDir + "/" + fileSlug + "_routing_auto.tar";
                    drivingLayer.RoutingSizeBytes = fileSizeBytes;
                    drivingLayer.RoutingSha256 = await ComputeOrReuseSha256Async(autoRoutingPath, fileSizeBytes, cachedSha, cachedSize, cancellationToken);
                }
                regionManifest.Layers["transit_and_driving"] = drivingLayer;
            }

            // Layer 2: pedestrian (Pedestrian tiles Z13-15 + Pedestrian routing)
            string pedTilesPath = Path.Combine(localRegionDir, fileSlug + "_tiles_pedestrian.mbtiles");
            string pedRoutingPath = Path.Combine(localRegionDir, fileSlug + "_routing_pedestrian.tar");
            if (File.Exists(pedTilesPath) || File.Exists(pedRoutingPath)) {
                var pedLayer = new ManifestLayerModel {
                    Description = "Pedestrian paths, sidewalks, cycling trails, and walking routing (Z13-15)",
                    MinZoom = 13,
                    MaxZoom = 15
                };
                if (File.Exists(pedTilesPath)) {
                    long fileSizeBytes = new FileInfo(pedTilesPath).Length;
                    string? cachedSha = null;
                    long? cachedSize = null;
                    if ((existingRegion != null) && existingRegion.Layers.TryGetValue("pedestrian", out ManifestLayerModel? cachedLayer)) {
                        cachedSha = cachedLayer.TilesSha256;
                        cachedSize = cachedLayer.TilesSizeBytes;
                    }

                    pedLayer.TilesFilename = relativeRegionDir + "/" + fileSlug + "_tiles_pedestrian.mbtiles";
                    pedLayer.TilesSizeBytes = fileSizeBytes;
                    pedLayer.TilesSha256 = await ComputeOrReuseSha256Async(pedTilesPath, fileSizeBytes, cachedSha, cachedSize, cancellationToken);
                }
                if (File.Exists(pedRoutingPath)) {
                    long fileSizeBytes = new FileInfo(pedRoutingPath).Length;
                    string? cachedSha = null;
                    long? cachedSize = null;
                    if ((existingRegion != null) && existingRegion.Layers.TryGetValue("pedestrian", out ManifestLayerModel? cachedLayer)) {
                        cachedSha = cachedLayer.RoutingSha256;
                        cachedSize = cachedLayer.RoutingSizeBytes;
                    }

                    pedLayer.RoutingFilename = relativeRegionDir + "/" + fileSlug + "_routing_pedestrian.tar";
                    pedLayer.RoutingSizeBytes = fileSizeBytes;
                    pedLayer.RoutingSha256 = await ComputeOrReuseSha256Async(pedRoutingPath, fileSizeBytes, cachedSha, cachedSize, cancellationToken);
                }
                regionManifest.Layers["pedestrian"] = pedLayer;
            }

            // Layer 3: buildings_3d (Z13-15)
            string buildingsTilesPath = Path.Combine(localRegionDir, fileSlug + "_tiles_buildings.mbtiles");
            if (File.Exists(buildingsTilesPath)) {
                long fileSizeBytes = new FileInfo(buildingsTilesPath).Length;
                string? cachedSha = null;
                long? cachedSize = null;
                if ((existingRegion != null) && existingRegion.Layers.TryGetValue("buildings_3d", out ManifestLayerModel? cachedLayer)) {
                    cachedSha = cachedLayer.TilesSha256;
                    cachedSize = cachedLayer.TilesSizeBytes;
                }

                regionManifest.Layers["buildings_3d"] = new ManifestLayerModel {
                    Description = "2D and 3D extruded buildings and landmarks (Z13-15)",
                    MinZoom = 13,
                    MaxZoom = 15,
                    TilesFilename = relativeRegionDir + "/" + fileSlug + "_tiles_buildings.mbtiles",
                    TilesSizeBytes = fileSizeBytes,
                    TilesSha256 = await ComputeOrReuseSha256Async(buildingsTilesPath, fileSizeBytes, cachedSha, cachedSize, cancellationToken)
                };
            }

            // Layer 4: terrain_hd (Z9-14)
            string terrainTilesPath = Path.Combine(localRegionDir, fileSlug + "_tiles_terrain_hd.mbtiles");
            if (File.Exists(terrainTilesPath)) {
                long fileSizeBytes = new FileInfo(terrainTilesPath).Length;
                string? cachedSha = null;
                long? cachedSize = null;
                if ((existingRegion != null) && existingRegion.Layers.TryGetValue("terrain_hd", out ManifestLayerModel? cachedLayer)) {
                    cachedSha = cachedLayer.TilesSha256;
                    cachedSize = cachedLayer.TilesSizeBytes;
                }

                regionManifest.Layers["terrain_hd"] = new ManifestLayerModel {
                    Description = "Topographic peaks, alpine passes, and terrain features (Z9-14)",
                    MinZoom = 9,
                    MaxZoom = 14,
                    TilesFilename = relativeRegionDir + "/" + fileSlug + "_tiles_terrain_hd.mbtiles",
                    TilesSizeBytes = fileSizeBytes,
                    TilesSha256 = await ComputeOrReuseSha256Async(terrainTilesPath, fileSizeBytes, cachedSha, cachedSize, cancellationToken)
                };
            }

            return regionManifest;
        }

        /// <summary>
        /// Updates the modular 0.5x0.5 degree cell catalog incrementally for affected regions, or performs a full scan with SHA-256 cache.
        /// </summary>
        private async Task<List<ManifestCellModel>> UpdateCellManifestListAsync(
            string cellsRootDirectory,
            List<ManifestCellModel>? currentCellList,
            List<GeofabrikRegionModel>? updatedRegionList,
            CancellationToken cancellationToken
        ) {
            var existingCellMap = new Dictionary<string, ManifestCellModel>(StringComparer.OrdinalIgnoreCase);
            if (currentCellList != null) {
                foreach (ManifestCellModel existingCell in currentCellList) {
                    existingCellMap[existingCell.CellId] = existingCell;
                }
            }

            // If we have an existing populated cell manifest and a defined list of updated regions,
            // only inspect the intersecting cells for those regions instead of scanning tens of thousands of directories over network SMB.
            if ((existingCellMap.Count > 0) && (updatedRegionList != null) && (updatedRegionList.Count > 0)) {
                var affectedCellIdSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (GeofabrikRegionModel region in updatedRegionList) {
                    List<GeoCellCoordinateModel> intersectingList = _geoCellGridService.GetIntersectingCellListForRegion(region);
                    foreach (GeoCellCoordinateModel cellCoord in intersectingList) {
                        affectedCellIdSet.Add(cellCoord.CellId);
                    }
                }

                foreach (string cellId in affectedCellIdSet) {
                    string cellDir = Path.Combine(cellsRootDirectory, cellId);
                    if (!Directory.Exists(cellDir)) {
                        continue;
                    }

                    GeoCellCoordinateModel? parsedCell = _geoCellGridService.TryParseCellId(cellId);
                    if (parsedCell == null) {
                        continue;
                    }

                    existingCellMap.TryGetValue(cellId, out ManifestCellModel? existingCell);
                    ManifestCellModel? updatedCell = await BuildSingleCellManifestEntryAsync(
                        cellDir,
                        parsedCell,
                        existingCell,
                        cancellationToken
                    );

                    if (updatedCell != null) {
                        existingCellMap[cellId] = updatedCell;
                    }
                }
            }else {
                // Initial scan or full catalog rebuild: scan all directories in cellsRootDirectory with SHA-256 size caching
                string[] cellDirList = Directory.GetDirectories(cellsRootDirectory);
                foreach (string cellDir in cellDirList) {
                    string cellId = Path.GetFileName(cellDir);
                    GeoCellCoordinateModel? parsedCell = _geoCellGridService.TryParseCellId(cellId);
                    if (parsedCell == null) {
                        continue;
                    }

                    existingCellMap.TryGetValue(cellId, out ManifestCellModel? existingCell);
                    ManifestCellModel? cellManifest = await BuildSingleCellManifestEntryAsync(
                        cellDir,
                        parsedCell,
                        existingCell,
                        cancellationToken
                    );

                    if (cellManifest != null) {
                        existingCellMap[cellId] = cellManifest;
                    }
                }
            }

            var resultList = new List<ManifestCellModel>(existingCellMap.Values);
            resultList.Sort((ManifestCellModel left, ManifestCellModel right) =>
                string.Compare(left.CellId, right.CellId, StringComparison.Ordinal)
            );
            return resultList;
        }

        /// <summary>
        /// Inspects a single cell directory and builds its <see cref="ManifestCellModel"/>, reusing SHA-256 digests if file sizes are unchanged.
        /// </summary>
        private async Task<ManifestCellModel?> BuildSingleCellManifestEntryAsync(
            string cellDir,
            GeoCellCoordinateModel parsedCell,
            ManifestCellModel? existingCell,
            CancellationToken cancellationToken
        ) {
            var cellManifest = new ManifestCellModel {
                CellId = parsedCell.CellId,
                BoundingBoxList = parsedCell.GetBoundingBoxList()
            };

            string relativeCellPrefix = "cells/" + parsedCell.CellId + "/" + parsedCell.CellId;

            // Layer 1: transit_and_driving
            string baseTilesPath = Path.Combine(cellDir, parsedCell.CellId + "_tiles_base.mbtiles");
            if (File.Exists(baseTilesPath)) {
                long fileSizeBytes = new FileInfo(baseTilesPath).Length;
                string? cachedSha = null;
                long? cachedSize = null;
                if ((existingCell != null) && existingCell.Layers.TryGetValue("transit_and_driving", out ManifestLayerModel? cachedLayer)) {
                    cachedSha = cachedLayer.TilesSha256;
                    cachedSize = cachedLayer.TilesSizeBytes;
                }

                cellManifest.Layers["transit_and_driving"] = new ManifestLayerModel {
                    Description = "Cell driving network (Z8-14)",
                    MinZoom = 8,
                    MaxZoom = 14,
                    TilesFilename = relativeCellPrefix + "_tiles_base.mbtiles",
                    TilesSizeBytes = fileSizeBytes,
                    TilesSha256 = await ComputeOrReuseSha256Async(baseTilesPath, fileSizeBytes, cachedSha, cachedSize, cancellationToken)
                };
            }

            // Layer 2: pedestrian
            string pedTilesPath = Path.Combine(cellDir, parsedCell.CellId + "_tiles_pedestrian.mbtiles");
            if (File.Exists(pedTilesPath)) {
                long fileSizeBytes = new FileInfo(pedTilesPath).Length;
                string? cachedSha = null;
                long? cachedSize = null;
                if ((existingCell != null) && existingCell.Layers.TryGetValue("pedestrian", out ManifestLayerModel? cachedLayer)) {
                    cachedSha = cachedLayer.TilesSha256;
                    cachedSize = cachedLayer.TilesSizeBytes;
                }

                cellManifest.Layers["pedestrian"] = new ManifestLayerModel {
                    Description = "Cell pedestrian and cycling network (Z13-15)",
                    MinZoom = 13,
                    MaxZoom = 15,
                    TilesFilename = relativeCellPrefix + "_tiles_pedestrian.mbtiles",
                    TilesSizeBytes = fileSizeBytes,
                    TilesSha256 = await ComputeOrReuseSha256Async(pedTilesPath, fileSizeBytes, cachedSha, cachedSize, cancellationToken)
                };
            }

            // Layer 3: buildings_3d
            string buildingsTilesPath = Path.Combine(cellDir, parsedCell.CellId + "_tiles_buildings.mbtiles");
            if (File.Exists(buildingsTilesPath)) {
                long fileSizeBytes = new FileInfo(buildingsTilesPath).Length;
                string? cachedSha = null;
                long? cachedSize = null;
                if ((existingCell != null) && existingCell.Layers.TryGetValue("buildings_3d", out ManifestLayerModel? cachedLayer)) {
                    cachedSha = cachedLayer.TilesSha256;
                    cachedSize = cachedLayer.TilesSizeBytes;
                }

                cellManifest.Layers["buildings_3d"] = new ManifestLayerModel {
                    Description = "Cell 3D buildings (Z13-15)",
                    MinZoom = 13,
                    MaxZoom = 15,
                    TilesFilename = relativeCellPrefix + "_tiles_buildings.mbtiles",
                    TilesSizeBytes = fileSizeBytes,
                    TilesSha256 = await ComputeOrReuseSha256Async(buildingsTilesPath, fileSizeBytes, cachedSha, cachedSize, cancellationToken)
                };
            }

            // Layer 4: terrain_hd
            string terrainTilesPath = Path.Combine(cellDir, parsedCell.CellId + "_tiles_terrain_hd.mbtiles");
            if (File.Exists(terrainTilesPath)) {
                long fileSizeBytes = new FileInfo(terrainTilesPath).Length;
                string? cachedSha = null;
                long? cachedSize = null;
                if ((existingCell != null) && existingCell.Layers.TryGetValue("terrain_hd", out ManifestLayerModel? cachedLayer)) {
                    cachedSha = cachedLayer.TilesSha256;
                    cachedSize = cachedLayer.TilesSizeBytes;
                }

                cellManifest.Layers["terrain_hd"] = new ManifestLayerModel {
                    Description = "Cell terrain HD (Z9-14)",
                    MinZoom = 9,
                    MaxZoom = 14,
                    TilesFilename = relativeCellPrefix + "_tiles_terrain_hd.mbtiles",
                    TilesSizeBytes = fileSizeBytes,
                    TilesSha256 = await ComputeOrReuseSha256Async(terrainTilesPath, fileSizeBytes, cachedSha, cachedSize, cancellationToken)
                };
            }

            if (cellManifest.Layers.Count > 0) {
                return cellManifest;
            }

            return null;
        }

        private static async Task<string> ComputeOrReuseSha256Async(
            string filePath,
            long fileSizeBytes,
            string? cachedSha256,
            long? cachedSizeBytes,
            CancellationToken cancellationToken
        ) {
            if ((cachedSizeBytes.HasValue) && (cachedSizeBytes.Value == fileSizeBytes) && (!string.IsNullOrEmpty(cachedSha256))) {
                return cachedSha256;
            }

            return await ComputeSha256Async(filePath, cancellationToken);
        }

        private static async Task<ManifestRootModel> LoadOrCreateManifestAsync(
            string manifestPath,
            string baseUrl,
            CancellationToken cancellationToken
        ) {
            if (File.Exists(manifestPath)) {
                try {
                    string existingJson = await File.ReadAllTextAsync(manifestPath, cancellationToken);
                    ManifestRootModel? parsed = JsonSerializer.Deserialize<ManifestRootModel>(existingJson);
                    if (parsed != null) {
                        return parsed;
                    }
                }catch (Exception) {
                    // Recreate manifest if existing file is corrupted
                }
            }

            return new ManifestRootModel {
                BaseUrl = baseUrl
            };
        }

        private static async Task<string> ComputeSha256Async(string filePath, CancellationToken cancellationToken) {
            using var sha256Hasher = SHA256.Create();
            await using var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read, 131072, true);
            byte[] hashByteList = await sha256Hasher.ComputeHashAsync(fileStream, cancellationToken);
            return Convert.ToHexStringLower(hashByteList);
        }
    }
}
