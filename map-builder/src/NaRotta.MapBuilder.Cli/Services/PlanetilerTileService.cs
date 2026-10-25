using Microsoft.Data.Sqlite;
using NaRotta.MapBuilder.Cli.Models;
using NaRotta.MapBuilder.Cli.Runners;
using NetTopologySuite.Geometries;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Cli.Services {
    /// <summary>
    /// Orchestrates Planetiler vector tile generation across multiple resolutions/layers and splits parent .mbtiles into subregions without clipping border tiles.
    /// </summary>
    public class PlanetilerTileService {
        private const string PlanetilerReleaseJarUrl = "https://github.com/onthegomap/planetiler/releases/latest/download/planetiler.jar";
        private const string PlanetilerJarFileName = "planetiler.jar";

        private readonly HttpClient _httpClient;
        private readonly IProcessRunner _processRunner;

        public PlanetilerTileService(HttpClient httpClient, IProcessRunner processRunner) {
            _httpClient = httpClient;
            _processRunner = processRunner;
        }

        /// <summary>
        /// Ensures that planetiler.jar is present in the tools directory, downloading it if missing.
        /// </summary>
        public async Task<string> EnsurePlanetilerJarAsync(string toolsDirectory, CancellationToken cancellationToken) {
            Directory.CreateDirectory(toolsDirectory);
            string jarPath = Path.Combine(toolsDirectory, PlanetilerJarFileName);

            if (File.Exists(jarPath) && (new FileInfo(jarPath).Length > (10L * 1024L * 1024L))) {
                return jarPath;
            }

            Console.WriteLine("[Planetiler] Downloading planetiler.jar from GitHub Releases...");
            string tempJarPath = jarPath + ".part";
            using HttpResponseMessage response = await _httpClient.GetAsync(
                PlanetilerReleaseJarUrl,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken
            );
            response.EnsureSuccessStatusCode();

            await using (var fileStream = new FileStream(tempJarPath, FileMode.Create, FileAccess.Write, FileShare.None, 131072, true)) {
                await using Stream networkStream = await response.Content.ReadAsStreamAsync(cancellationToken);
                await networkStream.CopyToAsync(fileStream, cancellationToken);
            }

            if (File.Exists(jarPath)) {
                File.Delete(jarPath);
            }
            File.Move(tempJarPath, jarPath);
            Console.WriteLine("[Planetiler] Downloaded planetiler.jar to " + jarPath);

            return jarPath;
        }

        /// <summary>
        /// Builds the global or continental low-zoom overview map (Zoom 0 to 7), merging tiles cumulatively into world_overview.mbtiles if it already exists.
        /// </summary>
        public async Task<string> BuildOverviewTilesAsync(
            GeofabrikRegionModel region,
            string pbfFilePath,
            BuildOptionsModel options,
            HardwareProfileModel hardwareProfile,
            CancellationToken cancellationToken
        ) {
            string overviewDirectory = Path.Combine(options.OutputDirectory, "overview");
            Directory.CreateDirectory(overviewDirectory);

            string outputMbtilesPath = Path.Combine(overviewDirectory, "world_overview.mbtiles");
            string schemaPath = Path.Combine(options.ProfilesDirectory, "overview-schema.yml");

            if (!File.Exists(outputMbtilesPath)) {
                await RunPlanetilerSchemaAsync(
                    region,
                    pbfFilePath,
                    schemaPath,
                    outputMbtilesPath,
                    0,
                    7,
                    options,
                    hardwareProfile,
                    cancellationToken
                );
                return outputMbtilesPath;
            }

            string tempOverviewPath = Path.Combine(
                overviewDirectory,
                region.GetFileSlug() + "_overview_part.mbtiles"
            );
            if (File.Exists(tempOverviewPath)) {
                File.Delete(tempOverviewPath);
            }

            await RunPlanetilerSchemaAsync(
                region,
                pbfFilePath,
                schemaPath,
                tempOverviewPath,
                0,
                7,
                options,
                hardwareProfile,
                cancellationToken
            );

            if (File.Exists(tempOverviewPath)) {
                await MergeOverviewMbtilesAsync(outputMbtilesPath, tempOverviewPath, cancellationToken);
                File.Delete(tempOverviewPath);
            }

            return outputMbtilesPath;
        }

        /// <summary>
        /// Merges Z0-Z7 overview tiles from a regional MBTiles file into the global world_overview.mbtiles database.
        /// </summary>
        private static async Task MergeOverviewMbtilesAsync(
            string targetWorldMbtilesPath,
            string sourcePartMbtilesPath,
            CancellationToken cancellationToken
        ) {
            string connectionString = new SqliteConnectionStringBuilder {
                DataSource = targetWorldMbtilesPath,
                Mode = SqliteOpenMode.ReadWriteCreate,
                Pooling = false
            }.ToString();

            await using var connection = new SqliteConnection(connectionString);
            await connection.OpenAsync(cancellationToken);

            string escapedSourcePath = sourcePartMbtilesPath.Replace("'", "''");
            await ExecuteNonQueryAsync(connection, "ATTACH DATABASE '" + escapedSourcePath + "' AS part_db;", cancellationToken);

            bool isView = false;
            using (var checkCommand = connection.CreateCommand()) {
                checkCommand.CommandText = "SELECT type FROM sqlite_master WHERE name = 'tiles';";
                object? result = await checkCommand.ExecuteScalarAsync(cancellationToken);
                isView = string.Equals(result?.ToString(), "view", StringComparison.OrdinalIgnoreCase);
            }

            if (isView) {
                // Planetiler creates a compact deduplicated schema with tiles_shallow + tiles_data and a view called 'tiles'
                await ExecuteNonQueryAsync(
                    connection,
                    "INSERT INTO tiles_data (tile_data) " +
                    "SELECT DISTINCT tile_data FROM part_db.tiles " +
                    "WHERE tile_data NOT IN (SELECT tile_data FROM tiles_data);",
                    cancellationToken
                );
                await ExecuteNonQueryAsync(
                    connection,
                    "INSERT OR REPLACE INTO tiles_shallow (zoom_level, tile_column, tile_row, tile_data_id) " +
                    "SELECT p.zoom_level, p.tile_column, p.tile_row, d.tile_data_id " +
                    "FROM part_db.tiles p " +
                    "JOIN tiles_data d ON d.tile_data = p.tile_data;",
                    cancellationToken
                );
            }else {
                // Standard flat MBTiles table
                await ExecuteNonQueryAsync(
                    connection,
                    "INSERT OR REPLACE INTO tiles (zoom_level, tile_column, tile_row, tile_data) " +
                    "SELECT zoom_level, tile_column, tile_row, tile_data FROM part_db.tiles;",
                    cancellationToken
                );
            }

            await UpsertMetadataValueAsync(connection, "bounds", "-180,-85.0511,180,85.0511", cancellationToken);
            await ExecuteNonQueryAsync(connection, "DETACH DATABASE part_db;", cancellationToken);
            await connection.CloseAsync();
            SqliteConnection.ClearAllPools();
        }

        /// <summary>
        /// Builds a specific resolution/functional layer .mbtiles file for a region.
        /// </summary>
        public async Task<string> BuildResolutionLayerAsync(
            GeofabrikRegionModel region,
            string pbfFilePath,
            MapResolutionLayer resolutionLayer,
            BuildOptionsModel options,
            HardwareProfileModel hardwareProfile,
            CancellationToken cancellationToken
        ) {
            if (resolutionLayer == MapResolutionLayer.Overview) {
                return await this.BuildOverviewTilesAsync(region, pbfFilePath, options, hardwareProfile, cancellationToken);
            }

            string regionOutputDirectory = Path.Combine(options.OutputDirectory, "regions", region.Id.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(regionOutputDirectory);

            string fileSlug = region.GetFileSlug();
            (string schemaFileName, string outputSuffix, int minZoom, int maxZoom) layerSpec = GetLayerSpecification(resolutionLayer);

            string schemaPath = Path.Combine(options.ProfilesDirectory, layerSpec.schemaFileName);
            string outputMbtilesPath = Path.Combine(regionOutputDirectory, fileSlug + "_" + layerSpec.outputSuffix + ".mbtiles");

            await RunPlanetilerSchemaAsync(
                region,
                pbfFilePath,
                schemaPath,
                outputMbtilesPath,
                layerSpec.minZoom,
                layerSpec.maxZoom,
                options,
                hardwareProfile,
                cancellationToken
            );

            return outputMbtilesPath;
        }

        /// <summary>
        /// Splits a parent region's .mbtiles SQLite database into a child subregion's .mbtiles by copying all Web Mercator (z/x/y) tiles that intersect the subregion's boundary, preventing clipped border tiles.
        /// </summary>
        public async Task<string> SplitMbtilesForSubregionAsync(
            string parentMbtilesPath,
            GeofabrikRegionModel subregion,
            MapResolutionLayer resolutionLayer,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            if (!File.Exists(parentMbtilesPath)) {
                throw new FileNotFoundException("Parent .mbtiles file not found for splitting.", parentMbtilesPath);
            }

            string subregionOutputDirectory = Path.Combine(options.OutputDirectory, "regions", subregion.Id.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(subregionOutputDirectory);

            string fileSlug = subregion.GetFileSlug();
            (string schemaFileName, string outputSuffix, int minZoom, int maxZoom) layerSpec = GetLayerSpecification(resolutionLayer);
            string childMbtilesPath = Path.Combine(subregionOutputDirectory, fileSlug + "_" + layerSpec.outputSuffix + ".mbtiles");

            if (File.Exists(childMbtilesPath)) {
                File.Delete(childMbtilesPath);
            }

            Console.WriteLine("[TileSplitter] Extracting unclipped tiles for subregion '" + subregion.Id + "' (" + layerSpec.outputSuffix + ")...");

            string childConnectionString = new SqliteConnectionStringBuilder {
                DataSource = childMbtilesPath,
                Mode = SqliteOpenMode.ReadWriteCreate,
                Pooling = false
            }.ToString();

            await using (var connection = new SqliteConnection(childConnectionString)) {
                await connection.OpenAsync(cancellationToken);

                // Create standard MBTiles schema
                await ExecuteNonQueryAsync(
                    connection,
                    "CREATE TABLE metadata (name TEXT, value TEXT); " +
                    "CREATE UNIQUE INDEX name ON metadata (name); " +
                    "CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB); " +
                    "CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row);",
                    cancellationToken
                );

                // Attach parent MBTiles database
                string escapedParentPath = parentMbtilesPath.Replace("'", "''");
                await ExecuteNonQueryAsync(connection, "ATTACH DATABASE '" + escapedParentPath + "' AS parent_db;", cancellationToken);

                // Copy metadata and override bounds/name for subregion
                await ExecuteNonQueryAsync(connection, "INSERT OR REPLACE INTO metadata SELECT name, value FROM parent_db.metadata;", cancellationToken);
                await UpsertMetadataValueAsync(connection, "name", subregion.Name + " (" + layerSpec.outputSuffix + ")", cancellationToken);
                await UpsertMetadataValueAsync(connection, "bounds", subregion.GetBoundingBoxString(), cancellationToken);

                if ((subregion.BoundingBoxList != null) && (subregion.BoundingBoxList.Count >= 4)) {
                    double minLon = subregion.BoundingBoxList[0];
                    double minLat = subregion.BoundingBoxList[1];
                    double maxLon = subregion.BoundingBoxList[2];
                    double maxLat = subregion.BoundingBoxList[3];

                    await using SqliteTransaction transaction = (SqliteTransaction)await connection.BeginTransactionAsync(cancellationToken);

                    for (int zoom = layerSpec.minZoom; zoom <= layerSpec.maxZoom; zoom++) {
                        (int minTileX, int maxTileX, int minTmsY, int maxTmsY) tileRange = ComputeTmsTileBounds(
                            minLon,
                            minLat,
                            maxLon,
                            maxLat,
                            zoom
                        );

                        using var copyCommand = connection.CreateCommand();
                        copyCommand.Transaction = transaction;
                        copyCommand.CommandText =
                            "INSERT OR REPLACE INTO tiles (zoom_level, tile_column, tile_row, tile_data) " +
                            "SELECT zoom_level, tile_column, tile_row, tile_data FROM parent_db.tiles " +
                            "WHERE zoom_level = $zoom " +
                            "AND tile_column BETWEEN $minX AND $maxX " +
                            "AND tile_row BETWEEN $minY AND $maxY;";

                        copyCommand.Parameters.AddWithValue("$zoom", zoom);
                        copyCommand.Parameters.AddWithValue("$minX", tileRange.minTileX);
                        copyCommand.Parameters.AddWithValue("$maxX", tileRange.maxTileX);
                        copyCommand.Parameters.AddWithValue("$minY", tileRange.minTmsY);
                        copyCommand.Parameters.AddWithValue("$maxY", tileRange.maxTmsY);

                        await copyCommand.ExecuteNonQueryAsync(cancellationToken);
                    }

                    await transaction.CommitAsync(cancellationToken);
                }

                await ExecuteNonQueryAsync(connection, "DETACH DATABASE parent_db;", cancellationToken);
                await ExecuteNonQueryAsync(connection, "VACUUM;", cancellationToken);
                await connection.CloseAsync();
            }

            SqliteConnection.ClearAllPools();
            return childMbtilesPath;
        }

        /// <summary>
        /// Invokes Planetiler JVM with hardware-calibrated memory flags and custom schema YAML.
        /// </summary>
        private async Task RunPlanetilerSchemaAsync(
            GeofabrikRegionModel region,
            string pbfFilePath,
            string schemaYamlPath,
            string outputMbtilesPath,
            int minZoom,
            int maxZoom,
            BuildOptionsModel options,
            HardwareProfileModel hardwareProfile,
            CancellationToken cancellationToken
        ) {
            if (!hardwareProfile.IsJavaAvailable) {
                throw new InvalidOperationException(
                    "Java runtime (Java 21+) is required to execute Planetiler vector tile generation. Run 'narotta-map doctor' for details."
                );
            }

            if (!File.Exists(schemaYamlPath)) {
                throw new FileNotFoundException("Planetiler schema profile not found at: " + schemaYamlPath, schemaYamlPath);
            }

            string jarPath = await this.EnsurePlanetilerJarAsync(options.ToolsDirectory, cancellationToken);
            long pbfSizeBytes = File.Exists(pbfFilePath) ? new FileInfo(pbfFilePath).Length : 0L;

            string nodeMapType = hardwareProfile.GetPlanetilerNodeMapType(pbfSizeBytes);
            string storageMode = hardwareProfile.GetPlanetilerStorageMode(pbfSizeBytes);
            string tempDir = Path.Combine(options.WorkspaceDirectory, "planetiler-tmp");
            Directory.CreateDirectory(tempDir);

            var argumentList = new List<string> {
                "-Xmx" + hardwareProfile.RecommendedJvmHeapGigabytes.ToString(CultureInfo.InvariantCulture) + "g",
                "-jar",
                jarPath,
                "generate-custom",
                "--schema=" + schemaYamlPath,
                "--osm-path=" + pbfFilePath,
                "--output=" + outputMbtilesPath,
                "--tmpdir=" + tempDir,
                "--minzoom=" + minZoom.ToString(CultureInfo.InvariantCulture),
                "--maxzoom=" + maxZoom.ToString(CultureInfo.InvariantCulture),
                "--nodemap-type=" + nodeMapType,
                "--nodemap-storage=" + storageMode,
                "--storage=" + storageMode,
                "--force"
            };

            if ((region.BoundingBoxList != null) && (region.BoundingBoxList.Count >= 4)) {
                argumentList.Add("--bounds=" + region.GetBoundingBoxString());
            }

            Console.WriteLine(
                "[Planetiler] Generating " + Path.GetFileName(outputMbtilesPath) +
                " (Z" + minZoom.ToString(CultureInfo.InvariantCulture) + "-Z" + maxZoom.ToString(CultureInfo.InvariantCulture) +
                ", nodemap=" + nodeMapType + ", storage=" + storageMode + ")..."
            );

            ProcessExecutionResultModel result = await _processRunner.ExecuteProcessAsync(
                "java",
                argumentList,
                options.WorkspaceDirectory,
                true,
                cancellationToken
            );

            if (!result.IsSuccess) {
                throw new InvalidOperationException(
                    "Planetiler execution failed with exit code " + result.ExitCode.ToString(CultureInfo.InvariantCulture) +
                    ": " + result.StandardError
                );
            }
        }

        /// <summary>
        /// Maps a <see cref="MapResolutionLayer"/> to its schema YAML file name, output suffix, and zoom range.
        /// </summary>
        public static (string schemaFileName, string outputSuffix, int minZoom, int maxZoom) GetLayerSpecification(MapResolutionLayer layer) {
            if (layer == MapResolutionLayer.Overview) {
                return ("overview-schema.yml", "tiles_overview", 0, 7);
            }
            if (layer == MapResolutionLayer.Pedestrian) {
                return ("pedestrian-schema.yml", "tiles_pedestrian", 13, 15);
            }
            if (layer == MapResolutionLayer.Buildings) {
                return ("buildings-schema.yml", "tiles_buildings", 13, 15);
            }
            if (layer == MapResolutionLayer.Terrain) {
                return ("terrain-schema.yml", "tiles_terrain_hd", 9, 14);
            }
            return ("driving-base-schema.yml", "tiles_base", 8, 14);
        }

        /// <summary>
        /// Computes Web Mercator X and TMS Y tile index bounds for a geographic bounding box at a given zoom level.
        /// </summary>
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

            // Convert XYZ slippy map Y to TMS Y used by MBTiles: tmsY = (2^zoom - 1) - osmY
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

        private static async Task ExecuteNonQueryAsync(SqliteConnection connection, string sqlText, CancellationToken cancellationToken) {
            using var command = connection.CreateCommand();
            command.CommandText = sqlText;
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        private static async Task UpsertMetadataValueAsync(
            SqliteConnection connection,
            string keyName,
            string keyValue,
            CancellationToken cancellationToken
        ) {
            using var command = connection.CreateCommand();
            command.CommandText = "INSERT OR REPLACE INTO metadata (name, value) VALUES ($name, $value);";
            command.Parameters.AddWithValue("$name", keyName);
            command.Parameters.AddWithValue("$value", keyValue);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
    }
}
