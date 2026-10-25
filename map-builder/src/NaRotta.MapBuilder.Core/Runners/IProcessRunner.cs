using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Runners {
    /// <summary>
    /// Represents the execution result of an external command-line process.
    /// </summary>
    public class ProcessExecutionResultModel {
        public int ExitCode { get; set; }
        public string StandardOutput { get; set; } = string.Empty;
        public string StandardError { get; set; } = string.Empty;
        public bool IsSuccess => (this.ExitCode == 0);
    }

    /// <summary>
    /// Abstraction for running external tools (Java/Planetiler, Valhalla, WSL2, Docker) across Windows and Unix.
    /// </summary>
    public interface IProcessRunner {
        /// <summary>
        /// Executes an external process asynchronously and optionally streams output to the console.
        /// </summary>
        Task<ProcessExecutionResultModel> ExecuteProcessAsync(
            string executableName,
            List<string> argumentList,
            string workingDirectory,
            bool streamToConsole,
            CancellationToken cancellationToken
        );

        /// <summary>
        /// Converts a local host path into a WSL2 mount path (e.g. "C:\work\file.pbf" -> "/mnt/c/work/file.pbf").
        /// </summary>
        string ConvertHostPathToWslPath(string hostPath);
    }
}
