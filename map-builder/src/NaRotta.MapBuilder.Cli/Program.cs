using NaRotta.MapBuilder.Cli.Logging;
using NaRotta.MapBuilder.Cli.Models;
using NaRotta.MapBuilder.Cli.Runners;
using NaRotta.MapBuilder.Cli.Services;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Cli {
    /// <summary>
    /// Entry point and CLI command orchestrator for the NaRotta Cross-Platform Offline Map Builder (.NET 10).
    /// </summary>
    public static class Program {
        public static async Task<int> Main(string[] argumentList) {
            // Enable unified timestamped logging across all CLI commands and child processes
            Console.SetOut(new TimestampedTextWriter(Console.Out));
            Console.SetError(new TimestampedTextWriter(Console.Error));

            string baseDirectory = ResolveMapBuilderRootDirectory();
            BuildOptionsModel options = BuildOptionsModel.ParseArguments(argumentList, baseDirectory);

            // Ensure schema profile files are deployed to the effective profiles directory
            string defaultProfilesDirectory = Path.Combine(baseDirectory, "profiles");
            EnsureProfilesAvailable(defaultProfilesDirectory, options.ProfilesDirectory);

            using var cancellationTokenSource = new CancellationTokenSource();
            Console.CancelKeyPress += (object? sender, ConsoleCancelEventArgs eventArgs) => {
                eventArgs.Cancel = true;
                Console.WriteLine("\n[MapBuilder] Cancellation requested. Stopping current operation...");
                cancellationTokenSource.Cancel();
            };

            using var httpClient = new HttpClient {
                Timeout = TimeSpan.FromHours(6)
            };
            httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("NaRotta-MapBuilder/1.0 (+https://narotta.app)");

            IProcessRunner processRunner = new CrossPlatformProcessRunner();
            var hardwareProfilerService = new HardwareProfilerService(processRunner);
            var catalogService = new GeofabrikCatalogService(httpClient);
            var downloadService = new PbfDownloadService(httpClient);
            var elevationService = new DemElevationService(httpClient);
            var tileService = new PlanetilerTileService(httpClient, processRunner);
            var geoCellGridService = new GeoCellGridService();
            var routingService = new ValhallaRoutingService(processRunner);
            var searchDatabaseService = new SearchDatabaseService();
            var offlineAssetsService = new OfflineAssetsService();
            var manifestService = new ManifestGeneratorService();

            try {
                CancellationToken cancellationToken = cancellationTokenSource.Token;

                if (options.CommandName == "doctor") {
                    await RunDoctorCommandAsync(hardwareProfilerService, options, cancellationToken);
                    return 0;
                }

                if (options.CommandName == "list") {
                    await RunListCommandAsync(catalogService, options, cancellationToken);
                    return 0;
                }

                if (options.CommandName == "download") {
                    await RunDownloadCommandAsync(catalogService, downloadService, elevationService, options, cancellationToken);
                    return 0;
                }

                if (options.CommandName == "build-assets") {
                    await offlineAssetsService.BuildOfflineAssetsPackageAsync(options, cancellationToken);
                    await manifestService.UpdateManifestAsync(options, new List<GeofabrikRegionModel>(), cancellationToken);
                    return 0;
                }

                if (options.CommandName == "build-overview") {
                    await RunBuildOverviewCommandAsync(
                        catalogService,
                        downloadService,
                        tileService,
                        hardwareProfilerService,
                        manifestService,
                        options,
                        cancellationToken
                    );
                    return 0;
                }

                if (options.CommandName == "build-search") {
                    await RunBuildSearchCommandAsync(
                        catalogService,
                        downloadService,
                        searchDatabaseService,
                        manifestService,
                        options,
                        cancellationToken
                    );
                    return 0;
                }

                if (options.CommandName == "build-tiles") {
                    await RunBuildTilesCommandAsync(
                        catalogService,
                        downloadService,
                        tileService,
                        geoCellGridService,
                        hardwareProfilerService,
                        manifestService,
                        options,
                        cancellationToken
                    );
                    return 0;
                }

                if (options.CommandName == "build-routing") {
                    await RunBuildRoutingCommandAsync(
                        catalogService,
                        downloadService,
                        elevationService,
                        routingService,
                        hardwareProfilerService,
                        manifestService,
                        options,
                        cancellationToken
                    );
                    return 0;
                }

                if (options.CommandName == "build") {
                    await RunFullBuildPipelineAsync(
                        catalogService,
                        downloadService,
                        elevationService,
                        tileService,
                        geoCellGridService,
                        routingService,
                        searchDatabaseService,
                        offlineAssetsService,
                        hardwareProfilerService,
                        manifestService,
                        options,
                        cancellationToken
                    );
                    return 0;
                }

                if ((options.CommandName == "batch-build") || (options.CommandName == "build-world")) {
                    await RunBatchOrWorldBuildAsync(
                        catalogService,
                        downloadService,
                        elevationService,
                        tileService,
                        geoCellGridService,
                        routingService,
                        searchDatabaseService,
                        offlineAssetsService,
                        hardwareProfilerService,
                        manifestService,
                        options,
                        cancellationToken
                    );
                    return 0;
                }

                PrintHelpBanner();
                return 0;
            }catch (OperationCanceledException) {
                Console.Error.WriteLine("[MapBuilder] Operation cancelled by user.");
                return 130;
            }catch (Exception exception) {
                Console.Error.WriteLine("[MapBuilder] ERROR: " + exception.Message);
                return 1;
            }
        }

        /// <summary>
        /// Executes the 'doctor' command to display detected hardware, memory configuration, and external tool readiness.
        /// </summary>
        private static async Task RunDoctorCommandAsync(
            HardwareProfilerService profilerService,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            HardwareProfileModel profile = await profilerService.ProfileSystemAsync(options.WorkspaceDirectory, cancellationToken);

            Console.WriteLine("=================================================================");
            Console.WriteLine("  NaRotta MapBuilder (.NET 10) - System & Tooling Diagnostics");
            Console.WriteLine("=================================================================");
            Console.WriteLine("  OS Platform          : " + profile.OperatingSystemName);
            Console.WriteLine("  CPU Logical Threads  : " + profile.CpuThreadCount.ToString(CultureInfo.InvariantCulture));
            Console.WriteLine("  Total Physical RAM   : " + profile.TotalRamMegabytes.ToString("N0", CultureInfo.InvariantCulture) + " MB");
            Console.WriteLine("  Recommended JVM Heap : -Xmx" + profile.RecommendedJvmHeapGigabytes.ToString(CultureInfo.InvariantCulture) + "g");
            Console.WriteLine("  Free Disk Space      : " + profile.AvailableDiskGigabytes.ToString("N0", CultureInfo.InvariantCulture) + " GB");
            Console.WriteLine("-----------------------------------------------------------------");
            Console.WriteLine("  Search DB (C# Native): READY (OsmSharp + NetTopologySuite + SQLite FTS5/R-Tree)");
            Console.WriteLine("  Geo-Cell Grid Slicer : READY (0.5° x 0.5° Lasso & Route Corridor Engine)");
            Console.WriteLine("  Planetiler (Java)    : " + (profile.IsJavaAvailable ? ("READY (" + profile.JavaVersionText + ")") : "MISSING (Install Java 21+)"));
            Console.WriteLine("  Valhalla Routing     : " + profile.ValhallaMode.ToString());
            Console.WriteLine("  Profiles Directory   : " + options.ProfilesDirectory);
            Console.WriteLine("  Workspace Directory  : " + options.WorkspaceDirectory);
            Console.WriteLine("  Output Directory     : " + options.OutputDirectory);
            Console.WriteLine("=================================================================");
        }

        /// <summary>
        /// Lists available regions and subregions from the Geofabrik catalog.
        /// </summary>
        private static async Task RunListCommandAsync(
            GeofabrikCatalogService catalogService,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            List<GeofabrikRegionModel> catalogList = await catalogService.LoadCatalogAsync(
                options.WorkspaceDirectory,
                options.ForceDownload,
                cancellationToken
            );

            List<GeofabrikRegionModel> childList = catalogService.GetSubregionList(catalogList, options.RegionId);
            if (childList.Count == 0) {
                GeofabrikRegionModel? singleRegion = catalogService.FindRegion(catalogList, options.RegionId);
                if (singleRegion != null) {
                    childList.Add(singleRegion);
                }
            }

            Console.WriteLine("==================================================================================");
            Console.WriteLine("  Geofabrik Catalog Regions matching '" + options.RegionId + "' (" + childList.Count.ToString(CultureInfo.InvariantCulture) + " found)");
            Console.WriteLine("==================================================================================");
            foreach (GeofabrikRegionModel region in childList) {
                string parentPrefix = string.IsNullOrEmpty(region.ParentId) ? "" : (region.ParentId + "/");
                Console.WriteLine(string.Format(
                    CultureInfo.InvariantCulture,
                    "  - {0,-38} | {1,-26} | BBox: [{2}]",
                    parentPrefix + region.Id,
                    region.Name,
                    region.GetBoundingBoxString()
                ));
            }
        }

        /// <summary>
        /// Downloads the .osm.pbf extract and optional DEM .hgt elevation tiles for a region.
        /// </summary>
        private static async Task RunDownloadCommandAsync(
            GeofabrikCatalogService catalogService,
            PbfDownloadService downloadService,
            DemElevationService elevationService,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            List<GeofabrikRegionModel> catalogList = await catalogService.LoadCatalogAsync(
                options.WorkspaceDirectory,
                false,
                cancellationToken
            );
            GeofabrikRegionModel targetRegion = RequireRegion(catalogService, catalogList, options.RegionId);

            string pbfPath = await downloadService.EnsurePbfDownloadedAsync(
                targetRegion,
                options.WorkspaceDirectory,
                options.ForceDownload,
                cancellationToken
            );
            Console.WriteLine("[MapBuilder] PBF Ready: " + pbfPath);

            if (options.IncludeElevation) {
                string elevationDir = await elevationService.EnsureElevationTilesAsync(
                    targetRegion,
                    options.WorkspaceDirectory,
                    cancellationToken
                );
                Console.WriteLine("[MapBuilder] DEM Elevation Ready: " + elevationDir);
            }
        }

        /// <summary>
        /// Builds the low-zoom global/continental overview map (Zoom 0 to 7).
        /// </summary>
        private static async Task RunBuildOverviewCommandAsync(
            GeofabrikCatalogService catalogService,
            PbfDownloadService downloadService,
            PlanetilerTileService tileService,
            HardwareProfilerService profilerService,
            ManifestGeneratorService manifestService,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            HardwareProfileModel hardwareProfile = await profilerService.ProfileSystemAsync(options.WorkspaceDirectory, cancellationToken);
            List<GeofabrikRegionModel> catalogList = await catalogService.LoadCatalogAsync(options.WorkspaceDirectory, false, cancellationToken);
            GeofabrikRegionModel targetRegion = RequireRegion(catalogService, catalogList, options.RegionId);

            string pbfPath = await downloadService.EnsurePbfDownloadedAsync(
                targetRegion,
                options.WorkspaceDirectory,
                options.ForceDownload,
                cancellationToken
            );

            await tileService.BuildOverviewTilesAsync(targetRegion, pbfPath, options, hardwareProfile, cancellationToken);
            await manifestService.UpdateManifestAsync(options, new List<GeofabrikRegionModel>(), cancellationToken);
        }

        /// <summary>
        /// Builds only the offline SQLite FTS5 & R-Tree search database for a region.
        /// </summary>
        private static async Task RunBuildSearchCommandAsync(
            GeofabrikCatalogService catalogService,
            PbfDownloadService downloadService,
            SearchDatabaseService searchDatabaseService,
            ManifestGeneratorService manifestService,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            List<GeofabrikRegionModel> catalogList = await catalogService.LoadCatalogAsync(options.WorkspaceDirectory, false, cancellationToken);
            GeofabrikRegionModel targetRegion = RequireRegion(catalogService, catalogList, options.RegionId);

            string pbfPath = await downloadService.EnsurePbfDownloadedAsync(
                targetRegion,
                options.WorkspaceDirectory,
                options.ForceDownload,
                cancellationToken
            );

            await searchDatabaseService.BuildSearchDatabaseAsync(targetRegion, pbfPath, options, cancellationToken);
            await manifestService.UpdateManifestAsync(
                options,
                new List<GeofabrikRegionModel> { targetRegion },
                cancellationToken
            );
        }

        /// <summary>
        /// Builds the multi-resolution .mbtiles vector layers for a region (and splits subregions or 0.5x0.5 degree cells if requested).
        /// </summary>
        private static async Task RunBuildTilesCommandAsync(
            GeofabrikCatalogService catalogService,
            PbfDownloadService downloadService,
            PlanetilerTileService tileService,
            GeoCellGridService geoCellGridService,
            HardwareProfilerService profilerService,
            ManifestGeneratorService manifestService,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            HardwareProfileModel hardwareProfile = await profilerService.ProfileSystemAsync(options.WorkspaceDirectory, cancellationToken);
            List<GeofabrikRegionModel> catalogList = await catalogService.LoadCatalogAsync(options.WorkspaceDirectory, false, cancellationToken);
            GeofabrikRegionModel targetRegion = RequireRegion(catalogService, catalogList, options.RegionId);

            string pbfPath = await downloadService.EnsurePbfDownloadedAsync(
                targetRegion,
                options.WorkspaceDirectory,
                options.ForceDownload,
                cancellationToken
            );

            var updatedRegionList = new List<GeofabrikRegionModel> { targetRegion };
            List<GeofabrikRegionModel> subregionList = options.SplitSubregions
                ? catalogService.GetSubregionList(catalogList, targetRegion.Id)
                : new List<GeofabrikRegionModel>();

            foreach (MapResolutionLayer layer in options.ResolutionLayerList) {
                string parentMbtilesPath = await tileService.BuildResolutionLayerAsync(
                    targetRegion,
                    pbfPath,
                    layer,
                    options,
                    hardwareProfile,
                    cancellationToken
                );

                if (options.SliceGeoCells && (layer != MapResolutionLayer.Overview)) {
                    await geoCellGridService.SliceMbtilesIntoGeoCellsAsync(
                        parentMbtilesPath,
                        targetRegion,
                        layer,
                        options,
                        cancellationToken
                    );
                }

                if ((subregionList.Count > 0) && (layer != MapResolutionLayer.Overview)) {
                    foreach (GeofabrikRegionModel subregion in subregionList) {
                        await tileService.SplitMbtilesForSubregionAsync(
                            parentMbtilesPath,
                            subregion,
                            layer,
                            options,
                            cancellationToken
                        );
                    }
                }
            }

            foreach (GeofabrikRegionModel subregion in subregionList) {
                updatedRegionList.Add(subregion);
            }

            await manifestService.UpdateManifestAsync(options, updatedRegionList, cancellationToken);
        }

        /// <summary>
        /// Builds the Valhalla routing graph (.gph) and packages regional .tar archives.
        /// </summary>
        private static async Task RunBuildRoutingCommandAsync(
            GeofabrikCatalogService catalogService,
            PbfDownloadService downloadService,
            DemElevationService elevationService,
            ValhallaRoutingService routingService,
            HardwareProfilerService profilerService,
            ManifestGeneratorService manifestService,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            HardwareProfileModel hardwareProfile = await profilerService.ProfileSystemAsync(options.WorkspaceDirectory, cancellationToken);
            List<GeofabrikRegionModel> catalogList = await catalogService.LoadCatalogAsync(options.WorkspaceDirectory, false, cancellationToken);
            GeofabrikRegionModel targetRegion = RequireRegion(catalogService, catalogList, options.RegionId);

            string pbfPath = await downloadService.EnsurePbfDownloadedAsync(
                targetRegion,
                options.WorkspaceDirectory,
                options.ForceDownload,
                cancellationToken
            );

            bool needsElevation = options.IncludeElevation && (hardwareProfile.ValhallaMode != ValhallaExecutionMode.CSharpNativeFallback);
            string elevationDirectory = needsElevation
                ? await elevationService.EnsureElevationTilesAsync(targetRegion, options.WorkspaceDirectory, cancellationToken)
                : Path.Combine(options.WorkspaceDirectory, "elevation");

            string tileDirectory = await routingService.BuildValhallaTileTreeAsync(
                targetRegion,
                pbfPath,
                elevationDirectory,
                options,
                hardwareProfile,
                cancellationToken
            );

            var updatedRegionList = new List<GeofabrikRegionModel> { targetRegion };
            await routingService.PackageRegionRoutingTarAsync(tileDirectory, targetRegion, options, cancellationToken);

            if (options.SplitSubregions) {
                List<GeofabrikRegionModel> subregionList = catalogService.GetSubregionList(catalogList, targetRegion.Id);
                foreach (GeofabrikRegionModel subregion in subregionList) {
                    await routingService.PackageRegionRoutingTarAsync(tileDirectory, subregion, options, cancellationToken);
                    updatedRegionList.Add(subregion);
                }
            }

            await manifestService.UpdateManifestAsync(options, updatedRegionList, cancellationToken);
        }

        /// <summary>
        /// Executes the complete end-to-end map pipeline for a single region or country.
        /// </summary>
        private static async Task RunFullBuildPipelineAsync(
            GeofabrikCatalogService catalogService,
            PbfDownloadService downloadService,
            DemElevationService elevationService,
            PlanetilerTileService tileService,
            GeoCellGridService geoCellGridService,
            ValhallaRoutingService routingService,
            SearchDatabaseService searchDatabaseService,
            OfflineAssetsService offlineAssetsService,
            HardwareProfilerService profilerService,
            ManifestGeneratorService manifestService,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            HardwareProfileModel hardwareProfile = await profilerService.ProfileSystemAsync(options.WorkspaceDirectory, cancellationToken);
            List<GeofabrikRegionModel> catalogList = await catalogService.LoadCatalogAsync(options.WorkspaceDirectory, false, cancellationToken);
            GeofabrikRegionModel targetRegion = RequireRegion(catalogService, catalogList, options.RegionId);

            await ExecuteRegionBuildPipelineInternalAsync(
                targetRegion,
                catalogList,
                hardwareProfile,
                catalogService,
                downloadService,
                elevationService,
                tileService,
                geoCellGridService,
                routingService,
                searchDatabaseService,
                offlineAssetsService,
                manifestService,
                options,
                cancellationToken
            );
        }

        /// <summary>
        /// Executes a batch build across all countries of a continent (batch-build) or the entire world (build-world), with optional resume and automatic temporary workspace cleanup.
        /// </summary>
        private static async Task RunBatchOrWorldBuildAsync(
            GeofabrikCatalogService catalogService,
            PbfDownloadService downloadService,
            DemElevationService elevationService,
            PlanetilerTileService tileService,
            GeoCellGridService geoCellGridService,
            ValhallaRoutingService routingService,
            SearchDatabaseService searchDatabaseService,
            OfflineAssetsService offlineAssetsService,
            HardwareProfilerService profilerService,
            ManifestGeneratorService manifestService,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            HardwareProfileModel hardwareProfile = await profilerService.ProfileSystemAsync(options.WorkspaceDirectory, cancellationToken);
            List<GeofabrikRegionModel> catalogList = await catalogService.LoadCatalogAsync(options.WorkspaceDirectory, false, cancellationToken);

            var targetRegionList = new List<GeofabrikRegionModel>();
            if (options.CommandName == "build-world") {
                string[] continentIdList = new string[] {
                    "europe",
                    "north-america",
                    "south-america",
                    "asia",
                    "africa",
                    "australia-oceania",
                    "central-america",
                    "russia"
                };

                foreach (string continentId in continentIdList) {
                    List<GeofabrikRegionModel> continentChildList = catalogService.GetSubregionList(catalogList, continentId);
                    foreach (GeofabrikRegionModel countryRegion in continentChildList) {
                        // Skip redundant monolithic containers in North America
                        // Geofabrik provides the 53 individual US states (us/alabama, us/california, etc.)
                        // directly under north-america, alongside redundant monolithic aggregates 'us' and 'us-*'.
                        if ((countryRegion.Id == "us") || countryRegion.Id.StartsWith("us-", StringComparison.OrdinalIgnoreCase)) {
                            continue;
                        }

                        targetRegionList.Add(countryRegion);
                    }
                }

                // Add Antarctica if available
                GeofabrikRegionModel? antarcticaRegion = catalogService.FindRegion(catalogList, "antarctica");
                if (antarcticaRegion != null) {
                    targetRegionList.Add(antarcticaRegion);
                }
            }else {
                targetRegionList = catalogService.GetSubregionList(catalogList, options.RegionId);
                if (options.RegionId.Equals("north-america", StringComparison.OrdinalIgnoreCase)) {
                    targetRegionList.RemoveAll((GeofabrikRegionModel region) =>
                        (region.Id == "us") || region.Id.StartsWith("us-", StringComparison.OrdinalIgnoreCase)
                    );
                }

                if (targetRegionList.Count == 0) {
                    GeofabrikRegionModel singleRegion = RequireRegion(catalogService, catalogList, options.RegionId);
                    targetRegionList.Add(singleRegion);
                }
            }

            Console.WriteLine("=================================================================");
            Console.WriteLine(
                "  NaRotta World Pipeline: " + targetRegionList.Count.ToString(CultureInfo.InvariantCulture) +
                " regions queued (SliceCells=" + options.SliceGeoCells.ToString() +
                ", SplitSubregions=" + options.SplitSubregions.ToString() +
                ", Resume=" + options.ResumeBatch.ToString() +
                ", CleanWorkspace=" + options.CleanWorkspaceAfterBuild.ToString() + ")"
            );
            Console.WriteLine("=================================================================");

            // Step 0: Build shared offline assets (day/night styles, sprites, glyphs) immediately
            await offlineAssetsService.BuildOfflineAssetsPackageAsync(options, cancellationToken);

            int completedCount = 0;
            foreach (GeofabrikRegionModel region in targetRegionList) {
                cancellationToken.ThrowIfCancellationRequested();
                completedCount++;
                TimestampedTextWriter.CurrentRegionProgress = completedCount.ToString(CultureInfo.InvariantCulture) + "/" + targetRegionList.Count.ToString(CultureInfo.InvariantCulture);

                if (options.ResumeBatch && (!options.ForceDownload)) {
                    bool isAlreadyBuilt = await manifestService.IsRegionAlreadyBuiltInManifestAsync(
                        options.OutputDirectory,
                        region.Id,
                        cancellationToken
                    );
                    if (isAlreadyBuilt) {
                        Console.WriteLine("Skipping '" + region.Id + "' (already present in manifest.json).");
                        continue;
                    }
                }

                Console.WriteLine("Processing '" + region.Name + "' (" + region.Id + ")...");

                try {
                    await ExecuteRegionBuildPipelineInternalAsync(
                        region,
                        catalogList,
                        hardwareProfile,
                        catalogService,
                        downloadService,
                        elevationService,
                        tileService,
                        geoCellGridService,
                        routingService,
                        searchDatabaseService,
                        offlineAssetsService,
                        manifestService,
                        options,
                        cancellationToken
                    );
                }catch (OperationCanceledException) {
                    throw;
                }catch (Exception regionException) {
                    Console.Error.WriteLine(
                        "[MapBuilder] ERROR processing region '" + region.Id + "': " + regionException.Message +
                        ". Continuing with next region in world pipeline."
                    );
                }
            }

            TimestampedTextWriter.CurrentRegionProgress = null;
        }

        private static async Task ExecuteRegionBuildPipelineInternalAsync(
            GeofabrikRegionModel targetRegion,
            List<GeofabrikRegionModel> catalogList,
            HardwareProfileModel hardwareProfile,
            GeofabrikCatalogService catalogService,
            PbfDownloadService downloadService,
            DemElevationService elevationService,
            PlanetilerTileService tileService,
            GeoCellGridService geoCellGridService,
            ValhallaRoutingService routingService,
            SearchDatabaseService searchDatabaseService,
            OfflineAssetsService offlineAssetsService,
            ManifestGeneratorService manifestService,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            Console.WriteLine("=================================================================");
            Console.WriteLine("  NaRotta Full Map Pipeline: " + targetRegion.Name + " (" + targetRegion.Id + ")");
            Console.WriteLine("=================================================================");

            string? pbfPath = null;
            try {
                // Step 1: Download PBF & DEM elevation
                pbfPath = await downloadService.EnsurePbfDownloadedAsync(
                    targetRegion,
                    options.WorkspaceDirectory,
                    options.ForceDownload,
                    cancellationToken
                );

                bool needsElevation = options.IncludeElevation && (hardwareProfile.ValhallaMode != ValhallaExecutionMode.CSharpNativeFallback);
                string elevationDirectory = needsElevation
                    ? await elevationService.EnsureElevationTilesAsync(targetRegion, options.WorkspaceDirectory, cancellationToken)
                    : Path.Combine(options.WorkspaceDirectory, "elevation");

                var updatedRegionList = new List<GeofabrikRegionModel> { targetRegion };
                List<GeofabrikRegionModel> subregionList = options.SplitSubregions
                    ? catalogService.GetSubregionList(catalogList, targetRegion.Id)
                    : new List<GeofabrikRegionModel>();

                // Step 2: Build SQLite FTS5 & R-Tree Search DB
                if (!options.SkipSearch) {
                    await searchDatabaseService.BuildSearchDatabaseAsync(targetRegion, pbfPath, options, cancellationToken);
                }

                // Step 3: Build Multi-Resolution Vector Tiles (.mbtiles) + optional 0.5x0.5 degree Geo-Cells
                if (!options.SkipTiles) {
                    foreach (MapResolutionLayer layer in options.ResolutionLayerList) {
                        string parentMbtilesPath = await tileService.BuildResolutionLayerAsync(
                            targetRegion,
                            pbfPath,
                            layer,
                            options,
                            hardwareProfile,
                            cancellationToken
                        );

                        if (options.SliceGeoCells && (layer != MapResolutionLayer.Overview)) {
                            await geoCellGridService.SliceMbtilesIntoGeoCellsAsync(
                                parentMbtilesPath,
                                targetRegion,
                                layer,
                                options,
                                cancellationToken
                            );
                        }

                        if ((subregionList.Count > 0) && (layer != MapResolutionLayer.Overview)) {
                            foreach (GeofabrikRegionModel subregion in subregionList) {
                                await tileService.SplitMbtilesForSubregionAsync(
                                    parentMbtilesPath,
                                    subregion,
                                    layer,
                                    options,
                                    cancellationToken
                                );
                            }
                        }
                    }
                }

                // Step 4: Build Valhalla Routing Graph & Regional Tar Packages
                if (!options.SkipRouting) {
                    string tileDirectory = await routingService.BuildValhallaTileTreeAsync(
                        targetRegion,
                        pbfPath,
                        elevationDirectory,
                        options,
                        hardwareProfile,
                        cancellationToken
                    );

                    await routingService.PackageRegionRoutingTarAsync(tileDirectory, targetRegion, options, cancellationToken);
                    foreach (GeofabrikRegionModel subregion in subregionList) {
                        await routingService.PackageRegionRoutingTarAsync(tileDirectory, subregion, options, cancellationToken);
                    }
                }

                foreach (GeofabrikRegionModel subregion in subregionList) {
                    updatedRegionList.Add(subregion);
                }

                // Step 5: Ensure Offline Assets Archive & Update Manifest
                await offlineAssetsService.BuildOfflineAssetsPackageAsync(options, cancellationToken);
                await manifestService.UpdateManifestAsync(options, updatedRegionList, cancellationToken);

                Console.WriteLine("=================================================================");
                Console.WriteLine("  Pipeline Completed Successfully for '" + targetRegion.Id + "'!");
                Console.WriteLine("=================================================================");
            }finally {
                // Step 6: Workspace cleanup for batch/world builds (executed reliably even on failure)
                if (options.CleanWorkspaceAfterBuild) {
                    if ((pbfPath != null) && File.Exists(pbfPath)) {
                        try {
                            File.Delete(pbfPath);
                            Console.WriteLine("[Cleanup] Removed temporary PBF file: " + pbfPath);
                        }catch (Exception) {
                            // Non-critical file lock
                        }
                    }

                    string planetilerTmpDir = Path.Combine(options.WorkspaceDirectory, "planetiler-tmp");
                    if (Directory.Exists(planetilerTmpDir)) {
                        try {
                            Directory.Delete(planetilerTmpDir, true);
                        }catch (Exception) {
                            // Non-critical directory lock
                        }
                    }

                    string valhallaRegionDir = Path.Combine(options.WorkspaceDirectory, "valhalla", targetRegion.GetFileSlug());
                    if (Directory.Exists(valhallaRegionDir)) {
                        try {
                            Directory.Delete(valhallaRegionDir, true);
                            Console.WriteLine("[Cleanup] Removed temporary Valhalla directory: " + valhallaRegionDir);
                        }catch (Exception) {
                            // Non-critical directory lock
                        }
                    }

                    string searchTmpDir = Path.Combine(options.WorkspaceDirectory, "search");
                    if (Directory.Exists(searchTmpDir)) {
                        try {
                            Directory.Delete(searchTmpDir, true);
                            Console.WriteLine("[Cleanup] Removed temporary Search directory: " + searchTmpDir);
                        }catch (Exception) {
                            // Non-critical directory lock
                        }
                    }
                }
            }
        }

        private static GeofabrikRegionModel RequireRegion(
            GeofabrikCatalogService catalogService,
            List<GeofabrikRegionModel> catalogList,
            string regionId
        ) {
            GeofabrikRegionModel? foundRegion = catalogService.FindRegion(catalogList, regionId);
            if (foundRegion == null) {
                throw new ArgumentException(
                    "Region '" + regionId + "' was not found in the Geofabrik catalog. Run 'narotta-map list --region europe' to inspect valid IDs."
                );
            }
            return foundRegion;
        }

        /// <summary>
        /// Walks up from the current directory or binary base directory to locate the map-builder root folder containing 'profiles/'.
        /// </summary>
        private static string ResolveMapBuilderRootDirectory() {
            string currentDir = Directory.GetCurrentDirectory();
            if (Directory.Exists(Path.Combine(currentDir, "profiles"))) {
                return currentDir;
            }
            if (Directory.Exists(Path.Combine(currentDir, "map-builder", "profiles"))) {
                return Path.Combine(currentDir, "map-builder");
            }

            string? probeDir = AppContext.BaseDirectory;
            for (int depth = 0; (depth < 6) && (!string.IsNullOrEmpty(probeDir)); depth++) {
                if (Directory.Exists(Path.Combine(probeDir, "profiles"))) {
                    return probeDir;
                }
                DirectoryInfo? parentInfo = Directory.GetParent(probeDir);
                probeDir = (parentInfo != null) ? parentInfo.FullName : null;
            }

            return currentDir;
        }

        /// <summary>
        /// Ensures the YAML schema profile files exist in the target profiles directory, copying them from the application root if needed.
        /// </summary>
        private static void EnsureProfilesAvailable(string sourceProfilesDirectory, string targetProfilesDirectory) {
            if (string.Equals(Path.GetFullPath(sourceProfilesDirectory), Path.GetFullPath(targetProfilesDirectory), StringComparison.OrdinalIgnoreCase)) {
                return;
            }

            Directory.CreateDirectory(targetProfilesDirectory);

            if (Directory.Exists(sourceProfilesDirectory)) {
                string[] sourceFileList = Directory.GetFiles(sourceProfilesDirectory);
                foreach (string sourceFilePath in sourceFileList) {
                    string destinationFilePath = Path.Combine(targetProfilesDirectory, Path.GetFileName(sourceFilePath));
                    if ((!File.Exists(destinationFilePath)) || (File.GetLastWriteTimeUtc(sourceFilePath) > File.GetLastWriteTimeUtc(destinationFilePath))) {
                        File.Copy(sourceFilePath, destinationFilePath, true);
                    }
                }
            }
        }

        private static void PrintHelpBanner() {
            Console.WriteLine("================================================================================");
            Console.WriteLine("  NaRotta Offline Map Builder CLI (.NET 10 - Windows & Linux/Unix)");
            Console.WriteLine("================================================================================");
            Console.WriteLine("Usage:");
            Console.WriteLine("  dotnet run -- <command> [options]");
            Console.WriteLine("");
            Console.WriteLine("Commands:");
            Console.WriteLine("  doctor          Inspect system RAM, disk space, Java JVM, and Valhalla modes");
            Console.WriteLine("  list            List Geofabrik regions and bounding boxes");
            Console.WriteLine("  download        Download .osm.pbf (with MD5 & resume) + SRTM .hgt DEM tiles");
            Console.WriteLine("  build-search    Build offline SQLite FTS5 & R-Tree search database (.db)");
            Console.WriteLine("  build-tiles     Build multi-resolution Vector Tiles (.mbtiles) with Planetiler");
            Console.WriteLine("  build-routing   Build hierarchical Valhalla routing tiles (.tar)");
            Console.WriteLine("  build-overview  Build low-zoom world/continental overview map (Zoom 0-7)");
            Console.WriteLine("  build-assets    Build offline MapLibre day/night styles, sprites, and glyphs");
            Console.WriteLine("  build           Run the complete end-to-end pipeline and update manifest.json");
            Console.WriteLine("  batch-build     Build all child countries/regions under --region <continent>");
            Console.WriteLine("  build-world     Build all countries across all continents in batch mode");
            Console.WriteLine("");
            Console.WriteLine("Options:");
            Console.WriteLine("  --region, -r <id>         Target Geofabrik region (e.g. europe/italy or italy/nord-est)");
            Console.WriteLine("  --resolutions <csv>       Layers to build: base,pedestrian,buildings,terrain,overview or all");
            Console.WriteLine("  --slice-cells             Slice maps into 0.5°x0.5° Geo-Cells for finger-lasso & route corridors");
            Console.WriteLine("  --split-subregions        Slice parent tiles and routing into child subregions without border clipping");
            Console.WriteLine("  --resume                  Skip regions already built in manifest.json during batch-build/build-world");
            Console.WriteLine("  --clean-workspace         Delete temporary .osm.pbf after each region in batch-build/build-world");
            Console.WriteLine("  --no-elevation            Skip SRTM DEM (.hgt) elevation download");
            Console.WriteLine("  --skip-tiles              Skip Planetiler vector tile generation in 'build'");
            Console.WriteLine("  --skip-routing            Skip Valhalla routing generation in 'build'");
            Console.WriteLine("  --skip-search             Skip SQLite search database generation in 'build'");
            Console.WriteLine("  --force                   Force re-download of cached .osm.pbf files");
            Console.WriteLine("================================================================================");
        }
    }
}
