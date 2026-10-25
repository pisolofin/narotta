namespace NaRotta.MapBuilder.Cli.Models {
    /// <summary>
    /// Execution strategy for invoking Valhalla C++ build tools across Windows and Unix platforms.
    /// </summary>
    public enum ValhallaExecutionMode {
        CSharpNativeFallback,
        NativeUnix,
        Wsl2,
        Docker
    }

    /// <summary>
    /// Holds detected hardware metrics and optimal tool parameters to prevent OutOfMemory crashes during map conversion.
    /// </summary>
    public class HardwareProfileModel {
        public string OperatingSystemName { get; set; } = string.Empty;
        public bool IsWindows { get; set; }
        public bool IsLinux { get; set; }
        public bool IsMacOs { get; set; }
        public int CpuThreadCount { get; set; }
        public long TotalRamMegabytes { get; set; }
        public long AvailableDiskGigabytes { get; set; }
        public int RecommendedJvmHeapGigabytes { get; set; }
        public bool IsJavaAvailable { get; set; }
        public string JavaVersionText { get; set; } = string.Empty;
        public ValhallaExecutionMode ValhallaMode { get; set; } = ValhallaExecutionMode.CSharpNativeFallback;

        /// <summary>
        /// Determines the optimal Planetiler nodemap type ("sparsearray" for safe memory efficiency, "array" only for tiny PBF extracts under 100 MB).
        /// </summary>
        public string GetPlanetilerNodeMapType(long pbfSizeBytes) {
            long pbfSizeMegabytes = pbfSizeBytes / (1024L * 1024L);
            // Array node map pre-allocates up to 76 GB heap for entire OSM node ID address space.
            // Always use sparsearray for any regional PBF > 100 MB or when JVM heap cannot hold 76 GB.
            if ((pbfSizeMegabytes > 100L) || (this.RecommendedJvmHeapGigabytes < 76)) {
                return "sparsearray";
            }
            return "array";
        }

        /// <summary>
        /// Determines the optimal Planetiler storage backend ("ram" vs "mmap" on SSD).
        /// </summary>
        public string GetPlanetilerStorageMode(long pbfSizeBytes) {
            long pbfSizeMegabytes = pbfSizeBytes / (1024L * 1024L);
            // Use memory-mapped SSD files when PBF is larger than 800 MB or total RAM is under 24 GB
            if ((pbfSizeMegabytes > 800L) || (this.TotalRamMegabytes < 24000L)) {
                return "mmap";
            }
            return "ram";
        }
    }
}
