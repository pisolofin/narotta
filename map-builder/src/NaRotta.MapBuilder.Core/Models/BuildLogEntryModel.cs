using System;

namespace NaRotta.MapBuilder.Core.Models {
    /// <summary>
    /// Represents an individual structured log line produced by the map builder engine.
    /// </summary>
    public class BuildLogEntryModel {
        public long SequenceNumber { get; set; }
        public DateTime TimestampUtc { get; set; } = DateTime.UtcNow;
        public string Level { get; set; } = "INFO";
        public string Message { get; set; } = string.Empty;
        public string? RegionId { get; set; }
        public string? StageName { get; set; }

        public BuildLogEntryModel() {
        }

        public BuildLogEntryModel(long sequenceNumber, string level, string message, string? regionId, string? stageName) {
            this.SequenceNumber = sequenceNumber;
            this.TimestampUtc = DateTime.UtcNow;
            this.Level = level;
            this.Message = message;
            this.RegionId = regionId;
            this.StageName = stageName;
        }
    }
}
