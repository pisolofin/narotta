using NaRotta.MapBuilder.Core.Models;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests verifying Planetiler nodemap and storage mode heuristic selection in <see cref="HardwareProfileModel"/>.
    /// </summary>
    public class HardwareProfileModelTests {
        [Fact]
        public void GetPlanetilerNodeMapType_WhenPbfIsSmallAndRamIsLarge_ReturnsArray() {
            // Arrange
            var profile = new HardwareProfileModel {
                TotalRamMegabytes = 131072L, // 128 GB
                RecommendedJvmHeapGigabytes = 80
            };
            long pbfSizeBytes = 50L * 1024L * 1024L; // 50 MB
 
            // Act
            string nodeMapType = profile.GetPlanetilerNodeMapType(pbfSizeBytes);

            // Assert
            Assert.Equal("array", nodeMapType);
        }

        [Fact]
        public void GetPlanetilerNodeMapType_WhenPbfIsLargeAndRamIsLow_ReturnsSparseArray() {
            // Arrange
            var profile = new HardwareProfileModel {
                TotalRamMegabytes = 16384L // 16 GB
            };
            long pbfSizeBytes = 2000L * 1024L * 1024L; // 2 GB

            // Act
            string nodeMapType = profile.GetPlanetilerNodeMapType(pbfSizeBytes);

            // Assert
            Assert.Equal("sparsearray", nodeMapType);
        }

        [Fact]
        public void GetPlanetilerStorageMode_WhenPbfIsSmallAndRamIsSufficient_ReturnsRam() {
            // Arrange
            var profile = new HardwareProfileModel {
                TotalRamMegabytes = 32768L // 32 GB
            };
            long pbfSizeBytes = 300L * 1024L * 1024L; // 300 MB

            // Act
            string storageMode = profile.GetPlanetilerStorageMode(pbfSizeBytes);

            // Assert
            Assert.Equal("ram", storageMode);
        }

        [Fact]
        public void GetPlanetilerStorageMode_WhenPbfIsLarge_ReturnsMmap() {
            // Arrange
            var profile = new HardwareProfileModel {
                TotalRamMegabytes = 65536L // 64 GB
            };
            long pbfSizeBytes = 1200L * 1024L * 1024L; // 1.2 GB

            // Act
            string storageMode = profile.GetPlanetilerStorageMode(pbfSizeBytes);

            // Assert
            Assert.Equal("mmap", storageMode);
        }

        [Fact]
        public void GetPlanetilerStorageMode_WhenRamIsLow_ReturnsMmap() {
            // Arrange
            var profile = new HardwareProfileModel {
                TotalRamMegabytes = 16384L // 16 GB
            };
            long pbfSizeBytes = 400L * 1024L * 1024L; // 400 MB

            // Act
            string storageMode = profile.GetPlanetilerStorageMode(pbfSizeBytes);

            // Assert
            Assert.Equal("mmap", storageMode);
        }
    }
}
