using Microsoft.Extensions.Configuration;
using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Core.Services;
using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace NaRotta.MapBuilder.Web.Services {
    /// <summary>
    /// Thread-safe manager responsible for resolving, validating, and persisting runtime storage directory settings.
    /// </summary>
    public class MapBuilderConfigService {
        private readonly object _syncLock = new object();
        private readonly string _contentRootAppSettingsPath;
        private readonly string _baseDirAppSettingsPath;
        private MapBuilderSettingsModel _currentSettings;

        public MapBuilderConfigService(IConfiguration configuration, string? contentRootPath = null) {
            string baseDirectory = AppContext.BaseDirectory;
            _baseDirAppSettingsPath = Path.Combine(baseDirectory, "appsettings.Local.json");

            string rootDir = !string.IsNullOrWhiteSpace(contentRootPath)
                ? contentRootPath
                : ResolveSourceProjectDirectory(baseDirectory);
            _contentRootAppSettingsPath = Path.Combine(rootDir, "appsettings.Local.json");

            _currentSettings = new MapBuilderSettingsModel {
                WorkspaceDirectory = ResolveWorkspaceDirectory(configuration, baseDirectory),
                OutputDirectory = ResolveOutputDirectory(configuration, baseDirectory),
                ProfilesDirectory = ResolveProfilesDirectory(configuration, baseDirectory),
                ToolsDirectory = ResolveToolsDirectory(configuration, baseDirectory),
                BaseUrl = ResolveBaseUrl(configuration)
            };

            // Ensure directories exist and schema profiles are provisioned
            EnsureDirectoryExists(_currentSettings.WorkspaceDirectory);
            EnsureDirectoryExists(_currentSettings.OutputDirectory);
            EnsureDirectoryExists(_currentSettings.ProfilesDirectory);
            EnsureDirectoryExists(_currentSettings.ToolsDirectory);

            MapBuilderPathHelper.EnsureProfilesAvailable(_currentSettings.ProfilesDirectory);
        }

        public MapBuilderSettingsModel GetSettings() {
            lock (_syncLock) {
                return _currentSettings.Clone();
            }
        }

        public bool UpdateSettings(MapBuilderSettingsModel newSettings, bool persistToFile, out string? errorMessage) {
            errorMessage = null;

            if (string.IsNullOrWhiteSpace(newSettings.WorkspaceDirectory)) {
                errorMessage = "WorkspaceDirectory cannot be empty";
                return false;
            }

            if (string.IsNullOrWhiteSpace(newSettings.OutputDirectory)) {
                errorMessage = "OutputDirectory cannot be empty";
                return false;
            }

            lock (_syncLock) {
                _currentSettings.WorkspaceDirectory = newSettings.WorkspaceDirectory.Trim();
                _currentSettings.OutputDirectory = newSettings.OutputDirectory.Trim();

                if (!string.IsNullOrWhiteSpace(newSettings.ProfilesDirectory)) {
                    _currentSettings.ProfilesDirectory = newSettings.ProfilesDirectory.Trim();
                }

                if (!string.IsNullOrWhiteSpace(newSettings.ToolsDirectory)) {
                    _currentSettings.ToolsDirectory = newSettings.ToolsDirectory.Trim();
                }

                if (!string.IsNullOrWhiteSpace(newSettings.BaseUrl)) {
                    _currentSettings.BaseUrl = newSettings.BaseUrl.Trim();
                }

                _currentSettings.PlanetilerMaxHeapGigabytes = newSettings.PlanetilerMaxHeapGigabytes;

                EnsureDirectoryExists(_currentSettings.WorkspaceDirectory);
                EnsureDirectoryExists(_currentSettings.OutputDirectory);
                EnsureDirectoryExists(_currentSettings.ProfilesDirectory);
                EnsureDirectoryExists(_currentSettings.ToolsDirectory);

                MapBuilderPathHelper.EnsureProfilesAvailable(_currentSettings.ProfilesDirectory);

                if (persistToFile) {
                    try {
                        PersistToAppSettingsJson(_currentSettings);
                    }catch (Exception exception) {
                        errorMessage = "Settings updated in memory but failed to save to appsettings.json: " + exception.Message;
                    }
                }

                return true;
            }
        }

        public DirectoryValidationModel ValidateDirectory(string directoryPath) {
            var model = new DirectoryValidationModel {
                Path = directoryPath
            };

            if (string.IsNullOrWhiteSpace(directoryPath)) {
                model.ErrorMessage = "Path is empty";
                return model;
            }

            try {
                model.Exists = Directory.Exists(directoryPath);
                if (!model.Exists) {
                    // Test if parent can be created
                    Directory.CreateDirectory(directoryPath);
                    model.Exists = Directory.Exists(directoryPath);
                }

                // Test write permissions
                string probeFile = Path.Combine(directoryPath, ".narotta_probe_" + Guid.NewGuid().ToString("N"));
                File.WriteAllText(probeFile, "narotta_test");
                File.Delete(probeFile);
                model.IsWritable = true;

                // Inspect drive space if local drive
                try {
                    string rootPath = Path.GetPathRoot(Path.GetFullPath(directoryPath)) ?? string.Empty;
                    if (!string.IsNullOrEmpty(rootPath)) {
                        var driveInfo = new DriveInfo(rootPath);
                        if (driveInfo.IsReady) {
                            model.AvailableFreeSpaceBytes = driveInfo.AvailableFreeSpace;
                            model.TotalSpaceBytes = driveInfo.TotalSize;
                        }
                    }
                }catch {
                    // Ignore UNC network share drive query errors
                }
            }catch (Exception exception) {
                model.ErrorMessage = exception.Message;
                model.IsWritable = false;
            }

            return model;
        }

        private static string ResolveWorkspaceDirectory(IConfiguration configuration, string baseDirectory) {
            string? envPath = Environment.GetEnvironmentVariable("WORKSPACE_DIR");
            if (!string.IsNullOrEmpty(envPath)) {
                return envPath;
            }

            string? configPath = configuration["MapBuilder:WorkspaceDirectory"];
            if (!string.IsNullOrEmpty(configPath)) {
                return configPath;
            }

            if (OperatingSystem.IsWindows() && Directory.Exists(@"C:\narotta-workspace")) {
                return @"C:\narotta-workspace";
            }

            return Path.Combine(baseDirectory, "workspace");
        }

        private static string ResolveOutputDirectory(IConfiguration configuration, string baseDirectory) {
            string? envPath = Environment.GetEnvironmentVariable("OUTPUT_DIR");
            if (!string.IsNullOrEmpty(envPath)) {
                return envPath;
            }

            string? configPath = configuration["MapBuilder:OutputDirectory"];
            if (!string.IsNullOrEmpty(configPath)) {
                return configPath;
            }

            if (OperatingSystem.IsWindows() && Directory.Exists(@"\\192.168.8.53\Miscuglio\Narotta\data\output")) {
                return @"\\192.168.8.53\Miscuglio\Narotta\data\output";
            }

            return Path.Combine(baseDirectory, "output");
        }

        private static string ResolveProfilesDirectory(IConfiguration configuration, string baseDirectory) {
            string? envPath = Environment.GetEnvironmentVariable("PROFILES_DIR");
            if (!string.IsNullOrEmpty(envPath)) {
                return envPath;
            }

            string? configPath = configuration["MapBuilder:ProfilesDirectory"];
            if (!string.IsNullOrEmpty(configPath)) {
                return configPath;
            }

            string? discoveredDir = MapBuilderPathHelper.FindProfilesDirectory(baseDirectory);
            if (!string.IsNullOrEmpty(discoveredDir)) {
                return discoveredDir;
            }

            return Path.Combine(baseDirectory, "profiles");
        }

        private static string ResolveToolsDirectory(IConfiguration configuration, string baseDirectory) {
            string? envPath = Environment.GetEnvironmentVariable("TOOLS_DIR");
            if (!string.IsNullOrEmpty(envPath)) {
                return envPath;
            }

            string? configPath = configuration["MapBuilder:ToolsDirectory"];
            if (!string.IsNullOrEmpty(configPath)) {
                return configPath;
            }

            string? discoveredDir = MapBuilderPathHelper.FindToolsDirectory(baseDirectory);
            if (!string.IsNullOrEmpty(discoveredDir)) {
                return discoveredDir;
            }

            return Path.Combine(baseDirectory, "tools");
        }

        private static string ResolveBaseUrl(IConfiguration configuration) {
            string? envBaseUrl = Environment.GetEnvironmentVariable("BASE_URL");
            if (!string.IsNullOrEmpty(envBaseUrl)) {
                return envBaseUrl;
            }

            string? configBaseUrl = configuration["MapBuilder:BaseUrl"];
            if (!string.IsNullOrEmpty(configBaseUrl)) {
                return configBaseUrl;
            }

            return "https://storage.narotta.app/maps/";
        }

        private static void EnsureDirectoryExists(string directoryPath) {
            try {
                if (!string.IsNullOrWhiteSpace(directoryPath)) {
                    Directory.CreateDirectory(directoryPath);
                }
            }catch {
                // Ignore initial creation errors for remote shares if offline
            }
        }

        private void PersistToAppSettingsJson(MapBuilderSettingsModel settings) {
            var targetFileList = new List<string>();
            if (!string.IsNullOrWhiteSpace(_contentRootAppSettingsPath)) {
                targetFileList.Add(_contentRootAppSettingsPath);
            }
            if (!string.IsNullOrWhiteSpace(_baseDirAppSettingsPath) && (!targetFileList.Exists((string p) => string.Equals(p, _baseDirAppSettingsPath, StringComparison.OrdinalIgnoreCase)))) {
                targetFileList.Add(_baseDirAppSettingsPath);
            }
            if (!string.IsNullOrWhiteSpace(settings.WorkspaceDirectory)) {
                try {
                    string workspaceFile = Path.Combine(settings.WorkspaceDirectory, "mapbuilder.settings.json");
                    if (!targetFileList.Exists((string p) => string.Equals(p, workspaceFile, StringComparison.OrdinalIgnoreCase))) {
                        targetFileList.Add(workspaceFile);
                    }
                }catch {
                    // Ignore path formatting errors
                }
            }

            foreach (string filePath in targetFileList) {
                try {
                    string? directoryName = Path.GetDirectoryName(filePath);
                    if (!string.IsNullOrEmpty(directoryName)) {
                        Directory.CreateDirectory(directoryName);
                    }

                    JsonObject rootObject;
                    if (File.Exists(filePath)) {
                        string existingJson = File.ReadAllText(filePath);
                        rootObject = JsonNode.Parse(existingJson) as JsonObject ?? new JsonObject();
                    }else {
                        rootObject = new JsonObject();
                    }

                    var mapBuilderSection = new JsonObject {
                        ["WorkspaceDirectory"] = settings.WorkspaceDirectory,
                        ["OutputDirectory"] = settings.OutputDirectory,
                        ["ProfilesDirectory"] = settings.ProfilesDirectory,
                        ["ToolsDirectory"] = settings.ToolsDirectory,
                        ["BaseUrl"] = settings.BaseUrl
                    };

                    if (settings.PlanetilerMaxHeapGigabytes.HasValue) {
                        mapBuilderSection["PlanetilerMaxHeapGigabytes"] = settings.PlanetilerMaxHeapGigabytes.Value;
                    }

                    rootObject["MapBuilder"] = mapBuilderSection;

                    var options = new JsonSerializerOptions {
                        WriteIndented = true
                    };
                    File.WriteAllText(filePath, rootObject.ToJsonString(options));
                }catch (Exception exception) {
                    Console.WriteLine("[MapBuilderConfig] Failed to save settings to " + filePath + ": " + exception.Message);
                }
            }
        }

        private static string ResolveSourceProjectDirectory(string baseDirectory) {
            string? probeDir = baseDirectory;
            for (int depth = 0; (depth < 6) && (!string.IsNullOrEmpty(probeDir)); depth++) {
                if (File.Exists(Path.Combine(probeDir, "NaRotta.MapBuilder.Web.csproj")) ||
                    (File.Exists(Path.Combine(probeDir, "appsettings.json")) && Directory.Exists(Path.Combine(probeDir, "wwwroot")))) {
                    return probeDir;
                }
                DirectoryInfo? parent = Directory.GetParent(probeDir);
                probeDir = (parent != null) ? parent.FullName : null;
            }
            return baseDirectory;
        }
    }
}
