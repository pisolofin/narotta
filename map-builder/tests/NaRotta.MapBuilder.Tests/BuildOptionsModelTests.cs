using NaRotta.MapBuilder.Core.Models;
using System.Collections.Generic;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests verifying command-line argument parsing and option mapping in <see cref="BuildOptionsModel"/>.
    /// </summary>
    public class BuildOptionsModelTests {
        [Fact]
        public void ParseArguments_WhenArgumentListIsEmpty_ReturnsDefaultOptions() {
            // Arrange
            string[] rawArgumentList = new string[0];
            string baseDirectory = "C:\\test\\narotta";

            // Act
            BuildOptionsModel options = BuildOptionsModel.ParseArguments(rawArgumentList, baseDirectory);

            // Assert
            Assert.Equal("help", options.CommandName);
            Assert.Equal("europe/italy/trentino-alto-adige", options.RegionId);
            Assert.False(options.SplitSubregions);
            Assert.True(options.IncludeElevation);
            Assert.False(options.SkipRouting);
            Assert.False(options.SkipTiles);
            Assert.False(options.SkipSearch);
            Assert.False(options.ForceDownload);
            Assert.Contains(MapResolutionLayer.Base, options.ResolutionLayerList);
            Assert.Contains(MapResolutionLayer.Pedestrian, options.ResolutionLayerList);
            Assert.Contains(MapResolutionLayer.Buildings, options.ResolutionLayerList);
            Assert.Contains(MapResolutionLayer.Terrain, options.ResolutionLayerList);
        }

        [Fact]
        public void ParseArguments_WhenCommandSpecified_ExtractsCommandName() {
            // Arrange
            string[] rawArgumentList = new string[] { "doctor" };
            string baseDirectory = "C:\\test\\narotta";

            // Act
            BuildOptionsModel options = BuildOptionsModel.ParseArguments(rawArgumentList, baseDirectory);

            // Assert
            Assert.Equal("doctor", options.CommandName);
        }

        [Fact]
        public void ParseArguments_WhenRegionFlagProvided_NormalizesRegionId() {
            // Arrange
            string[] rawArgumentList = new string[] {
                "download",
                "--region",
                "/europe/italy/lombardia/"
            };
            string baseDirectory = "C:\\test\\narotta";

            // Act
            BuildOptionsModel options = BuildOptionsModel.ParseArguments(rawArgumentList, baseDirectory);

            // Assert
            Assert.Equal("download", options.CommandName);
            Assert.Equal("europe/italy/lombardia", options.RegionId);
        }

        [Fact]
        public void ParseArguments_WhenShortFlagsProvided_ParsesCorrectly() {
            // Arrange
            string[] rawArgumentList = new string[] {
                "build",
                "-r", "italy/sicilia",
                "-w", "C:\\custom\\workspace",
                "-o", "C:\\custom\\output"
            };
            string baseDirectory = "C:\\test\\narotta";

            // Act
            BuildOptionsModel options = BuildOptionsModel.ParseArguments(rawArgumentList, baseDirectory);

            // Assert
            Assert.Equal("build", options.CommandName);
            Assert.Equal("italy/sicilia", options.RegionId);
            Assert.Equal("C:\\custom\\workspace", options.WorkspaceDirectory);
            Assert.Equal("C:\\custom\\output", options.OutputDirectory);
        }

        [Fact]
        public void ParseArguments_WhenOutputSpecifiedWithoutWorkspaceOrProfiles_AlignsWorkspaceAndProfilesToSameLevel() {
            // Arrange
            string[] rawArgumentList = new string[] {
                "build-world",
                "--output", "C:\\data\\output"
            };
            string baseDirectory = "C:\\test\\narotta";

            // Act
            BuildOptionsModel options = BuildOptionsModel.ParseArguments(rawArgumentList, baseDirectory);

            // Assert
            Assert.Equal("C:\\data\\output", options.OutputDirectory);
            Assert.Equal("C:\\data\\workspace", options.WorkspaceDirectory);
            Assert.Equal("C:\\data\\profiles", options.ProfilesDirectory);
        }

        [Fact]
        public void ParseArguments_WhenNetworkShareOutputSpecified_AlignsWorkspaceAndProfilesOnNetworkShare() {
            // Arrange
            string[] rawArgumentList = new string[] {
                "build-world",
                "--output", "\\\\192.168.8.53\\Miscuglio\\Narotta\\data\\output"
            };
            string baseDirectory = "C:\\test\\narotta";

            // Act
            BuildOptionsModel options = BuildOptionsModel.ParseArguments(rawArgumentList, baseDirectory);

            // Assert
            Assert.Equal("\\\\192.168.8.53\\Miscuglio\\Narotta\\data\\output", options.OutputDirectory);
            Assert.Equal("\\\\192.168.8.53\\Miscuglio\\Narotta\\data\\workspace", options.WorkspaceDirectory);
            Assert.Equal("\\\\192.168.8.53\\Miscuglio\\Narotta\\data\\profiles", options.ProfilesDirectory);
        }

        [Fact]
        public void ParseArguments_WhenOutputAndWorkspaceSpecified_KeepsExplicitWorkspaceAndAlignsProfiles() {
            // Arrange
            string[] rawArgumentList = new string[] {
                "build-world",
                "--output", "C:\\data\\output",
                "--workspace", "D:\\fast-nvme\\workspace"
            };
            string baseDirectory = "C:\\test\\narotta";

            // Act
            BuildOptionsModel options = BuildOptionsModel.ParseArguments(rawArgumentList, baseDirectory);

            // Assert
            Assert.Equal("C:\\data\\output", options.OutputDirectory);
            Assert.Equal("D:\\fast-nvme\\workspace", options.WorkspaceDirectory);
            Assert.Equal("C:\\data\\profiles", options.ProfilesDirectory);
        }

        [Fact]
        public void ParseArguments_WhenAllResolutionsSpecified_AddsAllLayers() {
            // Arrange
            string[] rawArgumentList = new string[] {
                "build-tiles",
                "--resolutions", "all"
            };
            string baseDirectory = "C:\\test\\narotta";

            // Act
            BuildOptionsModel options = BuildOptionsModel.ParseArguments(rawArgumentList, baseDirectory);

            // Assert
            Assert.Equal(4, options.ResolutionLayerList.Count);
            Assert.Contains(MapResolutionLayer.Base, options.ResolutionLayerList);
            Assert.Contains(MapResolutionLayer.Pedestrian, options.ResolutionLayerList);
            Assert.Contains(MapResolutionLayer.Buildings, options.ResolutionLayerList);
            Assert.Contains(MapResolutionLayer.Terrain, options.ResolutionLayerList);
        }

        [Fact]
        public void ParseArguments_WhenSpecificResolutionsSpecified_ParsesOnlyRequestedLayers() {
            // Arrange
            string[] rawArgumentList = new string[] {
                "build-tiles",
                "--resolutions", "base,buildings,overview"
            };
            string baseDirectory = "C:\\test\\narotta";

            // Act
            BuildOptionsModel options = BuildOptionsModel.ParseArguments(rawArgumentList, baseDirectory);

            // Assert
            Assert.Equal(3, options.ResolutionLayerList.Count);
            Assert.Contains(MapResolutionLayer.Base, options.ResolutionLayerList);
            Assert.Contains(MapResolutionLayer.Buildings, options.ResolutionLayerList);
            Assert.Contains(MapResolutionLayer.Overview, options.ResolutionLayerList);
            Assert.DoesNotContain(MapResolutionLayer.Pedestrian, options.ResolutionLayerList);
            Assert.DoesNotContain(MapResolutionLayer.Terrain, options.ResolutionLayerList);
        }

        [Fact]
        public void ParseArguments_WhenPipelineSkipFlagsProvided_UpdatesProperties() {
            // Arrange
            string[] rawArgumentList = new string[] {
                "batch-build",
                "--split-subregions",
                "--slice-cells",
                "--clean-workspace",
                "--resume",
                "--no-elevation",
                "--skip-routing",
                "--skip-tiles",
                "--skip-search",
                "--force"
            };
            string baseDirectory = "C:\\test\\narotta";

            // Act
            BuildOptionsModel options = BuildOptionsModel.ParseArguments(rawArgumentList, baseDirectory);

            // Assert
            Assert.Equal("batch-build", options.CommandName);
            Assert.True(options.SplitSubregions);
            Assert.True(options.SliceGeoCells);
            Assert.True(options.CleanWorkspaceAfterBuild);
            Assert.True(options.ResumeBatch);
            Assert.False(options.IncludeElevation);
            Assert.True(options.SkipRouting);
            Assert.True(options.SkipTiles);
            Assert.True(options.SkipSearch);
            Assert.True(options.ForceDownload);
        }

        [Fact]
        public void ParseArguments_WhenBuildWorldSpecified_EnablesAllInOneDefaults() {
            // Arrange
            string[] rawArgumentList = new string[] { "build-world" };
            string baseDirectory = "C:\\test\\narotta";

            // Act
            BuildOptionsModel options = BuildOptionsModel.ParseArguments(rawArgumentList, baseDirectory);

            // Assert
            Assert.Equal("build-world", options.CommandName);
            Assert.True(options.SplitSubregions);
            Assert.True(options.SliceGeoCells);
            Assert.True(options.CleanWorkspaceAfterBuild);
            Assert.True(options.ResumeBatch);
            Assert.Equal(5, options.ResolutionLayerList.Count);
            Assert.Contains(MapResolutionLayer.Overview, options.ResolutionLayerList);
            Assert.Contains(MapResolutionLayer.Base, options.ResolutionLayerList);
            Assert.Contains(MapResolutionLayer.Pedestrian, options.ResolutionLayerList);
            Assert.Contains(MapResolutionLayer.Buildings, options.ResolutionLayerList);
            Assert.Contains(MapResolutionLayer.Terrain, options.ResolutionLayerList);
        }
    }
}
