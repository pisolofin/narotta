using NaRotta.MapBuilder.Core.Logging;
using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Core.Runners;
using NaRotta.MapBuilder.Core.Services;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Orchestrator {
    /// <summary>
    /// Thread-safe singleton orchestrator managing offline map generation jobs, real-time logging, and graceful cancellation.
    /// </summary>
    public class MapBuildOrchestrator : IMapBuildOrchestrator {
        private readonly object _stateLock = new object();
        private readonly BuildProgressModel _currentProgress = new BuildProgressModel();
        private readonly BuildLogBuffer _logBuffer;
        private readonly HttpClient _httpClient;
        private readonly IProcessRunner _processRunner;
        private readonly HardwareProfilerService _hardwareProfilerService;
        private readonly GeofabrikCatalogService _catalogService;
        private readonly PbfDownloadService _downloadService;
        private readonly DemElevationService _elevationService;
        private readonly PlanetilerTileService _tileService;
        private readonly GeoCellGridService _geoCellGridService;
        private readonly ValhallaRoutingService _routingService;
        private readonly SearchDatabaseService _searchDatabaseService;
        private readonly OfflineAssetsService _offlineAssetsService;
        private readonly ManifestGeneratorService _manifestService;

        private CancellationTokenSource? _activeCancellationTokenSource;
        private Task? _activeBuildTask;
        private string _lastMonitoredRegion = string.Empty;
        private int _lastMonitoredCompletedCount = -1;

        public BuildLogBuffer LogBuffer => _logBuffer;
        public string DefaultWorkspaceDirectory { get; set; } = string.Empty;
        public string DefaultOutputDirectory { get; set; } = string.Empty;

        public MapBuildOrchestrator(
            HttpClient httpClient,
            IProcessRunner processRunner,
            BuildLogBuffer logBuffer
        ) {
            _httpClient = httpClient;
            _processRunner = processRunner;
            _logBuffer = logBuffer;

            _hardwareProfilerService = new HardwareProfilerService(_processRunner);
            _catalogService = new GeofabrikCatalogService(_httpClient);
            _downloadService = new PbfDownloadService(_httpClient);
            _elevationService = new DemElevationService(_httpClient);
            _tileService = new PlanetilerTileService(_httpClient, _processRunner);
            _geoCellGridService = new GeoCellGridService();
            _routingService = new ValhallaRoutingService(_processRunner);
            _searchDatabaseService = new SearchDatabaseService();
            _offlineAssetsService = new OfflineAssetsService();
            _manifestService = new ManifestGeneratorService();
        }

        public BuildProgressModel GetCurrentProgress() {
            lock (_stateLock) {
                if ((_activeBuildTask == null) || _activeBuildTask.IsCompleted) {
                    RefreshExternalCliProcessStatus();
                }

                return _currentProgress.CloneSnapshot();
            }
        }

        public Task<bool> StartBuildAsync(BuildOptionsModel options) {
            lock (_stateLock) {
                if ((_currentProgress.Status == BuildJobStatus.Running) || (_currentProgress.Status == BuildJobStatus.Cancelling)) {
                    _logBuffer.AppendLog("Cannot start build: another job is already in progress.", "WARN");
                    return Task.FromResult(false);
                }

                _currentProgress.JobId = Guid.NewGuid().ToString("N");
                _currentProgress.Status = BuildJobStatus.Running;
                _currentProgress.CommandName = options.CommandName;
                _currentProgress.ActiveRegionId = options.RegionId;
                _currentProgress.ActiveRegionName = options.RegionId;
                _currentProgress.CurrentRegionIndex = 0;
                _currentProgress.TotalRegionCount = 1;
                _currentProgress.CurrentStage = BuildStage.Initializing;
                _currentProgress.CurrentStageDescription = "Starting build pipeline for " + options.RegionId;
                _currentProgress.PercentCompleted = 0.0;
                _currentProgress.StartedAtUtc = DateTime.UtcNow;
                _currentProgress.FinishedAtUtc = null;
                _currentProgress.ErrorMessage = null;

                _activeCancellationTokenSource = new CancellationTokenSource();
                CancellationToken cancellationToken = _activeCancellationTokenSource.Token;

                _activeBuildTask = Task.Run(async () => {
                    await ExecuteBuildJobAsync(options, cancellationToken);
                });

                return Task.FromResult(true);
            }
        }

        public Task<bool> StopBuildAsync() {
            lock (_stateLock) {
                if (_currentProgress.Status != BuildJobStatus.Running) {
                    return Task.FromResult(false);
                }

                _currentProgress.Status = BuildJobStatus.Cancelling;
                _currentProgress.CurrentStageDescription = "Stopping pipeline, waiting for active processes to terminate...";
                _logBuffer.AppendLog("Cancellation requested by user. Aborting active build...", "WARN", _currentProgress.ActiveRegionId);

                _activeCancellationTokenSource?.Cancel();

                // Terminate external CLI process if attached
                try {
                    int currentPid = Environment.ProcessId;
                    Process[] processList = Process.GetProcessesByName("narotta-map");
                    foreach (Process proc in processList) {
                        if (proc.Id != currentPid) {
                            proc.Kill(true);
                            _logBuffer.AppendLog("Terminated external CLI process PID " + proc.Id.ToString(CultureInfo.InvariantCulture), "WARN");
                        }
                    }
                }catch (Exception exception) {
                    _logBuffer.AppendLog("Failed to stop external CLI process: " + exception.Message, "ERROR");
                }

                _currentProgress.Status = BuildJobStatus.Cancelled;
                _currentProgress.CurrentStage = BuildStage.None;
                _currentProgress.CurrentStageDescription = "Build stopped by user";
                _currentProgress.FinishedAtUtc = DateTime.UtcNow;

                return Task.FromResult(true);
            }
        }

        private void RefreshExternalCliProcessStatus() {
            Process[] processList = Process.GetProcessesByName("narotta-map");
            Process? externalProcess = null;
            int currentPid = Environment.ProcessId;

            foreach (Process proc in processList) {
                if (proc.Id != currentPid) {
                    externalProcess = proc;
                    break;
                }
            }

            if (externalProcess == null) {
                // If previously was monitoring an external CLI process that just finished, transition to Completed
                if (_currentProgress.JobId.StartsWith("cli-", StringComparison.OrdinalIgnoreCase) && (_currentProgress.Status == BuildJobStatus.Running)) {
                    _currentProgress.Status = BuildJobStatus.Completed;
                    _currentProgress.CurrentStage = BuildStage.None;
                    _currentProgress.CurrentStageDescription = "External CLI process finished";
                    _currentProgress.PercentCompleted = 100.0;
                    _currentProgress.FinishedAtUtc = DateTime.UtcNow;
                    _logBuffer.AppendLog("External CLI process has completed successfully.", "INFO");
                }
                return;
            }

            string workspaceDir = !string.IsNullOrWhiteSpace(this.DefaultWorkspaceDirectory) ? this.DefaultWorkspaceDirectory : @"C:\narotta-workspace";
            string outputDir = !string.IsNullOrWhiteSpace(this.DefaultOutputDirectory) ? this.DefaultOutputDirectory : @"\\192.168.8.53\Miscuglio\Narotta\data\output";

            string activeRegion = "world";
            var stage = BuildStage.BuildingTilesBase;
            string stageDescription = "Active offline map processing";

            // Inspect workspace/pbf for .part or latest .osm.pbf
            string pbfDir = Path.Combine(workspaceDir, "pbf");
            if (Directory.Exists(pbfDir)) {
                try {
                    var pbfDirInfo = new DirectoryInfo(pbfDir);
                    FileInfo[] partFileList = pbfDirInfo.GetFiles("*.part");
                    if (partFileList.Length > 0) {
                        stage = BuildStage.DownloadingPbf;
                        activeRegion = partFileList[0].Name.Replace("-latest.osm.pbf.part", "").Replace(".osm.pbf.part", "");
                        long mbDownloaded = partFileList[0].Length / (1024 * 1024);
                        stageDescription = "Downloading OpenStreetMap extract for " + activeRegion + " (" + mbDownloaded.ToString() + " MB downloaded)...";
                    }else {
                        FileInfo[] allPbfs = pbfDirInfo.GetFiles("*.osm.pbf");
                        if (allPbfs.Length > 0) {
                            Array.Sort(allPbfs, (FileInfo a, FileInfo b) => b.LastWriteTimeUtc.CompareTo(a.LastWriteTimeUtc));
                            activeRegion = allPbfs[0].Name.Replace("-latest.osm.pbf", "").Replace(".osm.pbf", "");
                            stage = BuildStage.BuildingSearchDatabase;
                            stageDescription = "Extracting offline search DB & compiling vector tiles for " + activeRegion;
                        }
                    }
                }catch {
                    // Ignore transient file inspection errors
                }
            }

            // Inspect planetiler-tmp
            string planetilerTmp = Path.Combine(workspaceDir, "planetiler-tmp");
            if (Directory.Exists(planetilerTmp)) {
                string featureDb = Path.Combine(planetilerTmp, "feature.db");
                if (Directory.Exists(featureDb) || File.Exists(featureDb)) {
                    stage = BuildStage.BuildingTilesBase;
                    stageDescription = "Planetiler is compiling vector tiles for " + activeRegion + " (feature.db active)";
                }
            }

            // Inspect manifest for completed regions count
            int completedCount = 0;
            string manifestPath = Path.Combine(outputDir, "manifest.json");
            if (File.Exists(manifestPath)) {
                try {
                    string manifestJson = File.ReadAllText(manifestPath);
                    using var doc = JsonDocument.Parse(manifestJson);
                    if (doc.RootElement.TryGetProperty("regions", out JsonElement regionsElement) && (regionsElement.ValueKind == JsonValueKind.Array)) {
                        completedCount = regionsElement.GetArrayLength();
                    }
                }catch {
                    // Ignore transient read errors
                }
            }

            int totalWorldCount = 53;
            double percent = (totalWorldCount > 0) ? Math.Min(98.0, Math.Round((completedCount / (double)totalWorldCount) * 100.0, 1)) : 0.0;

            bool isFirstDetection = !_currentProgress.JobId.StartsWith("cli-", StringComparison.OrdinalIgnoreCase);

            _currentProgress.Status = BuildJobStatus.Running;
            _currentProgress.JobId = "cli-" + externalProcess.Id.ToString(CultureInfo.InvariantCulture);
            _currentProgress.CommandName = "build-world (CLI Process #" + externalProcess.Id.ToString(CultureInfo.InvariantCulture) + ")";
            _currentProgress.ActiveRegionId = activeRegion;
            _currentProgress.ActiveRegionName = activeRegion;
            _currentProgress.CurrentRegionIndex = completedCount + 1;
            _currentProgress.TotalRegionCount = totalWorldCount;
            _currentProgress.CurrentStage = stage;
            _currentProgress.CurrentStageDescription = stageDescription;
            _currentProgress.PercentCompleted = percent;

            try {
                _currentProgress.StartedAtUtc = externalProcess.StartTime.ToUniversalTime();
            }catch {
                _currentProgress.StartedAtUtc ??= DateTime.UtcNow;
            }

            if (isFirstDetection) {
                long ramMb = externalProcess.WorkingSet64 / (1024 * 1024);
                _logBuffer.AppendLog("Attached to active CLI process #" + externalProcess.Id.ToString(CultureInfo.InvariantCulture) + " (" + externalProcess.ProcessName + ", RAM: " + ramMb.ToString() + " MB)", "INFO", activeRegion, stage.ToString());
                _logBuffer.AppendLog("Manifest catalog: " + completedCount.ToString(CultureInfo.InvariantCulture) + " regions already built in " + outputDir, "INFO");
                _logBuffer.AppendLog("Current regional operation: " + stageDescription, "INFO", activeRegion, stage.ToString());
                _lastMonitoredRegion = activeRegion;
                _lastMonitoredCompletedCount = completedCount;
            }else if ((activeRegion != _lastMonitoredRegion) || (completedCount != _lastMonitoredCompletedCount)) {
                _logBuffer.AppendLog("Region updated: " + activeRegion + " | Completed: " + completedCount.ToString(CultureInfo.InvariantCulture) + "/" + totalWorldCount.ToString(CultureInfo.InvariantCulture) + " (" + percent.ToString() + "%)", "INFO", activeRegion, stage.ToString());
                _lastMonitoredRegion = activeRegion;
                _lastMonitoredCompletedCount = completedCount;
            }
        }

        public async Task<HardwareProfileModel> GetHardwareProfileAsync(string workspaceDirectory, CancellationToken cancellationToken) {
            return await _hardwareProfilerService.ProfileSystemAsync(workspaceDirectory, cancellationToken);
        }

        public async Task<List<GeofabrikRegionModel>> GetCatalogAsync(string workspaceDirectory, bool forceRefresh, CancellationToken cancellationToken) {
            return await _catalogService.LoadCatalogAsync(workspaceDirectory, forceRefresh, cancellationToken);
        }

        public async Task<ManifestRootModel?> GetCurrentManifestAsync(string outputDirectory, CancellationToken cancellationToken) {
            string manifestFilePath = Path.Combine(outputDirectory, "manifest.json");
            if (!File.Exists(manifestFilePath)) {
                return null;
            }

            try {
                string jsonString = await File.ReadAllTextAsync(manifestFilePath, cancellationToken);
                return JsonSerializer.Deserialize<ManifestRootModel>(jsonString, new JsonSerializerOptions {
                    PropertyNameCaseInsensitive = true
                });
            }catch (Exception exception) {
                _logBuffer.AppendLog("Failed to read manifest.json: " + exception.Message, "WARN");
                return null;
            }
        }

        private async Task ExecuteBuildJobAsync(BuildOptionsModel options, CancellationToken cancellationToken) {
            _logBuffer.ActiveRegionId = options.RegionId;
            _logBuffer.ActiveStageName = BuildStage.Initializing.ToString();
            _logBuffer.AppendLog("=== Build Job Started (" + options.CommandName + ": " + options.RegionId + ") ===", "INFO", options.RegionId);

            try {
                MapBuilderPathHelper.EnsureProfilesAvailable(options.ProfilesDirectory);

                if (options.CommandName == "doctor") {
                    await RunDoctorInternalAsync(options, cancellationToken);
                }else if (options.CommandName == "build-assets") {
                    await RunBuildAssetsInternalAsync(options, cancellationToken);
                }else if (options.CommandName == "build-overview") {
                    await RunBuildOverviewInternalAsync(options, cancellationToken);
                }else if (options.CommandName == "build-search") {
                    await RunBuildSearchInternalAsync(options, cancellationToken);
                }else if (options.CommandName == "build-tiles") {
                    await RunBuildTilesInternalAsync(options, cancellationToken);
                }else if (options.CommandName == "build-routing") {
                    await RunBuildRoutingInternalAsync(options, cancellationToken);
                }else if (options.CommandName == "build") {
                    await RunFullBuildInternalAsync(options, cancellationToken);
                }else if ((options.CommandName == "batch-build") || (options.CommandName == "build-world")) {
                    await RunBatchOrWorldBuildInternalAsync(options, cancellationToken);
                }else {
                    throw new InvalidOperationException("Unknown command: " + options.CommandName);
                }

                lock (_stateLock) {
                    _currentProgress.Status = BuildJobStatus.Completed;
                    _currentProgress.PercentCompleted = 100.0;
                    _currentProgress.CurrentStage = BuildStage.None;
                    _currentProgress.CurrentStageDescription = "Build completed successfully";
                    _currentProgress.FinishedAtUtc = DateTime.UtcNow;
                }
                _logBuffer.AppendLog("=== Build Job Completed Successfully ===", "INFO", options.RegionId);
            }catch (OperationCanceledException) {
                lock (_stateLock) {
                    _currentProgress.Status = BuildJobStatus.Cancelled;
                    _currentProgress.CurrentStage = BuildStage.None;
                    _currentProgress.CurrentStageDescription = "Build cancelled by user";
                    _currentProgress.FinishedAtUtc = DateTime.UtcNow;
                }
                _logBuffer.AppendLog("=== Build Job Cancelled ===", "WARN", options.RegionId);
            }catch (Exception exception) {
                string errorDetail = exception.Message;
                if ((exception is FileNotFoundException fnf) && (!string.IsNullOrEmpty(fnf.FileName)) && (!errorDetail.Contains(fnf.FileName))) {
                    errorDetail += " (" + fnf.FileName + ")";
                }

                lock (_stateLock) {
                    _currentProgress.Status = BuildJobStatus.Failed;
                    _currentProgress.ErrorMessage = errorDetail;
                    _currentProgress.CurrentStage = BuildStage.None;
                    _currentProgress.CurrentStageDescription = "Build failed: " + errorDetail;
                    _currentProgress.FinishedAtUtc = DateTime.UtcNow;
                }
                _logBuffer.AppendLog("=== Build Job Failed: " + errorDetail + " ===", "ERROR", options.RegionId);
                _logBuffer.AppendLog("Exception details: " + exception.ToString(), "ERROR", options.RegionId);
            }finally {
                _logBuffer.ActiveRegionId = null;
                _logBuffer.ActiveStageName = null;
            }
        }

        private void UpdateStage(BuildStage stage, string description, double percentCompleted, string? regionId = null) {
            lock (_stateLock) {
                _currentProgress.CurrentStage = stage;
                _currentProgress.CurrentStageDescription = description;
                _currentProgress.PercentCompleted = Math.Clamp(percentCompleted, 0.0, 100.0);
                if (!string.IsNullOrEmpty(regionId)) {
                    _currentProgress.ActiveRegionId = regionId;
                }
            }
            _logBuffer.ActiveRegionId = regionId ?? _currentProgress.ActiveRegionId;
            _logBuffer.ActiveStageName = stage.ToString();
            _logBuffer.AppendLog("[" + stage.ToString() + "] " + description, "INFO", regionId, stage.ToString());
        }

        private async Task RunDoctorInternalAsync(BuildOptionsModel options, CancellationToken cancellationToken) {
            UpdateStage(BuildStage.DoctorDiagnostics, "Profiling system hardware and dependencies...", 10.0);
            HardwareProfileModel profile = await _hardwareProfilerService.ProfileSystemAsync(options.WorkspaceDirectory, cancellationToken);
            _logBuffer.AppendLog("OS: " + profile.OperatingSystemName + " | CPU Threads: " + profile.CpuThreadCount.ToString(CultureInfo.InvariantCulture), "INFO");
            _logBuffer.AppendLog("RAM: " + profile.TotalRamMegabytes.ToString("N0", CultureInfo.InvariantCulture) + " MB | Disk: " + profile.AvailableDiskGigabytes.ToString("N0", CultureInfo.InvariantCulture) + " GB", "INFO");
            _logBuffer.AppendLog("Java: " + (profile.IsJavaAvailable ? profile.JavaVersionText : "NOT FOUND") + " | Valhalla: " + profile.ValhallaMode.ToString(), "INFO");
            UpdateStage(BuildStage.DoctorDiagnostics, "Doctor diagnostics completed", 100.0);
        }

        private async Task RunBuildAssetsInternalAsync(BuildOptionsModel options, CancellationToken cancellationToken) {
            UpdateStage(BuildStage.BuildingOfflineAssets, "Building offline assets package (sprites, glyphs, styles)...", 20.0);
            await _offlineAssetsService.BuildOfflineAssetsPackageAsync(options, cancellationToken);
            UpdateStage(BuildStage.UpdatingManifest, "Updating manifest.json with offline assets...", 80.0);
            await _manifestService.UpdateManifestAsync(options, new List<GeofabrikRegionModel>(), cancellationToken);
        }

        private async Task RunBuildOverviewInternalAsync(BuildOptionsModel options, CancellationToken cancellationToken) {
            HardwareProfileModel profile = await _hardwareProfilerService.ProfileSystemAsync(options.WorkspaceDirectory, cancellationToken);
            List<GeofabrikRegionModel> catalogList = await _catalogService.LoadCatalogAsync(options.WorkspaceDirectory, false, cancellationToken);
            GeofabrikRegionModel targetRegion = RequireRegion(catalogList, options.RegionId);

            UpdateStage(BuildStage.DownloadingPbf, "Downloading PBF for overview map (" + targetRegion.Name + ")...", 15.0, targetRegion.Id);
            string pbfPath = await _downloadService.EnsurePbfDownloadedAsync(targetRegion, options.WorkspaceDirectory, options.ForceDownload, cancellationToken);

            UpdateStage(BuildStage.BuildingOverviewTiles, "Generating world overview tiles (Z0-Z7)...", 50.0, targetRegion.Id);
            await _tileService.BuildOverviewTilesAsync(targetRegion, pbfPath, options, profile, cancellationToken);

            UpdateStage(BuildStage.UpdatingManifest, "Updating manifest.json...", 90.0, targetRegion.Id);
            await _manifestService.UpdateManifestAsync(options, new List<GeofabrikRegionModel>(), cancellationToken);
        }

        private async Task RunBuildSearchInternalAsync(BuildOptionsModel options, CancellationToken cancellationToken) {
            List<GeofabrikRegionModel> catalogList = await _catalogService.LoadCatalogAsync(options.WorkspaceDirectory, false, cancellationToken);
            GeofabrikRegionModel targetRegion = RequireRegion(catalogList, options.RegionId);

            UpdateStage(BuildStage.DownloadingPbf, "Downloading PBF for search database (" + targetRegion.Name + ")...", 15.0, targetRegion.Id);
            string pbfPath = await _downloadService.EnsurePbfDownloadedAsync(targetRegion, options.WorkspaceDirectory, options.ForceDownload, cancellationToken);

            UpdateStage(BuildStage.BuildingSearchDatabase, "Extracting SQLite FTS5 search index...", 50.0, targetRegion.Id);
            await _searchDatabaseService.BuildSearchDatabaseAsync(targetRegion, pbfPath, options, cancellationToken);

            UpdateStage(BuildStage.UpdatingManifest, "Updating manifest.json...", 90.0, targetRegion.Id);
            await _manifestService.UpdateManifestAsync(options, new List<GeofabrikRegionModel> { targetRegion }, cancellationToken);
        }

        private async Task RunBuildTilesInternalAsync(BuildOptionsModel options, CancellationToken cancellationToken) {
            HardwareProfileModel profile = await _hardwareProfilerService.ProfileSystemAsync(options.WorkspaceDirectory, cancellationToken);
            List<GeofabrikRegionModel> catalogList = await _catalogService.LoadCatalogAsync(options.WorkspaceDirectory, false, cancellationToken);
            GeofabrikRegionModel targetRegion = RequireRegion(catalogList, options.RegionId);

            UpdateStage(BuildStage.DownloadingPbf, "Downloading PBF for vector tiles (" + targetRegion.Name + ")...", 10.0, targetRegion.Id);
            string pbfPath = await _downloadService.EnsurePbfDownloadedAsync(targetRegion, options.WorkspaceDirectory, options.ForceDownload, cancellationToken);

            var updatedRegionList = new List<GeofabrikRegionModel> { targetRegion };
            List<GeofabrikRegionModel> subregionList = options.SplitSubregions
                ? _catalogService.GetSubregionList(catalogList, targetRegion.Id)
                : new List<GeofabrikRegionModel>();

            double progressStep = 70.0 / Math.Max(1, options.ResolutionLayerList.Count);
            double currentProgressPercent = 15.0;

            foreach (MapResolutionLayer layer in options.ResolutionLayerList) {
                UpdateStage(MapResolutionLayerToStage(layer), "Building layer: " + layer.ToString(), currentProgressPercent, targetRegion.Id);
                string parentMbtilesPath = await _tileService.BuildResolutionLayerAsync(targetRegion, pbfPath, layer, options, profile, cancellationToken);

                if (options.SliceGeoCells && (layer != MapResolutionLayer.Overview)) {
                    UpdateStage(BuildStage.SlicingGeoCells, "Slicing " + layer.ToString() + " into 0.5x0.5° cells...", currentProgressPercent + 5.0, targetRegion.Id);
                    await _geoCellGridService.SliceMbtilesIntoGeoCellsAsync(parentMbtilesPath, targetRegion, layer, options, cancellationToken);
                }

                if ((subregionList.Count > 0) && (layer != MapResolutionLayer.Overview)) {
                    UpdateStage(BuildStage.SplittingSubregions, "Splitting subregions for layer " + layer.ToString() + "...", currentProgressPercent + 8.0, targetRegion.Id);
                    foreach (GeofabrikRegionModel subregion in subregionList) {
                        await _tileService.SplitMbtilesForSubregionAsync(parentMbtilesPath, subregion, layer, options, cancellationToken);
                    }
                }

                currentProgressPercent += progressStep;
            }

            foreach (GeofabrikRegionModel subregion in subregionList) {
                updatedRegionList.Add(subregion);
            }

            UpdateStage(BuildStage.UpdatingManifest, "Updating manifest.json...", 95.0, targetRegion.Id);
            await _manifestService.UpdateManifestAsync(options, updatedRegionList, cancellationToken);
        }

        private async Task RunBuildRoutingInternalAsync(BuildOptionsModel options, CancellationToken cancellationToken) {
            HardwareProfileModel profile = await _hardwareProfilerService.ProfileSystemAsync(options.WorkspaceDirectory, cancellationToken);
            List<GeofabrikRegionModel> catalogList = await _catalogService.LoadCatalogAsync(options.WorkspaceDirectory, false, cancellationToken);
            GeofabrikRegionModel targetRegion = RequireRegion(catalogList, options.RegionId);

            UpdateStage(BuildStage.DownloadingPbf, "Downloading PBF for routing graph...", 10.0, targetRegion.Id);
            string pbfPath = await _downloadService.EnsurePbfDownloadedAsync(targetRegion, options.WorkspaceDirectory, options.ForceDownload, cancellationToken);

            bool needsElevation = options.IncludeElevation && (profile.ValhallaMode != ValhallaExecutionMode.CSharpNativeFallback);
            string elevationDirectory = Path.Combine(options.WorkspaceDirectory, "elevation");
            if (needsElevation) {
                UpdateStage(BuildStage.DownloadingElevation, "Downloading DEM elevation tiles...", 20.0, targetRegion.Id);
                elevationDirectory = await _elevationService.EnsureElevationTilesAsync(targetRegion, options.WorkspaceDirectory, cancellationToken);
            }

            UpdateStage(BuildStage.BuildingRoutingGraph, "Compiling Valhalla routing graph...", 40.0, targetRegion.Id);
            string tileDirectory = await _routingService.BuildValhallaTileTreeAsync(targetRegion, pbfPath, elevationDirectory, options, profile, cancellationToken);

            UpdateStage(BuildStage.PackagingRoutingTar, "Packaging regional routing archives...", 80.0, targetRegion.Id);
            var updatedRegionList = new List<GeofabrikRegionModel> { targetRegion };
            await _routingService.PackageRegionRoutingTarAsync(tileDirectory, targetRegion, options, cancellationToken);

            if (options.SplitSubregions) {
                List<GeofabrikRegionModel> subregionList = _catalogService.GetSubregionList(catalogList, targetRegion.Id);
                foreach (GeofabrikRegionModel subregion in subregionList) {
                    await _routingService.PackageRegionRoutingTarAsync(tileDirectory, subregion, options, cancellationToken);
                    updatedRegionList.Add(subregion);
                }
            }

            UpdateStage(BuildStage.UpdatingManifest, "Updating manifest.json...", 95.0, targetRegion.Id);
            await _manifestService.UpdateManifestAsync(options, updatedRegionList, cancellationToken);
        }

        private async Task RunFullBuildInternalAsync(BuildOptionsModel options, CancellationToken cancellationToken) {
            HardwareProfileModel profile = await _hardwareProfilerService.ProfileSystemAsync(options.WorkspaceDirectory, cancellationToken);
            List<GeofabrikRegionModel> catalogList = await _catalogService.LoadCatalogAsync(options.WorkspaceDirectory, false, cancellationToken);
            GeofabrikRegionModel targetRegion = RequireRegion(catalogList, options.RegionId);

            await ExecuteSingleRegionFullPipelineAsync(targetRegion, catalogList, profile, options, 0.0, 100.0, cancellationToken);
        }

        private async Task RunBatchOrWorldBuildInternalAsync(BuildOptionsModel options, CancellationToken cancellationToken) {
            HardwareProfileModel profile = await _hardwareProfilerService.ProfileSystemAsync(options.WorkspaceDirectory, cancellationToken);
            List<GeofabrikRegionModel> catalogList = await _catalogService.LoadCatalogAsync(options.WorkspaceDirectory, false, cancellationToken);

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
                    List<GeofabrikRegionModel> continentChildList = _catalogService.GetSubregionList(catalogList, continentId);
                    foreach (GeofabrikRegionModel countryRegion in continentChildList) {
                        if ((countryRegion.Id == "us") || countryRegion.Id.StartsWith("us-", StringComparison.OrdinalIgnoreCase)) {
                            continue;
                        }
                        targetRegionList.Add(countryRegion);
                    }
                }

                GeofabrikRegionModel? antarcticaRegion = _catalogService.FindRegion(catalogList, "antarctica");
                if (antarcticaRegion != null) {
                    targetRegionList.Add(antarcticaRegion);
                }
            }else {
                targetRegionList = _catalogService.GetSubregionList(catalogList, options.RegionId);
                if (options.RegionId.Equals("north-america", StringComparison.OrdinalIgnoreCase)) {
                    targetRegionList.RemoveAll((GeofabrikRegionModel region) =>
                        (region.Id == "us") || region.Id.StartsWith("us-", StringComparison.OrdinalIgnoreCase)
                    );
                }

                if (targetRegionList.Count == 0) {
                    GeofabrikRegionModel singleRegion = RequireRegion(catalogList, options.RegionId);
                    targetRegionList.Add(singleRegion);
                }
            }

            lock (_stateLock) {
                _currentProgress.TotalRegionCount = targetRegionList.Count;
            }

            _logBuffer.AppendLog("Batch build: " + targetRegionList.Count.ToString(CultureInfo.InvariantCulture) + " regions queued.", "INFO");

            // Step 0: Shared offline assets
            UpdateStage(BuildStage.BuildingOfflineAssets, "Building shared offline assets package...", 2.0);
            await _offlineAssetsService.BuildOfflineAssetsPackageAsync(options, cancellationToken);

            int completedCount = 0;
            foreach (GeofabrikRegionModel region in targetRegionList) {
                cancellationToken.ThrowIfCancellationRequested();
                completedCount++;

                lock (_stateLock) {
                    _currentProgress.CurrentRegionIndex = completedCount;
                    _currentProgress.ActiveRegionId = region.Id;
                    _currentProgress.ActiveRegionName = region.Name;
                }

                if (options.ResumeBatch && (!options.ForceDownload)) {
                    bool isAlreadyBuilt = await _manifestService.IsRegionAlreadyBuiltInManifestAsync(
                        options.OutputDirectory,
                        region.Id,
                        cancellationToken
                    );
                    if (isAlreadyBuilt) {
                        _logBuffer.AppendLog("Skipping '" + region.Id + "' (already present in manifest.json).", "INFO", region.Id);
                        continue;
                    }
                }

                double basePercent = (completedCount - 1) * (95.0 / targetRegionList.Count);
                double targetPercent = completedCount * (95.0 / targetRegionList.Count);

                _logBuffer.AppendLog("Processing region " + completedCount.ToString(CultureInfo.InvariantCulture) + "/" + targetRegionList.Count.ToString(CultureInfo.InvariantCulture) + ": " + region.Name + " (" + region.Id + ")", "INFO", region.Id);

                await ExecuteSingleRegionFullPipelineAsync(region, catalogList, profile, options, basePercent, targetPercent, cancellationToken);
            }
        }

        private async Task ExecuteSingleRegionFullPipelineAsync(
            GeofabrikRegionModel targetRegion,
            List<GeofabrikRegionModel> catalogList,
            HardwareProfileModel profile,
            BuildOptionsModel options,
            double startPercent,
            double endPercent,
            CancellationToken cancellationToken
        ) {
            double range = endPercent - startPercent;

            // 1. Download PBF
            UpdateStage(BuildStage.DownloadingPbf, "Downloading PBF for " + targetRegion.Name, startPercent + (range * 0.1), targetRegion.Id);
            string pbfPath = await _downloadService.EnsurePbfDownloadedAsync(targetRegion, options.WorkspaceDirectory, options.ForceDownload, cancellationToken);

            // 2. DEM Elevation
            string elevationDirectory = Path.Combine(options.WorkspaceDirectory, "elevation");
            if (options.IncludeElevation && (!options.SkipRouting) && (profile.ValhallaMode != ValhallaExecutionMode.CSharpNativeFallback)) {
                UpdateStage(BuildStage.DownloadingElevation, "Downloading DEM elevation tiles...", startPercent + (range * 0.2), targetRegion.Id);
                elevationDirectory = await _elevationService.EnsureElevationTilesAsync(targetRegion, options.WorkspaceDirectory, cancellationToken);
            }

            var updatedRegionList = new List<GeofabrikRegionModel> { targetRegion };
            List<GeofabrikRegionModel> subregionList = options.SplitSubregions
                ? _catalogService.GetSubregionList(catalogList, targetRegion.Id)
                : new List<GeofabrikRegionModel>();

            // 3. Planetiler Tiles
            if (!options.SkipTiles) {
                double tileStep = (range * 0.35) / Math.Max(1, options.ResolutionLayerList.Count);
                double currentPercent = startPercent + (range * 0.25);

                foreach (MapResolutionLayer layer in options.ResolutionLayerList) {
                    UpdateStage(MapResolutionLayerToStage(layer), "Building tiles layer: " + layer.ToString(), currentPercent, targetRegion.Id);
                    string parentMbtilesPath = await _tileService.BuildResolutionLayerAsync(targetRegion, pbfPath, layer, options, profile, cancellationToken);

                    if (options.SliceGeoCells && (layer != MapResolutionLayer.Overview)) {
                        UpdateStage(BuildStage.SlicingGeoCells, "Slicing " + layer.ToString() + " into 0.5x0.5° cells...", currentPercent + (tileStep * 0.3), targetRegion.Id);
                        await _geoCellGridService.SliceMbtilesIntoGeoCellsAsync(parentMbtilesPath, targetRegion, layer, options, cancellationToken);
                    }

                    if ((subregionList.Count > 0) && (layer != MapResolutionLayer.Overview)) {
                        UpdateStage(BuildStage.SplittingSubregions, "Splitting subregions for layer " + layer.ToString() + "...", currentPercent + (tileStep * 0.6), targetRegion.Id);
                        foreach (GeofabrikRegionModel subregion in subregionList) {
                            await _tileService.SplitMbtilesForSubregionAsync(parentMbtilesPath, subregion, layer, options, cancellationToken);
                        }
                    }

                    currentPercent += tileStep;
                }
            }

            // 4. Valhalla Routing
            if (!options.SkipRouting) {
                UpdateStage(BuildStage.BuildingRoutingGraph, "Compiling Valhalla routing graph...", startPercent + (range * 0.65), targetRegion.Id);
                string tileDirectory = await _routingService.BuildValhallaTileTreeAsync(targetRegion, pbfPath, elevationDirectory, options, profile, cancellationToken);

                UpdateStage(BuildStage.PackagingRoutingTar, "Packaging routing archives...", startPercent + (range * 0.75), targetRegion.Id);
                await _routingService.PackageRegionRoutingTarAsync(tileDirectory, targetRegion, options, cancellationToken);

                if (options.SplitSubregions) {
                    foreach (GeofabrikRegionModel subregion in subregionList) {
                        await _routingService.PackageRegionRoutingTarAsync(tileDirectory, subregion, options, cancellationToken);
                    }
                }
            }

            // 5. Search Database (SQLite FTS5)
            if (!options.SkipSearch) {
                UpdateStage(BuildStage.BuildingSearchDatabase, "Generating offline search database...", startPercent + (range * 0.85), targetRegion.Id);
                await _searchDatabaseService.BuildSearchDatabaseAsync(targetRegion, pbfPath, options, cancellationToken);
            }

            // 6. Manifest
            foreach (GeofabrikRegionModel subregion in subregionList) {
                updatedRegionList.Add(subregion);
            }

            UpdateStage(BuildStage.UpdatingManifest, "Updating manifest.json...", startPercent + (range * 0.95), targetRegion.Id);
            await _manifestService.UpdateManifestAsync(options, updatedRegionList, cancellationToken);

            // 7. Cleanup Workspace
            if (options.CleanWorkspaceAfterBuild) {
                UpdateStage(BuildStage.CleaningWorkspace, "Cleaning temporary workspace files...", endPercent, targetRegion.Id);
                CleanWorkspaceTemporaryFiles(options.WorkspaceDirectory, targetRegion.GetFileSlug());
            }
        }

        private static void CleanWorkspaceTemporaryFiles(string workspaceDirectory, string regionFileSlug) {
            try {
                string planetilerTmp = Path.Combine(workspaceDirectory, "planetiler-tmp");
                if (Directory.Exists(planetilerTmp)) {
                    Directory.Delete(planetilerTmp, true);
                }

                string valhallaTilesDir = Path.Combine(workspaceDirectory, "valhalla", "valhalla_tiles");
                if (Directory.Exists(valhallaTilesDir)) {
                    Directory.Delete(valhallaTilesDir, true);
                }

                string pbfFile = Path.Combine(workspaceDirectory, "pbf", regionFileSlug + "-latest.osm.pbf");
                if (File.Exists(pbfFile)) {
                    File.Delete(pbfFile);
                }
            }catch {
                // Ignore transient cleanup errors
            }
        }

        private GeofabrikRegionModel RequireRegion(List<GeofabrikRegionModel> catalogList, string regionId) {
            GeofabrikRegionModel? region = _catalogService.FindRegion(catalogList, regionId);
            if (region == null) {
                throw new ArgumentException("Region not found in Geofabrik catalog: " + regionId);
            }
            return region;
        }

        private static BuildStage MapResolutionLayerToStage(MapResolutionLayer layer) {
            switch (layer) {
                case MapResolutionLayer.Overview:
                    return BuildStage.BuildingOverviewTiles;
                case MapResolutionLayer.Base:
                    return BuildStage.BuildingTilesBase;
                case MapResolutionLayer.Pedestrian:
                    return BuildStage.BuildingTilesPedestrian;
                case MapResolutionLayer.Buildings:
                    return BuildStage.BuildingTilesBuildings;
                case MapResolutionLayer.Terrain:
                    return BuildStage.BuildingTilesTerrain;
                default:
                    return BuildStage.BuildingTilesBase;
            }
        }
    }
}
