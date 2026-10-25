using System;
using System.Collections.Generic;

namespace NaRotta.MapBuilder.Core.Models {
    /// <summary>
    /// Enumeration of available map tile resolution and functional layers.
    /// </summary>
    public enum MapResolutionLayer {
        Overview,
        Base,
        Pedestrian,
        Buildings,
        Terrain
    }

    /// <summary>
    /// Represents the parsed CLI command and configuration options for the map builder pipeline.
    /// </summary>
    public class BuildOptionsModel {
        public string CommandName { get; set; } = "help";
        public string RegionId { get; set; } = "europe/italy/trentino-alto-adige";
        public string WorkspaceDirectory { get; set; } = string.Empty;
        public string OutputDirectory { get; set; } = string.Empty;
        public string ProfilesDirectory { get; set; } = string.Empty;
        public string ToolsDirectory { get; set; } = string.Empty;
        public string BaseUrl { get; set; } = "https://storage.narotta.app/maps/";
        public bool SplitSubregions { get; set; } = false;
        public bool SliceGeoCells { get; set; } = false;
        public bool CleanWorkspaceAfterBuild { get; set; } = false;
        public bool ResumeBatch { get; set; } = false;
        public bool IncludeElevation { get; set; } = true;
        public bool SkipRouting { get; set; } = false;
        public bool SkipTiles { get; set; } = false;
        public bool SkipSearch { get; set; } = false;
        public bool ForceDownload { get; set; } = false;
        public List<MapResolutionLayer> ResolutionLayerList { get; set; } = new List<MapResolutionLayer>();

        /// <summary>
        /// Parses raw command-line arguments into a strongly typed <see cref="BuildOptionsModel"/>.
        /// </summary>
        public static BuildOptionsModel ParseArguments(string[] rawArgumentList, string baseDirectory) {
            var options = new BuildOptionsModel {
                WorkspaceDirectory = System.IO.Path.Combine(baseDirectory, "workspace"),
                OutputDirectory = System.IO.Path.Combine(baseDirectory, "output"),
                ProfilesDirectory = System.IO.Path.Combine(baseDirectory, "profiles"),
                ToolsDirectory = System.IO.Path.Combine(baseDirectory, "tools"),
                ResolutionLayerList = new List<MapResolutionLayer> {
                    MapResolutionLayer.Base,
                    MapResolutionLayer.Pedestrian,
                    MapResolutionLayer.Buildings,
                    MapResolutionLayer.Terrain
                }
            };

            if ((rawArgumentList == null) || (rawArgumentList.Length == 0)) {
                return options;
            }

            // First positional argument is the command name unless it starts with a dash
            int startIndex = 0;
            if (!rawArgumentList[0].StartsWith("-", StringComparison.Ordinal)) {
                options.CommandName = rawArgumentList[0].Trim().ToLowerInvariant();
                startIndex = 1;
            }

            // Configure all-in-one defaults when executing 'build-world' so no extra flags or steps are needed
            if (options.CommandName == "build-world") {
                options.SplitSubregions = true;
                options.SliceGeoCells = true;
                options.CleanWorkspaceAfterBuild = true;
                options.ResumeBatch = true;
                options.ResolutionLayerList = new List<MapResolutionLayer> {
                    MapResolutionLayer.Overview,
                    MapResolutionLayer.Base,
                    MapResolutionLayer.Pedestrian,
                    MapResolutionLayer.Buildings,
                    MapResolutionLayer.Terrain
                };
            }

            bool isExplicitWorkspace = false;
            bool isExplicitOutput = false;
            bool isExplicitProfiles = false;

            // Parse flag and key-value arguments
            for (int index = startIndex; index < rawArgumentList.Length; index++) {
                string currentArg = rawArgumentList[index].Trim();
                string nextValue = ((index + 1) < rawArgumentList.Length) ? rawArgumentList[index + 1].Trim() : string.Empty;

                if ((currentArg == "--region") || (currentArg == "-r") || (currentArg == "--parent")) {
                    if (!string.IsNullOrEmpty(nextValue)) {
                        options.RegionId = nextValue.Trim('/').ToLowerInvariant();
                        index++;
                    }
                }else if ((currentArg == "--workspace") || (currentArg == "-w")) {
                    if (!string.IsNullOrEmpty(nextValue)) {
                        options.WorkspaceDirectory = System.IO.Path.GetFullPath(nextValue);
                        isExplicitWorkspace = true;
                        index++;
                    }
                }else if ((currentArg == "--output") || (currentArg == "-o")) {
                    if (!string.IsNullOrEmpty(nextValue)) {
                        options.OutputDirectory = System.IO.Path.GetFullPath(nextValue);
                        isExplicitOutput = true;
                        index++;
                    }
                }else if ((currentArg == "--profiles") || (currentArg == "-p")) {
                    if (!string.IsNullOrEmpty(nextValue)) {
                        options.ProfilesDirectory = System.IO.Path.GetFullPath(nextValue);
                        isExplicitProfiles = true;
                        index++;
                    }
                }else if (currentArg == "--base-url") {
                    if (!string.IsNullOrEmpty(nextValue)) {
                        options.BaseUrl = nextValue;
                        index++;
                    }
                }else if (currentArg == "--resolutions") {
                    if (!string.IsNullOrEmpty(nextValue)) {
                        options.ResolutionLayerList = ParseResolutionLayerList(nextValue);
                        index++;
                    }
                }else if (currentArg == "--split-subregions") {
                    options.SplitSubregions = true;
                }else if (currentArg == "--slice-cells") {
                    options.SliceGeoCells = true;
                }else if (currentArg == "--clean-workspace") {
                    options.CleanWorkspaceAfterBuild = true;
                }else if (currentArg == "--resume") {
                    options.ResumeBatch = true;
                }else if (currentArg == "--no-elevation") {
                    options.IncludeElevation = false;
                }else if (currentArg == "--skip-routing") {
                    options.SkipRouting = true;
                }else if (currentArg == "--skip-tiles") {
                    options.SkipTiles = true;
                }else if (currentArg == "--skip-search") {
                    options.SkipSearch = true;
                }else if (currentArg == "--force") {
                    options.ForceDownload = true;
                }else if ((currentArg == "--help") || (currentArg == "-h")) {
                    options.CommandName = "help";
                }
            }

            // Align workspace and profiles to the same level as output when output is custom and they were not explicitly overridden
            if (isExplicitOutput) {
                string trimmedOutput = options.OutputDirectory.TrimEnd(System.IO.Path.DirectorySeparatorChar, System.IO.Path.AltDirectorySeparatorChar);
                string? outputParent = System.IO.Path.GetDirectoryName(trimmedOutput);
                if (!string.IsNullOrEmpty(outputParent)) {
                    if (!isExplicitWorkspace) {
                        options.WorkspaceDirectory = System.IO.Path.Combine(outputParent, "workspace");
                    }

                    if (!isExplicitProfiles) {
                        options.ProfilesDirectory = System.IO.Path.Combine(outputParent, "profiles");
                    }
                }
            }

            return options;
        }

