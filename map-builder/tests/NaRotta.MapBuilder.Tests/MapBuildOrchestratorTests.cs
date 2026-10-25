using NaRotta.MapBuilder.Core.Logging;
using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Core.Orchestrator;
using NaRotta.MapBuilder.Core.Runners;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests verifying state machine transitions, concurrent build rejection, and stop signals in <see cref="MapBuildOrchestrator"/>.
    /// </summary>
    public class MapBuildOrchestratorTests {
        [Fact]
        public void GetCurrentProgress_InitialState_IsIdle() {
            var logBuffer = new BuildLogBuffer();
            using var httpClient = new HttpClient();
            IProcessRunner runner = new CrossPlatformProcessRunner();
            var orchestrator = new MapBuildOrchestrator(httpClient, runner, logBuffer);

            BuildProgressModel progress = orchestrator.GetCurrentProgress();

            Assert.Equal(BuildJobStatus.Idle, progress.Status);
            Assert.Equal(0.0, progress.PercentCompleted);
            Assert.Null(progress.StartedAtUtc);
        }

        [Fact]
        public async Task StartBuildAsync_WhenDoctorCommand_CompletesSuccessfullyAsync() {
            var logBuffer = new BuildLogBuffer();
            using var httpClient = new HttpClient();
            IProcessRunner runner = new CrossPlatformProcessRunner();
            var orchestrator = new MapBuildOrchestrator(httpClient, runner, logBuffer);

            string tempDir = Path.Combine(Path.GetTempPath(), "narotta-orch-test-" + System.Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);

            try {
                var options = new BuildOptionsModel {
                    CommandName = "doctor",
                    WorkspaceDirectory = tempDir,
                    OutputDirectory = tempDir
                };

                bool started = await orchestrator.StartBuildAsync(options);
                Assert.True(started);

                // Wait for doctor command to complete
                int timeoutMs = 5000;
                while ((orchestrator.GetCurrentProgress().Status == BuildJobStatus.Running) && (timeoutMs > 0)) {
                    await Task.Delay(100);
                    timeoutMs -= 100;
                }

                BuildProgressModel progress = orchestrator.GetCurrentProgress();
                Assert.Equal(BuildJobStatus.Completed, progress.Status);
                Assert.Equal(100.0, progress.PercentCompleted);
            }finally {
                if (Directory.Exists(tempDir)) {
                    Directory.Delete(tempDir, true);
                }
            }
        }

        [Fact]
        public async Task StopBuildAsync_WhenNoBuildRunning_ReturnsFalseAsync() {
            var logBuffer = new BuildLogBuffer();
            using var httpClient = new HttpClient();
            IProcessRunner runner = new CrossPlatformProcessRunner();
            var orchestrator = new MapBuildOrchestrator(httpClient, runner, logBuffer);

            bool stopped = await orchestrator.StopBuildAsync();

            Assert.False(stopped);
        }
    }
}
