using NaRotta.MapBuilder.Core.Logging;
using NaRotta.MapBuilder.Core.Models;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Orchestrator {
    /// <summary>
    /// High-level orchestrator interface for managing the background lifecycle of offline map builds.
    /// </summary>
    public interface IMapBuildOrchestrator {
        /// <summary>
        /// Gets the real-time progress model and machine telemetry snapshot.
        /// </summary>
        BuildProgressModel GetCurrentProgress();

        /// <summary>
        /// Initiates a background build job using the supplied options.
        /// </summary>
        Task<bool> StartBuildAsync(BuildOptionsModel options);

        /// <summary>
        /// Requests cancellation of the currently active build job.
        /// </summary>
        Task<bool> StopBuildAsync();

        /// <summary>
        /// In-memory ring buffer holding current and past logs.
        /// </summary>
        BuildLogBuffer LogBuffer { get; }

        /// <summary>
        /// Gathers the hardware profile and system tool diagnostics.
        /// </summary>
        Task<HardwareProfileModel> GetHardwareProfileAsync(string workspaceDirectory, CancellationToken cancellationToken);

        /// <summary>
        /// Loads the complete Geofabrik regional catalog.
        /// </summary>
        Task<List<GeofabrikRegionModel>> GetCatalogAsync(string workspaceDirectory, bool forceRefresh, CancellationToken cancellationToken);

        /// <summary>
        /// Reads the current manifest.json from the configured output directory.
        /// </summary>
        Task<ManifestRootModel?> GetCurrentManifestAsync(string outputDirectory, CancellationToken cancellationToken);
    }
}
