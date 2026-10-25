using NaRotta.MapBuilder.Core.Models;
using System.Collections.Generic;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests for <see cref="GeofabrikRegionModel"/>.
    /// </summary>
    public class GeofabrikRegionModelTests {
        [Fact]
        public void GetFileSlug_WhenNestedRegionId_ReturnsLeafSlug() {
            // Arrange
            var region = new GeofabrikRegionModel {
                Id = "europe/italy/trentino-alto-adige"
            };

            // Act
            string slug = region.GetFileSlug();

            // Assert
            Assert.Equal("trentino-alto-adige", slug);
        }

        [Fact]
        public void GetFileSlug_WhenSimpleRegionId_ReturnsLowerSlug() {
            // Arrange
            var region = new GeofabrikRegionModel {
                Id = "Italy"
            };

            // Act
            string slug = region.GetFileSlug();

            // Assert
            Assert.Equal("italy", slug);
        }

        [Fact]
        public void GetFileSlug_WhenEmptyId_ReturnsUnknown() {
            // Arrange
            var region = new GeofabrikRegionModel {
                Id = ""
            };

            // Act
            string slug = region.GetFileSlug();

            // Assert
            Assert.Equal("unknown", slug);
        }

        [Fact]
        public void GetBoundingBoxString_WhenCoordinatesValid_FormatsInvariantString() {
            // Arrange
            var region = new GeofabrikRegionModel {
                BoundingBoxList = new List<double> {
                    10.45678,
                    45.12345,
                    12.98765,
                    47.01234
                }
            };

            // Act
            string boundingBoxText = region.GetBoundingBoxString();

            // Assert
            Assert.Equal("10.4568,45.1234,12.9877,47.0123", boundingBoxText);
        }

        [Fact]
        public void GetBoundingBoxString_WhenBoundingBoxListIsNull_ReturnsDefaultGlobalBbox() {
            // Arrange
            var region = new GeofabrikRegionModel {
                BoundingBoxList = new List<double>()
            };

            // Act
            string boundingBoxText = region.GetBoundingBoxString();

            // Assert
            Assert.Equal("-180.0,-85.0,180.0,85.0", boundingBoxText);
        }
    }
}
