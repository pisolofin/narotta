using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Core.Runners;
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Services {
    /// <summary>
    /// Inspects the host system (Windows or Linux/Unix) to detect RAM, disk space, Java JVM, and Valhalla availability.
    /// </summary>
    public class HardwareProfilerService {
        private readonly IProcessRunner _processRunner;
        private readonly SemaphoreSlim _profileLock = new SemaphoreSlim(1, 1);
        private HardwareProfileModel? _cachedProfile;
        private DateTime _lastProfiledUtc = DateTime.MinValue;
        private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(10);

        public HardwareProfilerService(IProcessRunner processRunner) {
            _processRunner = processRunner;
        }

        /// <summary>
        /// Profiles the current hardware and installed tools asynchronously with in-memory caching.
        /// </summary>
        public async Task<HardwareProfileModel> ProfileSystemAsync(string targetDirectory, CancellationToken cancellationToken) {
            if ((_cachedProfile != null) && ((DateTime.UtcNow - _lastProfiledUtc) < CacheDuration)) {
                return new HardwareProfileModel {
                    OperatingSystemName = _cachedProfile.OperatingSystemName,
                    IsWindows = _cachedProfile.IsWindows,
                    IsLinux = _cachedProfile.IsLinux,
                    IsMacOs = _cachedProfile.IsMacOs,
                    CpuThreadCount = _cachedProfile.CpuThreadCount,
                    TotalRamMegabytes = _cachedProfile.TotalRamMegabytes,
                    AvailableDiskGigabytes = GetAvailableDiskGigabytes(targetDirectory),
                    RecommendedJvmHeapGigabytes = _cachedProfile.RecommendedJvmHeapGigabytes,
                    IsJavaAvailable = _cachedProfile.IsJavaAvailable,
                    JavaVersionText = _cachedProfile.JavaVersionText,
                    ValhallaMode = _cachedProfile.ValhallaMode
                };
            }

            await _profileLock.WaitAsync(cancellationToken);
            try {
                if ((_cachedProfile != null) && ((DateTime.UtcNow - _lastProfiledUtc) < CacheDuration)) {
                    return new HardwareProfileModel {
                        OperatingSystemName = _cachedProfile.OperatingSystemName,
                        IsWindows = _cachedProfile.IsWindows,
                        IsLinux = _cachedProfile.IsLinux,
                        IsMacOs = _cachedProfile.IsMacOs,
                        CpuThreadCount = _cachedProfile.CpuThreadCount,
                        TotalRamMegabytes = _cachedProfile.TotalRamMegabytes,
                        AvailableDiskGigabytes = GetAvailableDiskGigabytes(targetDirectory),
                        RecommendedJvmHeapGigabytes = _cachedProfile.RecommendedJvmHeapGigabytes,
                        IsJavaAvailable = _cachedProfile.IsJavaAvailable,
                        JavaVersionText = _cachedProfile.JavaVersionText,
                        ValhallaMode = _cachedProfile.ValhallaMode
                    };
                }

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

                // Check Java availability for Planetiler with a strict 3-second timeout
                try {
                    using var javaCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
                    javaCts.CancelAfter(TimeSpan.FromSeconds(3));
                    var javaArgumentList = new List<string> { "-version" };
                    ProcessExecutionResultModel javaResult = await _processRunner.ExecuteProcessAsync(
                        "java",
                        javaArgumentList,
                        Directory.GetCurrentDirectory(),
                        false,
                        javaCts.Token
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
                }catch (Exception) {
                    profile.IsJavaAvailable = false;
                    profile.JavaVersionText = "Not found";
                }

                // Detect Valhalla execution mode (Native on Linux/macOS, WSL2 or Docker on Windows) with strict timeouts
                profile.ValhallaMode = await DetectValhallaModeAsync(profile.IsWindows, cancellationToken);

                _cachedProfile = profile;
                _lastProfiledUtc = DateTime.UtcNow;

                return profile;
            }finally {
                _profileLock.Release();
            }
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
                try {
                    using var nativeCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
                    nativeCts.CancelAfter(TimeSpan.FromSeconds(2));
                    var nativeArgList = new List<string> { "--version" };
                    ProcessExecutionResultModel nativeResult = await _processRunner.ExecuteProcessAsync(
                        "valhalla_build_tiles",
                        nativeArgList,
                        Directory.GetCurrentDirectory(),
                        false,
                        nativeCts.Token
                    );

                    if (nativeResult.IsSuccess) {
                        return ValhallaExecutionMode.NativeUnix;
                    }
                }catch (Exception) {
                    // Ignore native probe errors
                }
            }

            if (isWindows) {
                try {
                    using var wslCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
                    wslCts.CancelAfter(TimeSpan.FromSeconds(2));
                    var wslArgList = new List<string> { "--", "which", "valhalla_build_tiles" };
                    ProcessExecutionResultModel wslResult = await _processRunner.ExecuteProcessAsync(
                        "wsl",
                        wslArgList,
                        Directory.GetCurrentDirectory(),
                        false,
                        wslCts.Token
                    );

                    if (wslResult.IsSuccess && (!string.IsNullOrWhiteSpace(wslResult.StandardOutput))) {
                        return ValhallaExecutionMode.Wsl2;
                    }
                }catch (Exception) {
                    // Ignore WSL probe timeout or execution errors
                }
            }

            try {
                using var dockerCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
                dockerCts.CancelAfter(TimeSpan.FromSeconds(2));
                var dockerArgList = new List<string> { "version", "--format", "{{.Server.Version}}" };
                ProcessExecutionResultModel dockerResult = await _processRunner.ExecuteProcessAsync(
                    "docker",
                    dockerArgList,
                    Directory.GetCurrentDirectory(),
                    false,
                    dockerCts.Token
                );

                if (dockerResult.IsSuccess) {
                    return ValhallaExecutionMode.Docker;
                }
            }catch (Exception) {
                // Ignore Docker probe timeout or execution errors
            }

            return ValhallaExecutionMode.CSharpNativeFallback;
        }
    }
}
