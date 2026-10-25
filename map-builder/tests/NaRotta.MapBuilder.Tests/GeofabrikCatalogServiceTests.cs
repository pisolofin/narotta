using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Core.Services;
using System.Collections.Generic;
using System.Net.Http;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests verifying region querying and hierarchy traversal in <see cref="GeofabrikCatalogService"/>.
    /// </summary>
    public class GeofabrikCatalogServiceTests {
        [Fact]
        public void FindRegion_WhenExactIdMatches_ReturnsRegion() {
            // Arrange
            using var httpClient = new HttpClient();
            var service = new GeofabrikCatalogService(httpClient);
            var regionList = new List<GeofabrikRegionModel> {
                new GeofabrikRegionModel { Id = "italy", Name = "Italy", ParentId = "europe" },
                new GeofabrikRegionModel { Id = "france", Name = "France", ParentId = "europe" },
                new GeofabrikRegionModel { Id = "germany", Name = "Germany", ParentId = "europe" }
            };

            // Act
            GeofabrikRegionModel? foundRegion = service.FindRegion(regionList, "italy");

            // Assert
            Assert.NotNull(foundRegion);
            Assert.Equal("italy", foundRegion.Id);
            Assert.Equal("Italy", foundRegion.Name);
        }

        [Fact]
        public void FindRegion_WhenFullHierarchyProvided_MatchesRegion() {
            // Arrange
            using var httpClient = new HttpClient();
            var service = new GeofabrikCatalogService(httpClient);
            var regionList = new List<GeofabrikRegionModel> {
                new GeofabrikRegionModel { Id = "trentino-alto-adige", Name = "Trentino-Alto Adige", ParentId = "italy" },
                new GeofabrikRegionModel { Id = "veneto", Name = "Veneto", ParentId = "italy" }
            };

            // Act
            GeofabrikRegionModel? foundRegion = service.FindRegion(regionList, "italy/trentino-alto-adige");

            // Assert
            Assert.NotNull(foundRegion);
            Assert.Equal("trentino-alto-adige", foundRegion.Id);
        }

        [Fact]
        public void FindRegion_WhenMatchingByLeafSlug_ReturnsRegion() {
            // Arrange
            using var httpClient = new HttpClient();
            var service = new GeofabrikCatalogService(httpClient);
            var regionList = new List<GeofabrikRegionModel> {
                new GeofabrikRegionModel { Id = "lombardia", Name = "Lombardia", ParentId = "italy" }
            };

            // Act
            GeofabrikRegionModel? foundRegion = service.FindRegion(regionList, "europe/italy/lombardia");

            // Assert
            Assert.NotNull(foundRegion);
            Assert.Equal("lombardia", foundRegion.Id);
        }

        [Fact]
        public void FindRegion_WhenRegionDoesNotExist_ReturnsNull() {
            // Arrange
            using var httpClient = new HttpClient();
            var service = new GeofabrikCatalogService(httpClient);
            var regionList = new List<GeofabrikRegionModel> {
                new GeofabrikRegionModel { Id = "italy", Name = "Italy", ParentId = "europe" }
            };

            // Act
            GeofabrikRegionModel? foundRegion = service.FindRegion(regionList, "japan");

            // Assert
            Assert.Null(foundRegion);
        }

        [Fact]
        public void GetSubregionList_ReturnsOnlyDirectChildrenSorted() {
            // Arrange
            using var httpClient = new HttpClient();
            var service = new GeofabrikCatalogService(httpClient);
            var regionList = new List<GeofabrikRegionModel> {
                new GeofabrikRegionModel { Id = "italy", Name = "Italy", ParentId = "europe" },
                new GeofabrikRegionModel { Id = "veneto", Name = "Veneto", ParentId = "italy" },
                new GeofabrikRegionModel { Id = "lombardia", Name = "Lombardia", ParentId = "italy" },
                new GeofabrikRegionModel { Id = "trentino-alto-adige", Name = "Trentino-Alto Adige", ParentId = "italy" },
                new GeofabrikRegionModel { Id = "france", Name = "France", ParentId = "europe" }
            };

            // Act
            List<GeofabrikRegionModel> subregionList = service.GetSubregionList(regionList, "italy");

            // Assert
            Assert.Equal(3, subregionList.Count);
            Assert.Equal("lombardia", subregionList[0].Id);
            Assert.Equal("trentino-alto-adige", subregionList[1].Id);
            Assert.Equal("veneto", subregionList[2].Id);
        }

        [Fact]
        public void GetSubregionList_WhenParentIsUs_ReturnsAllUsSlashSubregions() {
            // Arrange
            using var httpClient = new HttpClient();
            var service = new GeofabrikCatalogService(httpClient);
            var regionList = new List<GeofabrikRegionModel> {
                new GeofabrikRegionModel { Id = "us", Name = "United States", ParentId = "north-america" },
                new GeofabrikRegionModel { Id = "us/california", Name = "California", ParentId = "north-america" },
                new GeofabrikRegionModel { Id = "us/new-york", Name = "New York", ParentId = "north-america" },
                new GeofabrikRegionModel { Id = "canada", Name = "Canada", ParentId = "north-america" }
            };

            // Act
            List<GeofabrikRegionModel> subregionList = service.GetSubregionList(regionList, "us");

            // Assert
            Assert.Equal(2, subregionList.Count);
            Assert.Equal("us/california", subregionList[0].Id);
            Assert.Equal("us/new-york", subregionList[1].Id);
        }
    }
}
