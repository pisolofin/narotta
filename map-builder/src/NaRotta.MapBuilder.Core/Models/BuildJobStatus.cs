namespace NaRotta.MapBuilder.Core.Models {
    /// <summary>
    /// Represents the high-level execution status of a map generation job.
    /// </summary>
    public enum BuildJobStatus {
        Idle,
        Running,
        Cancelling,
        Completed,
        Failed,
        Cancelled
    }

    /// <summary>
    /// Represents the discrete lifecycle stages of the map build pipeline.
    /// </summary>
    public enum BuildStage {
        None,
        Initializing,
        DoctorDiagnostics,
        DownloadingPbf,
        DownloadingElevation,
        BuildingOverviewTiles,
        BuildingTilesBase,
        BuildingTilesPedestrian,
        BuildingTilesBuildings,
        BuildingTilesTerrain,
        SlicingGeoCells,
        SplittingSubregions,
        BuildingRoutingGraph,
        PackagingRoutingTar,
        BuildingSearchDatabase,
        BuildingOfflineAssets,
        UpdatingManifest,
        CleaningWorkspace
    }
}
