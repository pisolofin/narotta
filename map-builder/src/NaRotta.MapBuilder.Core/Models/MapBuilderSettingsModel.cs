namespace NaRotta.MapBuilder.Core.Models {
    /// <summary>
    /// Configuration model for storage paths, workspace caches, and artifact directories.
    /// </summary>
    public class MapBuilderSettingsModel {
        public string WorkspaceDirectory { get; set; } = string.Empty;
        public string OutputDirectory { get; set; } = string.Empty;
        public string ProfilesDirectory { get; set; } = string.Empty;
        public string ToolsDirectory { get; set; } = string.Empty;
        public string BaseUrl { get; set; } = "https://storage.narotta.app/maps/";
        public int? PlanetilerMaxHeapGigabytes { get; set; }

        public MapBuilderSettingsModel Clone() {
            var clone = new MapBuilderSettingsModel {
                WorkspaceDirectory = this.WorkspaceDirectory,
                OutputDirectory = this.OutputDirectory,
                ProfilesDirectory = this.ProfilesDirectory,
                ToolsDirectory = this.ToolsDirectory,
                BaseUrl = this.BaseUrl,
                PlanetilerMaxHeapGigabytes = this.PlanetilerMaxHeapGigabytes
            };
            return clone;
        }
    }

    /// <summary>
    /// Diagnostic report detailing the existence, write permissions, and disk capacity of a configured directory.
    /// </summary>
    public class DirectoryValidationModel {
        public string Path { get; set; } = string.Empty;
        public bool Exists { get; set; } = false;
        public bool IsWritable { get; set; } = false;
        public long? AvailableFreeSpaceBytes { get; set; }
        public long? TotalSpaceBytes { get; set; }
        public string? ErrorMessage { get; set; }
    }
}
