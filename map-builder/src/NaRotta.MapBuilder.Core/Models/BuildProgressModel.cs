using System;

namespace NaRotta.MapBuilder.Core.Models {
    /// <summary>
    /// Thread-safe snapshot of the current build progress, machine telemetry, and execution metrics.
    /// </summary>
    public class BuildProgressModel {
        public string JobId { get; set; } = string.Empty;
        public BuildJobStatus Status { get; set; } = BuildJobStatus.Idle;
        public string CommandName { get; set; } = string.Empty;
        public string ActiveRegionId { get; set; } = string.Empty;
        public string ActiveRegionName { get; set; } = string.Empty;
        public int CurrentRegionIndex { get; set; } = 0;
        public int TotalRegionCount { get; set; } = 0;
        public BuildStage CurrentStage { get; set; } = BuildStage.None;
        public string CurrentStageDescription { get; set; } = string.Empty;
        public double PercentCompleted { get; set; } = 0.0;
        public DateTime? StartedAtUtc { get; set; }
        public DateTime? FinishedAtUtc { get; set; }
        public string? ErrorMessage { get; set; }
        public string? LastLogLine { get; set; }
        public long TotalLogLineCount { get; set; } = 0;
        public TimeSpan? ElapsedDuration => this.StartedAtUtc.HasValue
            ? ((this.FinishedAtUtc ?? DateTime.UtcNow) - this.StartedAtUtc.Value)
            : null;

        /// <summary>
        /// Creates a deep clone snapshot of the progress model to prevent data races during serialization.
        /// </summary>
        public BuildProgressModel CloneSnapshot() {
            var snapshot = new BuildProgressModel {
                JobId = this.JobId,
                Status = this.Status,
                CommandName = this.CommandName,
                ActiveRegionId = this.ActiveRegionId,
                ActiveRegionName = this.ActiveRegionName,
                CurrentRegionIndex = this.CurrentRegionIndex,
                TotalRegionCount = this.TotalRegionCount,
                CurrentStage = this.CurrentStage,
                CurrentStageDescription = this.CurrentStageDescription,
                PercentCompleted = this.PercentCompleted,
                StartedAtUtc = this.StartedAtUtc,
                FinishedAtUtc = this.FinishedAtUtc,
                ErrorMessage = this.ErrorMessage,
                LastLogLine = this.LastLogLine,
                TotalLogLineCount = this.TotalLogLineCount
            };
            return snapshot;
        }
    }
}
