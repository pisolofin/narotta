using System;
using System.Collections.Generic;
using System.IO;

namespace NaRotta.MapBuilder.Core.Services {
    /// <summary>
    /// Utility for resolving and provisioning builder asset paths (profiles schemas, tools, binaries) across local and containerized runtime environments.
    /// </summary>
    public static class MapBuilderPathHelper {
        /// <summary>
        /// Probes upwards from multiple reference locations to locate the directory containing Planetiler YAML schema profiles.
        /// </summary>
        public static string? FindProfilesDirectory(string? hintDirectory = null) {
            var candidateDirectoryList = new List<string>();

            if (!string.IsNullOrWhiteSpace(hintDirectory)) {
                candidateDirectoryList.Add(hintDirectory);
            }

            candidateDirectoryList.Add(AppContext.BaseDirectory);
            candidateDirectoryList.Add(Directory.GetCurrentDirectory());

            foreach (string baseDir in candidateDirectoryList) {
                string? probeDir = baseDir;
                for (int depth = 0; (depth < 7) && (!string.IsNullOrEmpty(probeDir)); depth++) {
                    string directProfiles = Path.Combine(probeDir, "profiles");
                    if (Directory.Exists(directProfiles) && File.Exists(Path.Combine(directProfiles, "driving-base-schema.yml"))) {
                        return Path.GetFullPath(directProfiles);
                    }

                    string subProfiles = Path.Combine(probeDir, "map-builder", "profiles");
                    if (Directory.Exists(subProfiles) && File.Exists(Path.Combine(subProfiles, "driving-base-schema.yml"))) {
                        return Path.GetFullPath(subProfiles);
                    }

                    DirectoryInfo? parentInfo = Directory.GetParent(probeDir);
                    probeDir = (parentInfo != null) ? parentInfo.FullName : null;
                }
            }

            return null;
        }

        /// <summary>
        /// Probes upwards from multiple reference locations to locate the directory containing builder tools such as planetiler.jar.
        /// </summary>
        public static string? FindToolsDirectory(string? hintDirectory = null) {
            var candidateDirectoryList = new List<string>();

            if (!string.IsNullOrWhiteSpace(hintDirectory)) {
                candidateDirectoryList.Add(hintDirectory);
            }

            candidateDirectoryList.Add(AppContext.BaseDirectory);
            candidateDirectoryList.Add(Directory.GetCurrentDirectory());

            foreach (string baseDir in candidateDirectoryList) {
                string? probeDir = baseDir;
                for (int depth = 0; (depth < 7) && (!string.IsNullOrEmpty(probeDir)); depth++) {
                    string directTools = Path.Combine(probeDir, "tools");
                    if (Directory.Exists(directTools) && File.Exists(Path.Combine(directTools, "planetiler.jar"))) {
                        return Path.GetFullPath(directTools);
                    }

                    string subTools = Path.Combine(probeDir, "map-builder", "tools");
                    if (Directory.Exists(subTools) && File.Exists(Path.Combine(subTools, "planetiler.jar"))) {
                        return Path.GetFullPath(subTools);
                    }

                    DirectoryInfo? parentInfo = Directory.GetParent(probeDir);
                    probeDir = (parentInfo != null) ? parentInfo.FullName : null;
                }
            }

            return null;
        }

        /// <summary>
        /// Ensures all schema profile files and configuration templates are copied into the target profiles directory if missing or outdated.
        /// </summary>
        public static void EnsureProfilesAvailable(string targetProfilesDirectory, string? sourceDirectory = null) {
            if (string.IsNullOrWhiteSpace(targetProfilesDirectory)) {
                return;
            }

            string? sourceProfiles = !string.IsNullOrWhiteSpace(sourceDirectory)
                ? sourceDirectory
                : FindProfilesDirectory();

            if (string.IsNullOrWhiteSpace(sourceProfiles) || (!Directory.Exists(sourceProfiles))) {
                return;
            }

            string fullTarget = Path.GetFullPath(targetProfilesDirectory);
            string fullSource = Path.GetFullPath(sourceProfiles);

            Directory.CreateDirectory(fullTarget);

            if (string.Equals(fullTarget, fullSource, StringComparison.OrdinalIgnoreCase)) {
                return;
            }

            string[] sourceFileList = Directory.GetFiles(fullSource);
            foreach (string sourceFilePath in sourceFileList) {
                string fileName = Path.GetFileName(sourceFilePath);
                string destinationFilePath = Path.Combine(fullTarget, fileName);
                if ((!File.Exists(destinationFilePath)) || (File.GetLastWriteTimeUtc(sourceFilePath) > File.GetLastWriteTimeUtc(destinationFilePath))) {
                    File.Copy(sourceFilePath, destinationFilePath, true);
                }
            }
        }
    }
}
