using NaRotta.MapBuilder.Cli.Models;
using NaRotta.MapBuilder.Cli.Runners;
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Cli.Services {
    /// <summary>
    /// Inspects the host system (Windows or Linux/Unix) to detect RAM, disk space, Java JVM, and Valhalla availability.
    /// </summary>
    public class HardwareProfilerService {
        private readonly IProcessRunner _processRunner;

        public HardwareProfilerService(IProcessRunner processRunner) {
            _processRunner = processRunner;
        }

        /// <summary>
        /// Profiles the current hardware and installed tools asynchronously.
        /// </summary>
        public async Task<HardwareProfileModel> ProfileSystemAsync(string targetDirectory, CancellationToken cancellationToken) {
            var profile = new HardwareProfileModel {
                OperatingSystemName = RuntimeInformation.OSDescription,
                IsWindows = RuntimeInformation.IsOSPlatform(OSPlatform.Windows),
                IsLinux = RuntimeInformation.IsOSPlatform(OSPlatform.Linux),
                IsMacOs = RuntimeInformation.IsOSPlatform(OSPlatform.OSX),
                CpuThreadCount = Environment.ProcessorCount
            };

            // Detect total physical memory using GC memory info
            GCMemoryInfo gcMemoryInfo = GC.GetGCMemoryInfo();
            long totalMemoryBytes = gcMemoryInfo.TotalAvailableMemoryBytes;
            if (totalMemoryBytes <= 0L) {
                totalMemoryBytes = 8L * 1024L * 1024L * 1024L;
            }
            profile.TotalRamMegabytes = totalMemoryBytes / (1024L * 1024L);

            // Compute recommended JVM heap (approx 65% of physical RAM, clamped between 2 GB and 48 GB)
            int recommendedHeapGb = (int)((profile.TotalRamMegabytes * 65L) / (100L * 1024L));
            if (recommendedHeapGb < 2) {
                recommendedHeapGb = 2;
            }
            if (recommendedHeapGb > 48) {
                recommendedHeapGb = 48;
            }
            profile.RecommendedJvmHeapGigabytes = recommendedHeapGb;

            // Detect available free disk space on the target drive
            profile.AvailableDiskGigabytes = GetAvailableDiskGigabytes(targetDirectory);

            // Check Java availability for Planetiler
            var javaArgumentList = new List<string> { "-version" };
            ProcessExecutionResultModel javaResult = await _processRunner.ExecuteProcessAsync(
                "java",
                javaArgumentList,
                Directory.GetCurrentDirectory(),
                false,
                cancellationToken
            );

            if (javaResult.IsSuccess) {
                profile.IsJavaAvailable = true;
                string rawVersionOutput = !string.IsNullOrWhiteSpace(javaResult.StandardError)
                    ? javaResult.StandardError
                    : javaResult.StandardOutput;
                string[] lineList = rawVersionOutput.Split(new char[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
                profile.JavaVersionText = (lineList.Length > 0) ? lineList[0].Trim() : "Java installed";
            }else {
                profile.IsJavaAvailable = false;
                profile.JavaVersionText = "Not found";
            }

            // Detect Valhalla execution mode (Native on Linux/macOS, WSL2 or Docker on Windows)
            profile.ValhallaMode = await DetectValhallaModeAsync(profile.IsWindows, cancellationToken);

            return profile;
        }

        /// <summary>
        /// Determines the available free space in gigabytes for the directory path.
        /// </summary>
        private long GetAvailableDiskGigabytes(string targetDirectory) {
            try {
                string fullPath = Path.GetFullPath(string.IsNullOrWhiteSpace(targetDirectory) ? Directory.GetCurrentDirectory() : targetDirectory);
                string? rootPath = Path.GetPathRoot(fullPath);
                if (!string.IsNullOrWhiteSpace(rootPath)) {
                    var driveInfo = new DriveInfo(rootPath);
                    if (driveInfo.IsReady) {
                        return driveInfo.AvailableFreeSpace / (1024L * 1024L * 1024L);
                    }
                }
            }catch (Exception) {
                // Ignore drive inspection errors on virtual/network mounts
            }
            return 0L;
        }

        /// <summary>
        /// Probes for native Valhalla tools, WSL2 Valhalla installation, or Docker availability.
        /// </summary>
        private async Task<ValhallaExecutionMode> DetectValhallaModeAsync(bool isWindows, CancellationToken cancellationToken) {
            if (!isWindows) {
                var nativeArgList = new List<string> { "--version" };
                ProcessExecutionResultModel nativeResult = await _processRunner.ExecuteProcessAsync(
                    "valhalla_build_tiles",
                    nativeArgList,
                    Directory.GetCurrentDirectory(),
                    false,
                    cancellationToken
                );

                if (nativeResult.IsSuccess) {
                    return ValhallaExecutionMode.NativeUnix;
                }
            }

            if (isWindows) {
                var wslArgList = new List<string> { "--", "which", "valhalla_build_tiles" };
                ProcessExecutionResultModel wslResult = await _processRunner.ExecuteProcessAsync(
                    "wsl",
                    wslArgList,
                    Directory.GetCurrentDirectory(),
                    false,
                    cancellationToken
                );

                if (wslResult.IsSuccess && !string.IsNullOrWhiteSpace(wslResult.StandardOutput)) {
                    return ValhallaExecutionMode.Wsl2;
                }
            }

            var dockerArgList = new List<string> { "version", "--format", "{{.Server.Version}}" };
            ProcessExecutionResultModel dockerResult = await _processRunner.ExecuteProcessAsync(
                "docker",
                dockerArgList,
                Directory.GetCurrentDirectory(),
                false,
                cancellationToken
            );

            if (dockerResult.IsSuccess) {
                return ValhallaExecutionMode.Docker;
            }

            return ValhallaExecutionMode.CSharpNativeFallback;
        }
    }
}
