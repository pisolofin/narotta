using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Core.Services;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests verifying manifest.json v2.2 serialization format, including region cell_ids and modular Geo-Cells.
    /// </summary>
    public class ManifestSerializationTests {
        [Fact]
        public void ManifestRootModel_Serialization_ProducesExpectedJsonStructure() {
            // Arrange
            var manifest = new ManifestRootModel {
                SchemaVersion = "2.2",
                GeneratedAt = "2026-10-18T17:00:00Z",
                BaseUrl = "https://storage.narotta.app/maps/",
                CellSizeDegrees = 0.5,
                Overview = new ManifestOverviewModel {
                    Filename = "overview/world_overview.mbtiles",
                    MinZoom = 0,
                    MaxZoom = 7,
                    SizeBytes = 41943040L,
                    Sha256 = "abc123overview"
                },
                Assets = new ManifestAssetsModel {
                    Filename = "assets/map_assets.zip",
                    Version = "20261018",
                    SizeBytes = 6291456L,
                    Sha256 = "def456assets"
                }
            };

            var region = new ManifestRegionModel {
                Id = "europe/italy/trentino-alto-adige",
                ParentId = "europe/italy",
                CountryCode = "IT",
                Name = "Trentino-Alto Adige",
                Version = "20261018",
                BoundingBoxList = new List<double> { 10.4, 45.6, 12.5, 47.1 },
                CellIdList = new List<string> { "N45_50_E010_50", "N46_00_E011_00" },
                Search = new ManifestSearchModel {
                    Filename = "regions/europe/italy/trentino-alto-adige/trentino-alto-adige_search.db",
                    SizeBytes = 15000000L,
                    Sha256 = "searchhash123"
                }
            };

            region.Layers["transit_and_driving"] = new ManifestLayerModel {
                Description = "Roads",
                MinZoom = 8,
                MaxZoom = 14,
                TilesFilename = "tiles_base.mbtiles",
                TilesSizeBytes = 50000000L,
                TilesSha256 = "basehash",
                RoutingFilename = "routing_auto.tar",
                RoutingSizeBytes = 20000000L,
                RoutingSha256 = "routinghash"
            };

            manifest.RegionList.Add(region);

            var cellItem = new ManifestCellModel {
                CellId = "N45_50_E010_50",
                BoundingBoxList = new List<double> { 10.5, 45.5, 11.0, 46.0 }
            };
            cellItem.Layers["transit_and_driving"] = new ManifestLayerModel {
                Description = "Cell driving network (Z8-14)",
                MinZoom = 8,
                MaxZoom = 14,
                TilesFilename = "cells/N45_50_E010_50/N45_50_E010_50_tiles_base.mbtiles",
                TilesSizeBytes = 8388608L,
                TilesSha256 = "cellbasehash"
            };
            manifest.CellList.Add(cellItem);

            // Act
            string jsonText = JsonSerializer.Serialize(manifest, new JsonSerializerOptions { WriteIndented = true });

            // Assert
            Assert.Contains("\"schema_version\": \"2.2\"", jsonText);
            Assert.Contains("\"cell_size_degrees\": 0.5", jsonText);
            Assert.Contains("\"base_url\": \"https://storage.narotta.app/maps/\"", jsonText);
            Assert.Contains("\"overview\"", jsonText);
            Assert.Contains("\"overview/world_overview.mbtiles\"", jsonText);
            Assert.Contains("\"assets\"", jsonText);
            Assert.Contains("\"assets/map_assets.zip\"", jsonText);
            Assert.Contains("\"cell_ids\"", jsonText);
            Assert.Contains("\"N45_50_E010_50\"", jsonText);
            Assert.Contains("\"cells\"", jsonText);

            // Round-trip deserialization verification
            ManifestRootModel? deserialized = JsonSerializer.Deserialize<ManifestRootModel>(jsonText);
            Assert.NotNull(deserialized);
            Assert.Equal("2.2", deserialized.SchemaVersion);
            Assert.Equal(0.5, deserialized.CellSizeDegrees);
            Assert.Single(deserialized.RegionList);
            Assert.Equal(2, deserialized.RegionList[0].CellIdList.Count);
            Assert.Single(deserialized.CellList);
            Assert.Equal("N45_50_E010_50", deserialized.CellList[0].CellId);
        }

        [Fact]
        public async Task ManifestGeneratorService_UpdateManifestAsync_CachesSha256AndUpdatesIncrementally() {
            // Arrange
            string tempDirectory = Path.Combine(Path.GetTempPath(), "narotta_manifest_test_" + System.Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDirectory);

            try {
                var options = new BuildOptionsModel {
                    OutputDirectory = tempDirectory,
                    BaseUrl = "https://example.com/tiles/"
                };

                // Create a mock cell directory with a base tile file
                string cellDir = Path.Combine(tempDirectory, "cells", "N45_50_E010_50");
                Directory.CreateDirectory(cellDir);
                string tilePath = Path.Combine(cellDir, "N45_50_E010_50_tiles_base.mbtiles");
                await File.WriteAllTextAsync(tilePath, "test-tile-data-v1");

                var manifestService = new ManifestGeneratorService();
                var region = new GeofabrikRegionModel {
                    Id = "trentino",
                    Name = "Trentino",
                    BoundingBoxList = new List<double> { 10.5, 45.5, 11.0, 46.0 }
                };

                // Act 1: Initial manifest generation
                string manifestPath = await manifestService.UpdateManifestAsync(
                    options,
                    new List<GeofabrikRegionModel> { region },
                    CancellationToken.None
                );

                string initialJson = await File.ReadAllTextAsync(manifestPath);
                ManifestRootModel? initialManifest = JsonSerializer.Deserialize<ManifestRootModel>(initialJson);
                Assert.NotNull(initialManifest);
                Assert.Single(initialManifest.CellList);
                string originalSha = initialManifest.CellList[0].Layers["transit_and_driving"].TilesSha256!;
                Assert.False(string.IsNullOrEmpty(originalSha));

                // Act 2: Second manifest update with unchanged file size (should reuse sha without issue)
                await manifestService.UpdateManifestAsync(
                    options,
                    new List<GeofabrikRegionModel> { region },
                    CancellationToken.None
                );

                string secondJson = await File.ReadAllTextAsync(manifestPath);
                ManifestRootModel? secondManifest = JsonSerializer.Deserialize<ManifestRootModel>(secondJson);
                Assert.NotNull(secondManifest);
                Assert.Single(secondManifest.CellList);
                Assert.Equal(originalSha, secondManifest.CellList[0].Layers["transit_and_driving"].TilesSha256);
            }finally {
                if (Directory.Exists(tempDirectory)) {
                    Directory.Delete(tempDirectory, true);
                }
            }
        }
    }
}
