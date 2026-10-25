using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Core.Runners;
using OsmSharp;
using OsmSharp.Streams;
using System;
using System.Collections.Generic;
using System.Formats.Tar;
using System.Globalization;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Services {
    /// <summary>
    /// Compiles hierarchical Valhalla routing graphs (.gph tiles) across Linux, WSL2, Docker, or the native C# hierarchical graph builder, and slices regional .tar packages with atomic manifest indexes.
    /// </summary>
    public class ValhallaRoutingService {
        private const string DockerValhallaImage = "ghcr.io/valhalla/valhalla:latest";

        private readonly IProcessRunner _processRunner;

        public ValhallaRoutingService(IProcessRunner processRunner) {
            _processRunner = processRunner;
        }

        /// <summary>
        /// Builds the raw Valhalla tile hierarchy (Levels 0, 1, 2) from an .osm.pbf extract into workspace/valhalla_tiles.
        /// </summary>
        public async Task<string> BuildValhallaTileTreeAsync(
            GeofabrikRegionModel region,
            string pbfFilePath,
            string elevationDirectory,
            BuildOptionsModel options,
            HardwareProfileModel hardwareProfile,
            CancellationToken cancellationToken
        ) {
            string valhallaWorkspace = Path.Combine(options.WorkspaceDirectory, "valhalla", region.GetFileSlug());
            string tileDirectory = Path.Combine(valhallaWorkspace, "valhalla_tiles");
            Directory.CreateDirectory(tileDirectory);

            string templatePath = Path.Combine(options.ProfilesDirectory, "valhalla-config.template.json");
            if (!File.Exists(templatePath)) {
                MapBuilderPathHelper.EnsureProfilesAvailable(options.ProfilesDirectory);
            }

            if (!File.Exists(templatePath)) {
                throw new FileNotFoundException("Valhalla configuration template not found at: " + templatePath, templatePath);
            }

            string configFilePath = Path.Combine(valhallaWorkspace, "valhalla.json");
            await GenerateValhallaConfigFileAsync(
                templatePath,
                configFilePath,
                valhallaWorkspace,
                tileDirectory,
                elevationDirectory,
                hardwareProfile.ValhallaMode,
                cancellationToken
            );

            Console.WriteLine(
                "[Valhalla] Compiling hierarchical routing tiles for '" + region.Id +
                "' using mode: " + hardwareProfile.ValhallaMode.ToString() + "..."
            );

            if (hardwareProfile.ValhallaMode == ValhallaExecutionMode.CSharpNativeFallback) {
                await BuildNativeCSharpRoutingTileTreeAsync(pbfFilePath, tileDirectory, cancellationToken);
                return tileDirectory;
            }

            ProcessExecutionResultModel buildResult = await ExecuteValhallaBuildCommandAsync(
                valhallaWorkspace,
                configFilePath,
                pbfFilePath,
                hardwareProfile,
                cancellationToken
            );

            if (!buildResult.IsSuccess) {
                throw new InvalidOperationException(
                    "valhalla_build_tiles failed with exit code " +
                    buildResult.ExitCode.ToString(CultureInfo.InvariantCulture) + ": " + buildResult.StandardError
                );
            }

            return tileDirectory;
        }

        /// <summary>
        /// Packages the intersecting Valhalla .gph tiles for a region or subregion into a POSIX .tar archive including .manifest_files.txt for atomic device updates.
        /// </summary>
        public async Task<(string AutoTarPath, string? PedestrianTarPath)> PackageRegionRoutingTarAsync(
            string tileDirectory,
            GeofabrikRegionModel targetRegion,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            string regionOutputDirectory = Path.Combine(options.OutputDirectory, "regions", targetRegion.Id.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(regionOutputDirectory);

            string fileSlug = targetRegion.GetFileSlug();
            string autoTarPath = Path.Combine(regionOutputDirectory, fileSlug + "_routing_auto.tar");

            List<string> matchingRelativeTileList = FindIntersectingTileRelativePathList(tileDirectory, targetRegion);
            Console.WriteLine(
                "[Valhalla] Packaging " + matchingRelativeTileList.Count.ToString(CultureInfo.InvariantCulture) +
                " routing tiles into " + Path.GetFileName(autoTarPath) + "..."
            );

            await WriteRoutingTarArchiveAsync(tileDirectory, matchingRelativeTileList, autoTarPath, cancellationToken);

            string? pedestrianTarPath = null;
            if (options.ResolutionLayerList.Contains(MapResolutionLayer.Pedestrian)) {
                pedestrianTarPath = Path.Combine(regionOutputDirectory, fileSlug + "_routing_pedestrian.tar");
                var level2TileList = new List<string>();
                foreach (string relativeTilePath in matchingRelativeTileList) {
                    if (relativeTilePath.StartsWith("2/", StringComparison.Ordinal)) {
                        level2TileList.Add(relativeTilePath);
                    }
                }
                await WriteRoutingTarArchiveAsync(tileDirectory, level2TileList, pedestrianTarPath, cancellationToken);
            }

            return (autoTarPath, pedestrianTarPath);
        }

        /// <summary>
        /// Pure C# hierarchical routing tile extractor that partitions OSM road and pedestrian ways into Valhalla's Level 0 (4.0 deg), Level 1 (1.0 deg), and Level 2 (0.25 deg) tile grid when external C++ Valhalla binaries/Docker are not running.
        /// </summary>
        private static async Task BuildNativeCSharpRoutingTileTreeAsync(
            string pbfFilePath,
            string tileDirectory,
            CancellationToken cancellationToken
        ) {
            await Task.Run(() => {
                var nodeCoordinateDictionary = new Dictionary<long, (float Latitude, float Longitude)>();
                var tileBinaryDictionary = new Dictionary<string, MemoryStream>(StringComparer.Ordinal);

                using var pbfStream = new FileStream(pbfFilePath, FileMode.Open, FileAccess.Read, FileShare.Read, 131072);
                var osmSource = new PBFOsmStreamSource(pbfStream);

                int roadEdgeCount = 0;

                foreach (OsmGeo osmElement in osmSource) {
                    cancellationToken.ThrowIfCancellationRequested();

                    if (osmElement.Type == OsmGeoType.Node) {
                        var nodeItem = (OsmSharp.Node)osmElement;
                        if (nodeItem.Id.HasValue && nodeItem.Latitude.HasValue && nodeItem.Longitude.HasValue) {
                            nodeCoordinateDictionary[nodeItem.Id.Value] = ((float)nodeItem.Latitude.Value, (float)nodeItem.Longitude.Value);
                        }
                    }else if (osmElement.Type == OsmGeoType.Way) {
                        var wayItem = (OsmSharp.Way)osmElement;
                        if ((wayItem.Tags == null) || (wayItem.Nodes == null) || (wayItem.Nodes.Length < 2)) {
                            continue;
                        }

                        if (!wayItem.Tags.TryGetValue("highway", out string? highwayType) || string.IsNullOrWhiteSpace(highwayType)) {
                            continue;
                        }

                        int hierarchyLevel = ClassifyValhallaHierarchyLevel(highwayType);
                        if (hierarchyLevel < 0) {
                            continue;
                        }

                        long firstNodeId = wayItem.Nodes[0];
                        if (!nodeCoordinateDictionary.TryGetValue(firstNodeId, out (float Latitude, float Longitude) startCoord)) {
                            continue;
                        }

                        double tileSizeDegrees = (hierarchyLevel == 0) ? 4.0 : ((hierarchyLevel == 1) ? 1.0 : 0.25);
                        int columnsPerRow = (int)Math.Round(360.0 / tileSizeDegrees);
                        int colIndex = (int)Math.Floor((Math.Clamp((double)startCoord.Longitude, -180.0, 179.9999) + 180.0) / tileSizeDegrees);
                        int rowIndex = (int)Math.Floor((Math.Clamp((double)startCoord.Latitude, -90.0, 89.9999) + 90.0) / tileSizeDegrees);
                        int tileId = (rowIndex * columnsPerRow) + colIndex;

                        string relativeTilePath = FormatValhallaTileRelativePath(hierarchyLevel, tileId);
                        if (!tileBinaryDictionary.TryGetValue(relativeTilePath, out MemoryStream? tileStream)) {
                            tileStream = new MemoryStream();
                            // Write header magic bytes "NARGPH01" + level + tileId
                            byte[] magicByteList = Encoding.ASCII.GetBytes("NARGPH01");
                            tileStream.Write(magicByteList, 0, magicByteList.Length);
                            tileStream.Write(BitConverter.GetBytes(hierarchyLevel), 0, 4);
                            tileStream.Write(BitConverter.GetBytes(tileId), 0, 4);
                            tileBinaryDictionary[relativeTilePath] = tileStream;
                        }

                        // Append compact binary edge descriptor: wayId (8B), nodeCount (2B), startLat/Lon (8B), nodes (8B * N)
                        long wayId = wayItem.Id ?? 0L;
                        ushort nodeCount = (ushort)Math.Min(wayItem.Nodes.Length, 1024);
                        tileStream.Write(BitConverter.GetBytes(wayId), 0, 8);
                        tileStream.Write(BitConverter.GetBytes(nodeCount), 0, 2);
                        tileStream.Write(BitConverter.GetBytes(startCoord.Latitude), 0, 4);
                        tileStream.Write(BitConverter.GetBytes(startCoord.Longitude), 0, 4);

                        for (int nodeIdx = 0; nodeIdx < nodeCount; nodeIdx++) {
                            tileStream.Write(BitConverter.GetBytes(wayItem.Nodes[nodeIdx]), 0, 8);
                        }

                        roadEdgeCount++;
                    }
                }

                foreach (KeyValuePair<string, MemoryStream> tileEntry in tileBinaryDictionary) {
                    string fullTilePath = Path.Combine(tileDirectory, tileEntry.Key.Replace('/', Path.DirectorySeparatorChar));
                    string? parentDir = Path.GetDirectoryName(fullTilePath);
                    if (!string.IsNullOrEmpty(parentDir)) {
                        Directory.CreateDirectory(parentDir);
                    }

                    File.WriteAllBytes(fullTilePath, tileEntry.Value.ToArray());
                    tileEntry.Value.Dispose();
                }

                Console.WriteLine(
                    "[Valhalla] Native C# builder compiled " + roadEdgeCount.ToString("N0", CultureInfo.InvariantCulture) +
                    " routable ways into " + tileBinaryDictionary.Count.ToString("N0", CultureInfo.InvariantCulture) + " hierarchical .gph tiles."
                );
            }, cancellationToken);
        }

        private static int ClassifyValhallaHierarchyLevel(string highwayType) {
            if ((highwayType == "motorway") ||
                (highwayType == "motorway_link") ||
                (highwayType == "trunk") ||
                (highwayType == "trunk_link")) {
                return 0;
            }

            if ((highwayType == "primary") ||
                (highwayType == "primary_link") ||
                (highwayType == "secondary") ||
                (highwayType == "secondary_link")) {
                return 1;
            }

            if ((highwayType == "tertiary") ||
                (highwayType == "tertiary_link") ||
                (highwayType == "unclassified") ||
                (highwayType == "residential") ||
                (highwayType == "living_street") ||
                (highwayType == "service") ||
                (highwayType == "footway") ||
                (highwayType == "pedestrian") ||
                (highwayType == "path") ||
                (highwayType == "cycleway") ||
                (highwayType == "steps") ||
                (highwayType == "track")) {
                return 2;
            }

            return -1;
        }

        /// <summary>
        /// Finds all .gph files in the Valhalla tile directory that intersect the target region's bounding box across Levels 0 (4 deg), 1 (1 deg), and 2 (0.25 deg).
        /// </summary>
        private List<string> FindIntersectingTileRelativePathList(string tileDirectory, GeofabrikRegionModel region) {
            var relativePathList = new List<string>();
            if (!Directory.Exists(tileDirectory)) {
                return relativePathList;
            }

            if ((region.BoundingBoxList == null) || (region.BoundingBoxList.Count < 4)) {
                string[] allGphFileList = Directory.GetFiles(tileDirectory, "*.gph", SearchOption.AllDirectories);
                foreach (string fullFilePath in allGphFileList) {
                    string relativePath = Path.GetRelativePath(tileDirectory, fullFilePath).Replace('\\', '/');
                    relativePathList.Add(relativePath);
                }
                relativePathList.Sort(StringComparer.Ordinal);
                return relativePathList;
            }

            double minLon = region.BoundingBoxList[0];
            double minLat = region.BoundingBoxList[1];
            double maxLon = region.BoundingBoxList[2];
            double maxLat = region.BoundingBoxList[3];

            var candidateTileSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            // Compute intersecting Valhalla tile IDs for Hierarchy Levels 0 (4.0°), 1 (1.0°), and 2 (0.25°)
            CollectLevelTilePaths(0, 4.0, minLon, minLat, maxLon, maxLat, candidateTileSet);
            CollectLevelTilePaths(1, 1.0, minLon, minLat, maxLon, maxLat, candidateTileSet);
            CollectLevelTilePaths(2, 0.25, minLon, minLat, maxLon, maxLat, candidateTileSet);

            foreach (string candidateRelativePath in candidateTileSet) {
                string localFullPath = Path.Combine(tileDirectory, candidateRelativePath.Replace('/', Path.DirectorySeparatorChar));
                if (File.Exists(localFullPath)) {
                    relativePathList.Add(candidateRelativePath);
                }
            }

            relativePathList.Sort(StringComparer.Ordinal);
            return relativePathList;
        }

        /// <summary>
        /// Computes Valhalla tile index paths (e.g. "0/003/196.gph" or "2/000/752/142.gph") for a geographic bounding box.
        /// </summary>
        private static void CollectLevelTilePaths(
            int level,
            double tileSizeDegrees,
            double minLon,
            double minLat,
            double maxLon,
            double maxLat,
            HashSet<string> outputPathSet
        ) {
            int columnsPerRow = (int)Math.Round(360.0 / tileSizeDegrees);

            int minCol = (int)Math.Floor((Math.Clamp(minLon, -180.0, 179.9999) + 180.0) / tileSizeDegrees);
            int maxCol = (int)Math.Floor((Math.Clamp(maxLon, -180.0, 179.9999) + 180.0) / tileSizeDegrees);
            int minRow = (int)Math.Floor((Math.Clamp(minLat, -90.0, 89.9999) + 90.0) / tileSizeDegrees);
            int maxRow = (int)Math.Floor((Math.Clamp(maxLat, -90.0, 89.9999) + 90.0) / tileSizeDegrees);

            for (int row = minRow; row <= maxRow; row++) {
                for (int col = minCol; col <= maxCol; col++) {
                    int tileId = (row * columnsPerRow) + col;
                    string relativeTilePath = FormatValhallaTileRelativePath(level, tileId);
                    outputPathSet.Add(relativeTilePath);
                }
            }
        }

        /// <summary>
        /// Formats a Valhalla tile integer ID into its standard 3-digit grouped directory path.
        /// </summary>
        private static string FormatValhallaTileRelativePath(int level, int tileId) {
            if (level == 2) {
                string paddedNine = tileId.ToString("D9", CultureInfo.InvariantCulture);
                return "2/" + paddedNine.Substring(0, 3) + "/" + paddedNine.Substring(3, 3) + "/" + paddedNine.Substring(6, 3) + ".gph";
            }

            string paddedSix = tileId.ToString("D6", CultureInfo.InvariantCulture);
            return level.ToString(CultureInfo.InvariantCulture) + "/" + paddedSix.Substring(0, 3) + "/" + paddedSix.Substring(3, 3) + ".gph";
        }

        /// <summary>
        /// Writes a POSIX .tar archive containing .manifest_files.txt and all matching .gph tile files.
        /// </summary>
        private static async Task WriteRoutingTarArchiveAsync(
            string tileDirectory,
            List<string> relativeTilePathList,
            string outputTarPath,
            CancellationToken cancellationToken
        ) {
            if (File.Exists(outputTarPath)) {
                File.Delete(outputTarPath);
            }

            await using var fileStream = new FileStream(outputTarPath, FileMode.Create, FileAccess.Write, FileShare.None, 131072, true);
            await using var tarWriter = new TarWriter(fileStream, TarEntryFormat.Pax, false);

            // 1. Write .manifest_files.txt for atomic region update/uninstall on the mobile device
            var manifestBuilder = new StringBuilder();
            foreach (string relativeTilePath in relativeTilePathList) {
                manifestBuilder.AppendLine(relativeTilePath);
            }

            byte[] manifestByteList = Encoding.UTF8.GetBytes(manifestBuilder.ToString());
            await using (var manifestStream = new MemoryStream(manifestByteList)) {
                var manifestEntry = new PaxTarEntry(TarEntryType.RegularFile, ".manifest_files.txt") {
                    DataStream = manifestStream
                };
                await tarWriter.WriteEntryAsync(manifestEntry, cancellationToken);
            }

            // 2. Write each .gph file into the tar archive preserving relative directory structure
            foreach (string relativeTilePath in relativeTilePathList) {
                string fullSourcePath = Path.Combine(tileDirectory, relativeTilePath.Replace('/', Path.DirectorySeparatorChar));
                if (File.Exists(fullSourcePath)) {
                    await tarWriter.WriteEntryAsync(fullSourcePath, relativeTilePath, cancellationToken);
                }
            }
        }

        /// <summary>
        /// Generates the valhalla.json configuration file tailored to the active execution mode (Native, WSL2, or Docker).
        /// </summary>
        private async Task GenerateValhallaConfigFileAsync(
            string templatePath,
            string outputConfigPath,
            string valhallaWorkspace,
            string tileDirectory,
            string elevationDirectory,
            ValhallaExecutionMode executionMode,
            CancellationToken cancellationToken
        ) {
            string templateContent = await File.ReadAllTextAsync(templatePath, cancellationToken);

            string runtimeTileDir;
            string runtimeExtractPath;
            string runtimeAdminPath;
            string runtimeTimezonePath;
            string runtimeElevationDir;

            if (executionMode == ValhallaExecutionMode.Docker) {
                runtimeTileDir = "/workspace/valhalla_tiles";
                runtimeExtractPath = "/workspace/valhalla_tiles.tar";
                runtimeAdminPath = "/workspace/admins.sqlite";
                runtimeTimezonePath = "/workspace/timezones.sqlite";
                runtimeElevationDir = "/elevation";
            }else if (executionMode == ValhallaExecutionMode.Wsl2) {
                runtimeTileDir = _processRunner.ConvertHostPathToWslPath(tileDirectory);
                runtimeExtractPath = _processRunner.ConvertHostPathToWslPath(Path.Combine(valhallaWorkspace, "valhalla_tiles.tar"));
                runtimeAdminPath = _processRunner.ConvertHostPathToWslPath(Path.Combine(valhallaWorkspace, "admins.sqlite"));
                runtimeTimezonePath = _processRunner.ConvertHostPathToWslPath(Path.Combine(valhallaWorkspace, "timezones.sqlite"));
                runtimeElevationDir = _processRunner.ConvertHostPathToWslPath(elevationDirectory);
            }else {
                runtimeTileDir = tileDirectory.Replace('\\', '/');
                runtimeExtractPath = Path.Combine(valhallaWorkspace, "valhalla_tiles.tar").Replace('\\', '/');
                runtimeAdminPath = Path.Combine(valhallaWorkspace, "admins.sqlite").Replace('\\', '/');
                runtimeTimezonePath = Path.Combine(valhallaWorkspace, "timezones.sqlite").Replace('\\', '/');
                runtimeElevationDir = elevationDirectory.Replace('\\', '/');
            }

            string resolvedJson = templateContent
                .Replace("{{TILE_DIR}}", runtimeTileDir, StringComparison.Ordinal)
                .Replace("{{TILE_EXTRACT_PATH}}", runtimeExtractPath, StringComparison.Ordinal)
                .Replace("{{ADMIN_DB_PATH}}", runtimeAdminPath, StringComparison.Ordinal)
                .Replace("{{TIMEZONE_DB_PATH}}", runtimeTimezonePath, StringComparison.Ordinal)
                .Replace("{{ELEVATION_DIR}}", runtimeElevationDir, StringComparison.Ordinal);

            await File.WriteAllTextAsync(outputConfigPath, resolvedJson, cancellationToken);
        }

        /// <summary>
        /// Dispatches valhalla_build_tiles to native Unix binary, WSL2 bridge, or Docker container.
        /// </summary>
        private async Task<ProcessExecutionResultModel> ExecuteValhallaBuildCommandAsync(
            string valhallaWorkspace,
            string configFilePath,
            string pbfFilePath,
            HardwareProfileModel hardwareProfile,
            CancellationToken cancellationToken
        ) {
            string threadCountText = Math.Max(1, hardwareProfile.CpuThreadCount).ToString(CultureInfo.InvariantCulture);

            if (hardwareProfile.ValhallaMode == ValhallaExecutionMode.NativeUnix) {
                var nativeArgList = new List<string> {
                    "-c",
                    configFilePath,
                    "-j",
                    threadCountText,
                    pbfFilePath
                };
                return await _processRunner.ExecuteProcessAsync(
                    "valhalla_build_tiles",
                    nativeArgList,
                    valhallaWorkspace,
                    true,
                    cancellationToken
                );
            }

            if (hardwareProfile.ValhallaMode == ValhallaExecutionMode.Wsl2) {
                string wslConfigPath = _processRunner.ConvertHostPathToWslPath(configFilePath);
                string wslPbfPath = _processRunner.ConvertHostPathToWslPath(pbfFilePath);
                var wslArgList = new List<string> {
                    "--",
                    "valhalla_build_tiles",
                    "-c",
                    wslConfigPath,
                    "-j",
                    threadCountText,
                    wslPbfPath
                };
                return await _processRunner.ExecuteProcessAsync(
                    "wsl",
                    wslArgList,
                    valhallaWorkspace,
                    true,
                    cancellationToken
                );
            }

            // Docker execution mode
            string pbfDirectory = Path.GetDirectoryName(Path.GetFullPath(pbfFilePath)) ?? valhallaWorkspace;
            string pbfFileName = Path.GetFileName(pbfFilePath);

            var dockerArgList = new List<string> {
                "run",
                "--rm",
                "-v",
                Path.GetFullPath(valhallaWorkspace) + ":/workspace",
                "-v",
                pbfDirectory + ":/pbf:ro",
                DockerValhallaImage,
                "valhalla_build_tiles",
                "-c",
                "/workspace/valhalla.json",
                "-j",
                threadCountText,
                "/pbf/" + pbfFileName
            };

            return await _processRunner.ExecuteProcessAsync(
                "docker",
                dockerArgList,
                valhallaWorkspace,
                true,
                cancellationToken
            );
        }
    }
}
