using Microsoft.Extensions.Configuration;
using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Web.Services;
using System.Collections.Generic;
using System.IO;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests verifying configuration loading, path resolution, and directory validation in <see cref="MapBuilderConfigService"/>.
    /// </summary>
    public class MapBuilderConfigServiceTests {
        [Fact]
        public void GetSettings_WhenConfigurationProvided_ResolvesCustomPaths() {
            var inMemorySettings = new Dictionary<string, string?> {
                ["MapBuilder:WorkspaceDirectory"] = "C:\\custom-workspace",
                ["MapBuilder:OutputDirectory"] = "C:\\custom-output",
                ["MapBuilder:BaseUrl"] = "https://cdn.example.com/maps/"
            };

            IConfiguration configuration = new ConfigurationBuilder()
                .AddInMemoryCollection(inMemorySettings)
                .Build();

            var service = new MapBuilderConfigService(configuration);
            MapBuilderSettingsModel settings = service.GetSettings();

            Assert.Equal("C:\\custom-workspace", settings.WorkspaceDirectory);
            Assert.Equal("C:\\custom-output", settings.OutputDirectory);
            Assert.Equal("https://cdn.example.com/maps/", settings.BaseUrl);
        }

        [Fact]
        public void ValidateDirectory_WhenPathValid_ReportsExistingAndWritable() {
            IConfiguration configuration = new ConfigurationBuilder().Build();
            var service = new MapBuilderConfigService(configuration);

            string tempDir = Path.Combine(Path.GetTempPath(), "narotta-cfg-test-" + System.Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);

            try {
                DirectoryValidationModel validation = service.ValidateDirectory(tempDir);
                Assert.True(validation.Exists);
                Assert.True(validation.IsWritable);
                Assert.Null(validation.ErrorMessage);
            }finally {
                if (Directory.Exists(tempDir)) {
                    Directory.Delete(tempDir, true);
                }
            }
        }

        [Fact]
        public void UpdateSettings_WhenPersistTrue_WritesToContentRootAndBaseDir() {
            string tempDir = Path.Combine(Path.GetTempPath(), "narotta-cfg-persist-" + System.Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);

            try {
                var inMemorySettings = new Dictionary<string, string?> {
                    ["MapBuilder:WorkspaceDirectory"] = "C:\\initial-workspace",
                    ["MapBuilder:OutputDirectory"] = "C:\\initial-output"
                };
                IConfiguration configuration = new ConfigurationBuilder()
                    .AddInMemoryCollection(inMemorySettings)
                    .Build();

                var service = new MapBuilderConfigService(configuration, tempDir);
                var newSettings = new MapBuilderSettingsModel {
                    WorkspaceDirectory = "C:\\persisted-workspace",
                    OutputDirectory = "C:\\persisted-output",
                    ProfilesDirectory = "C:\\persisted-profiles",
                    ToolsDirectory = "C:\\persisted-tools",
                    BaseUrl = "https://persisted.example.com/"
                };

                bool updated = service.UpdateSettings(newSettings, true, out string? errorMessage);
                Assert.True(updated);
                Assert.Null(errorMessage);

                string savedFilePath = Path.Combine(tempDir, "appsettings.Local.json");
                Assert.True(File.Exists(savedFilePath));
                string fileContent = File.ReadAllText(savedFilePath);
                Assert.Contains("persisted-workspace", fileContent);
                Assert.Contains("persisted-output", fileContent);

                string workspaceSettingsFile = Path.Combine("C:\\persisted-workspace", "mapbuilder.settings.json");
                // Cleans up if created
                if (File.Exists(workspaceSettingsFile)) {
                    File.Delete(workspaceSettingsFile);
                }
            }finally {
                if (Directory.Exists(tempDir)) {
                    Directory.Delete(tempDir, true);
                }
            }
        }
    }
}
