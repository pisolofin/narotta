using NaRotta.MapBuilder.Core.Models;
using System.Collections.Generic;

namespace NaRotta.MapBuilder.Web.Models {
    /// <summary>
    /// Payload submitted by the web dashboard to start a new map generation build.
    /// </summary>
    public class StartBuildRequestModel {
        public string CommandName { get; set; } = "build";
        public string RegionId { get; set; } = "europe/italy/trentino-alto-adige";
        public bool SplitSubregions { get; set; } = false;
        public bool SliceGeoCells { get; set; } = false;
        public bool ResumeBatch { get; set; } = false;
        public bool CleanWorkspaceAfterBuild { get; set; } = false;
        public bool IncludeElevation { get; set; } = true;
        public bool SkipRouting { get; set; } = false;
        public bool SkipTiles { get; set; } = false;
        public bool SkipSearch { get; set; } = false;
        public bool ForceDownload { get; set; } = false;
        public string? CustomWorkspaceDirectory { get; set; }
        public string? CustomOutputDirectory { get; set; }
        public List<string> LayerNameList { get; set; } = new List<string> {
            "Base",
            "Pedestrian",
            "Buildings",
            "Terrain"
        };

        /// <summary>
        /// Converts the web request into a typed <see cref="BuildOptionsModel"/>.
        /// </summary>
        public BuildOptionsModel ToBuildOptions(string baseWorkspace, string baseOutput, string baseProfiles, string baseTools, string baseUrl) {
            string effectiveWorkspace = !string.IsNullOrWhiteSpace(this.CustomWorkspaceDirectory) ? this.CustomWorkspaceDirectory.Trim() : baseWorkspace;
            string effectiveOutput = !string.IsNullOrWhiteSpace(this.CustomOutputDirectory) ? this.CustomOutputDirectory.Trim() : baseOutput;

            var options = new BuildOptionsModel {
                CommandName = this.CommandName.Trim().ToLowerInvariant(),
                RegionId = this.RegionId.Trim(),
                WorkspaceDirectory = effectiveWorkspace,
                OutputDirectory = effectiveOutput,
                ProfilesDirectory = baseProfiles,
                ToolsDirectory = baseTools,
                BaseUrl = baseUrl,
                SplitSubregions = this.SplitSubregions,
                SliceGeoCells = this.SliceGeoCells,
                ResumeBatch = this.ResumeBatch,
                CleanWorkspaceAfterBuild = this.CleanWorkspaceAfterBuild,
                IncludeElevation = this.IncludeElevation,
                SkipRouting = this.SkipRouting,
                SkipTiles = this.SkipTiles,
                SkipSearch = this.SkipSearch,
                ForceDownload = this.ForceDownload,
                ResolutionLayerList = new List<MapResolutionLayer>()
            };

            if (options.CommandName == "build-world") {
                options.SplitSubregions = true;
                options.SliceGeoCells = true;
                options.CleanWorkspaceAfterBuild = true;
                options.ResumeBatch = true;
            }

            foreach (string layerName in this.LayerNameList) {
                switch (layerName.Trim().ToLowerInvariant()) {
                    case "overview":
                        options.ResolutionLayerList.Add(MapResolutionLayer.Overview);
                        break;
                    case "base":
                        options.ResolutionLayerList.Add(MapResolutionLayer.Base);
                        break;
                    case "pedestrian":
                        options.ResolutionLayerList.Add(MapResolutionLayer.Pedestrian);
                        break;
                    case "buildings":
                        options.ResolutionLayerList.Add(MapResolutionLayer.Buildings);
                        break;
                    case "terrain":
                        options.ResolutionLayerList.Add(MapResolutionLayer.Terrain);
                        break;
                }
            }

            if (options.ResolutionLayerList.Count == 0) {
                options.ResolutionLayerList.Add(MapResolutionLayer.Base);
                options.ResolutionLayerList.Add(MapResolutionLayer.Pedestrian);
                options.ResolutionLayerList.Add(MapResolutionLayer.Buildings);
                options.ResolutionLayerList.Add(MapResolutionLayer.Terrain);
            }

            return options;
        }
    }
}
