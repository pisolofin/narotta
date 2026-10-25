using NaRotta.MapBuilder.Core.Runners;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests verifying cross-platform path conversion for WSL2 execution.
    /// </summary>
    public class CrossPlatformProcessRunnerTests {
        [Fact]
        public void ConvertHostPathToWslPath_WhenWindowsDrivePath_ReturnsMountPath() {
            // Arrange
            var runner = new CrossPlatformProcessRunner();
            string windowsPath = "C:\\Users\\Fabio\\source\\narotta\\workspace\\file.pbf";

            // Act
            string wslPath = runner.ConvertHostPathToWslPath(windowsPath);

            // Assert
            Assert.Equal("/mnt/c/Users/Fabio/source/narotta/workspace/file.pbf", wslPath);
        }

        [Fact]
        public void ConvertHostPathToWslPath_WhenDifferentDriveLetter_ReturnsCorrespondingMount() {
            // Arrange
            var runner = new CrossPlatformProcessRunner();
            string windowsPath = "D:\\maps\\elevation\\N45E011.hgt";

            // Act
            string wslPath = runner.ConvertHostPathToWslPath(windowsPath);

            // Assert
            Assert.Equal("/mnt/d/maps/elevation/N45E011.hgt", wslPath);
        }

        [Fact]
        public void ConvertHostPathToWslPath_WhenEmptyPath_ReturnsEmptyString() {
            // Arrange
            var runner = new CrossPlatformProcessRunner();

            // Act
            string wslPath = runner.ConvertHostPathToWslPath("");

            // Assert
            Assert.Equal("", wslPath);
        }
    }
}
