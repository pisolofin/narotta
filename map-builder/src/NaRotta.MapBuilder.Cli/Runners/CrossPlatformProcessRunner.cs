using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Cli.Runners {
    /// <summary>
    /// Cross-platform process runner supporting native Windows/Linux processes, WSL2 bridges, and Docker containers.
    /// </summary>
    public class CrossPlatformProcessRunner : IProcessRunner {
        /// <summary>
        /// Executes an external process asynchronously and captures or streams its output.
        /// </summary>
        public async Task<ProcessExecutionResultModel> ExecuteProcessAsync(
            string executableName,
            List<string> argumentList,
            string workingDirectory,
            bool streamToConsole,
            CancellationToken cancellationToken
        ) {
            var result = new ProcessExecutionResultModel {
                ExitCode = -1
            };

            var startInfo = new ProcessStartInfo {
                FileName = executableName,
                WorkingDirectory = string.IsNullOrWhiteSpace(workingDirectory) ? Directory.GetCurrentDirectory() : workingDirectory,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            if (argumentList != null) {
                foreach (string argumentItem in argumentList) {
                    startInfo.ArgumentList.Add(argumentItem);
                }
            }

            var outputBuilder = new StringBuilder();
            var errorBuilder = new StringBuilder();

            try {
                using var process = new Process {
                    StartInfo = startInfo
                };

                process.OutputDataReceived += (object sender, DataReceivedEventArgs eventArgs) => {
                    if (eventArgs.Data != null) {
                        outputBuilder.AppendLine(eventArgs.Data);
                        if (streamToConsole) {
                            Console.WriteLine(eventArgs.Data);
                        }
                    }
                };

                process.ErrorDataReceived += (object sender, DataReceivedEventArgs eventArgs) => {
                    if (eventArgs.Data != null) {
                        errorBuilder.AppendLine(eventArgs.Data);
                        if (streamToConsole) {
                            Console.WriteLine(eventArgs.Data);
                        }
                    }
                };

                bool isStarted = process.Start();
                if (!isStarted) {
                    result.StandardError = "Failed to start process: " + executableName;
                    return result;
                }

                process.BeginOutputReadLine();
                process.BeginErrorReadLine();

                await process.WaitForExitAsync(cancellationToken);

                result.ExitCode = process.ExitCode;
                result.StandardOutput = outputBuilder.ToString();
                result.StandardError = errorBuilder.ToString();
            }catch (Exception exception) {
                result.ExitCode = -1;
                result.StandardError = exception.Message;
            }

            return result;
        }

        /// <summary>
        /// Converts a Windows drive path (e.g. "C:\Users\Fabio\work") into a WSL2 path ("/mnt/c/Users/Fabio/work").
        /// </summary>
        public string ConvertHostPathToWslPath(string hostPath) {
            if (string.IsNullOrWhiteSpace(hostPath)) {
                return string.Empty;
            }

            string fullPath = Path.GetFullPath(hostPath);
            string normalizedSlashes = fullPath.Replace('\\', '/');

            if ((normalizedSlashes.Length >= 2) && (normalizedSlashes[1] == ':')) {
                char driveLetter = char.ToLowerInvariant(normalizedSlashes[0]);
                string remainingPath = normalizedSlashes.Substring(2);
                return "/mnt/" + driveLetter + remainingPath;
            }

            return normalizedSlashes;
        }
    }
}
