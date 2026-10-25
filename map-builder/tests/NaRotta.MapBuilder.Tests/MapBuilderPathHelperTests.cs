using NaRotta.MapBuilder.Core.Services;
using System;
using System.IO;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests verifying discovery and deployment of schema profile and tool files.
    /// </summary>
    public class MapBuilderPathHelperTests {
        [Fact]
        public void FindProfilesDirectory_LocatesMapBuilderProfiles() {
            string? profilesDir = MapBuilderPathHelper.FindProfilesDirectory();

            Assert.NotNull(profilesDir);
            Assert.True(Directory.Exists(profilesDir));
            Assert.True(File.Exists(Path.Combine(profilesDir, "driving-base-schema.yml")));
            Assert.True(File.Exists(Path.Combine(profilesDir, "valhalla-config.template.json")));
        }

        [Fact]
        public void EnsureProfilesAvailable_CopiesFilesToTargetDirectory() {
            string tempDir = Path.Combine(Path.GetTempPath(), "narotta-profiles-test-" + Guid.NewGuid().ToString("N"));

            try {
                MapBuilderPathHelper.EnsureProfilesAvailable(tempDir);

                Assert.True(Directory.Exists(tempDir));
                Assert.True(File.Exists(Path.Combine(tempDir, "driving-base-schema.yml")));
                Assert.True(File.Exists(Path.Combine(tempDir, "overview-schema.yml")));
                Assert.True(File.Exists(Path.Combine(tempDir, "valhalla-config.template.json")));
            }finally {
                if (Directory.Exists(tempDir)) {
                    Directory.Delete(tempDir, true);
                }
            }
        }
    }
}
