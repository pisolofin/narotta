using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Core.Services;
using System.IO;
using System.IO.Compression;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Integration tests for <see cref="OfflineAssetsService"/> ensuring valid zip and style json generation.
    /// </summary>
    public class OfflineAssetsServiceTests {
        [Fact]
        public async Task BuildOfflineAssetsPackageAsync_GeneratesValidArchiveAndStyles() {
            // Arrange
            string tempOutputDirectory = Path.Combine(Path.GetTempPath(), "narotta_test_assets_" + Path.GetRandomFileName());
            var options = new BuildOptionsModel {
                OutputDirectory = tempOutputDirectory
            };

            var service = new OfflineAssetsService();
            using var cancellationTokenSource = new CancellationTokenSource();

            try {
                // Act
                string outputZipPath = await service.BuildOfflineAssetsPackageAsync(options, cancellationTokenSource.Token);

                // Assert
                Assert.True(File.Exists(outputZipPath));
                Assert.True(new FileInfo(outputZipPath).Length > 0L);

                using (var zipArchive = ZipFile.OpenRead(outputZipPath)) {
                    ZipArchiveEntry? dayStyleEntry = zipArchive.GetEntry("styles/style-day.json");
                    ZipArchiveEntry? nightStyleEntry = zipArchive.GetEntry("styles/style-night.json");
                    ZipArchiveEntry? spriteEntry = zipArchive.GetEntry("sprites/sprite.json");
                    ZipArchiveEntry? glyphEntry = zipArchive.GetEntry("glyphs/manifest.json");

                    Assert.NotNull(dayStyleEntry);
                    Assert.NotNull(nightStyleEntry);
                    Assert.NotNull(spriteEntry);
                    Assert.NotNull(glyphEntry);

                    // Verify style-day.json is valid JSON and contains required sources
                    using (Stream dayStream = dayStyleEntry.Open())
                    using (var reader = new StreamReader(dayStream)) {
                        string dayJsonText = await reader.ReadToEndAsync();
                        using JsonDocument dayDoc = JsonDocument.Parse(dayJsonText);
                        Assert.True(dayDoc.RootElement.TryGetProperty("sources", out JsonElement sourcesElement));
                        Assert.True(sourcesElement.TryGetProperty("overview_source", out _));
                        Assert.True(sourcesElement.TryGetProperty("base_source", out _));
                        Assert.True(sourcesElement.TryGetProperty("pedestrian_source", out _));
                        Assert.True(sourcesElement.TryGetProperty("buildings_source", out _));
                        Assert.True(sourcesElement.TryGetProperty("terrain_source", out _));
                    }
                }
            }finally {
                if (Directory.Exists(tempOutputDirectory)) {
                    Directory.Delete(tempOutputDirectory, true);
                }
            }
        }
    }
}
