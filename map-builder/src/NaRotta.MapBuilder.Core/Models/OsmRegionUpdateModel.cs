using System;

namespace NaRotta.MapBuilder.Core.Models {
    /// <summary>
    /// Status indicating whether local map assets match upstream OpenStreetMap/Geofabrik releases.
    /// </summary>
    public enum OsmUpdateStatus {
        Unknown,
        Checking,
        UpToDate,
        UpdateAvailable,
        NotBuiltYet,
        CheckFailed
    }

    /// <summary>
    /// Information model comparing the upstream Geofabrik release against local generated map packages.
    /// </summary>
    public class OsmRegionUpdateModel {
        public string RegionId { get; set; } = string.Empty;
        public string RegionName { get; set; } = string.Empty;
        public string ParentId { get; set; } = string.Empty;
        public string RemotePbfUrl { get; set; } = string.Empty;
        public DateTime? RemoteLastModifiedUtc { get; set; }
        public long? RemoteSizeBytes { get; set; }
        public string? RemoteMd5Hash { get; set; }
        public DateTime? LocalLastBuiltUtc { get; set; }
        public long? LocalTotalSizeBytes { get; set; }
        public OsmUpdateStatus Status { get; set; } = OsmUpdateStatus.Unknown;
        public string StatusMessage { get; set; } = string.Empty;
        public bool HasUpdate => this.Status == OsmUpdateStatus.UpdateAvailable;
    }
}