        /// <summary>
        /// Parses a comma-separated list of resolution names into a list of <see cref="MapResolutionLayer"/>.
        /// </summary>
        private static List<MapResolutionLayer> ParseResolutionLayerList(string resolutionCsv) {
            var parsedLayerList = new List<MapResolutionLayer>();
            if (string.IsNullOrWhiteSpace(resolutionCsv)) {
                return parsedLayerList;
            }

            string normalizedCsv = resolutionCsv.Trim().ToLowerInvariant();
            if (normalizedCsv == "all") {
                parsedLayerList.Add(MapResolutionLayer.Base);
                parsedLayerList.Add(MapResolutionLayer.Pedestrian);
                parsedLayerList.Add(MapResolutionLayer.Buildings);
                parsedLayerList.Add(MapResolutionLayer.Terrain);
                return parsedLayerList;
            }

            string[] tokenList = normalizedCsv.Split(',', StringSplitOptions.RemoveEmptyEntries);
            foreach (string rawToken in tokenList) {
                string token = rawToken.Trim();
                if ((token == "overview") || (token == "world")) {
                    parsedLayerList.Add(MapResolutionLayer.Overview);
                }else if ((token == "base") || (token == "driving") || (token == "transit")) {
                    parsedLayerList.Add(MapResolutionLayer.Base);
                }else if ((token == "pedestrian") || (token == "walk")) {
                    parsedLayerList.Add(MapResolutionLayer.Pedestrian);
                }else if ((token == "buildings") || (token == "buildings_3d") || (token == "3d")) {
                    parsedLayerList.Add(MapResolutionLayer.Buildings);
                }else if ((token == "terrain") || (token == "terrain_hd") || (token == "hd")) {
                    parsedLayerList.Add(MapResolutionLayer.Terrain);
                }
            }

            return parsedLayerList;
        }
    }
}
