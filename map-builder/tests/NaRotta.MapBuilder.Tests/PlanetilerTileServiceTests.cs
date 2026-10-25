using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Core.Services;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests verifying layer specifications in <see cref="PlanetilerTileService"/>.
    /// </summary>
    public class PlanetilerTileServiceTests {
        [Fact]
        public void GetLayerSpecification_WhenOverview_ReturnsCorrectParameters() {
            // Act
            (string schemaFileName, string outputSuffix, int minZoom, int maxZoom) spec =
                PlanetilerTileService.GetLayerSpecification(MapResolutionLayer.Overview);

            // Assert
            Assert.Equal("overview-schema.yml", spec.schemaFileName);
            Assert.Equal("tiles_overview", spec.outputSuffix);
            Assert.Equal(0, spec.minZoom);
            Assert.Equal(7, spec.maxZoom);
        }

        [Fact]
        public void GetLayerSpecification_WhenBase_ReturnsCorrectParameters() {
            // Act
            (string schemaFileName, string outputSuffix, int minZoom, int maxZoom) spec =
                PlanetilerTileService.GetLayerSpecification(MapResolutionLayer.Base);

            // Assert
            Assert.Equal("driving-base-schema.yml", spec.schemaFileName);
            Assert.Equal("tiles_base", spec.outputSuffix);
            Assert.Equal(8, spec.minZoom);
            Assert.Equal(14, spec.maxZoom);
        }

        [Fact]
        public void GetLayerSpecification_WhenPedestrian_ReturnsCorrectParameters() {
            // Act
            (string schemaFileName, string outputSuffix, int minZoom, int maxZoom) spec =
                PlanetilerTileService.GetLayerSpecification(MapResolutionLayer.Pedestrian);

            // Assert
            Assert.Equal("pedestrian-schema.yml", spec.schemaFileName);
            Assert.Equal("tiles_pedestrian", spec.outputSuffix);
            Assert.Equal(13, spec.minZoom);
            Assert.Equal(15, spec.maxZoom);
        }

        [Fact]
        public void GetLayerSpecification_WhenBuildings_ReturnsCorrectParameters() {
            // Act
            (string schemaFileName, string outputSuffix, int minZoom, int maxZoom) spec =
                PlanetilerTileService.GetLayerSpecification(MapResolutionLayer.Buildings);

            // Assert
            Assert.Equal("buildings-schema.yml", spec.schemaFileName);
            Assert.Equal("tiles_buildings", spec.outputSuffix);
            Assert.Equal(13, spec.minZoom);
            Assert.Equal(15, spec.maxZoom);
        }

        [Fact]
        public void GetLayerSpecification_WhenTerrain_ReturnsCorrectParameters() {
            // Act
            (string schemaFileName, string outputSuffix, int minZoom, int maxZoom) spec =
                PlanetilerTileService.GetLayerSpecification(MapResolutionLayer.Terrain);

            // Assert
            Assert.Equal("terrain-schema.yml", spec.schemaFileName);
            Assert.Equal("tiles_terrain_hd", spec.outputSuffix);
            Assert.Equal(9, spec.minZoom);
            Assert.Equal(14, spec.maxZoom);
        }
    }
}
