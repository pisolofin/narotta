using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Web.Models;
using System.Collections.Generic;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests verifying conversion of web dashboard requests to pipeline <see cref="BuildOptionsModel"/>.
    /// </summary>
    public class StartBuildRequestModelTests {
        [Fact]
        public void ToBuildOptions_WhenStandardRequest_MapsPropertiesAccurately() {
            var request = new StartBuildRequestModel {
                CommandName = "build",
                RegionId = "europe/italy/calabria",
                SplitSubregions = true,
                SliceGeoCells = true,
                ResumeBatch = false,
                CleanWorkspaceAfterBuild = true,
                IncludeElevation = false,
                LayerNameList = new List<string> { "Base", "Buildings" }
            };

            BuildOptionsModel options = request.ToBuildOptions(
                "C:\\workspace",
                "C:\\output",
                "C:\\profiles",
                "C:\\tools",
                "https://cdn.test/maps/"
            );

            Assert.Equal("build", options.CommandName);
            Assert.Equal("europe/italy/calabria", options.RegionId);
            Assert.True(options.SplitSubregions);
            Assert.True(options.SliceGeoCells);
            Assert.False(options.ResumeBatch);
            Assert.True(options.CleanWorkspaceAfterBuild);
            Assert.False(options.IncludeElevation);
            Assert.Equal(2, options.ResolutionLayerList.Count);
            Assert.Contains(MapResolutionLayer.Base, options.ResolutionLayerList);
            Assert.Contains(MapResolutionLayer.Buildings, options.ResolutionLayerList);
        }

        [Fact]
        public void ToBuildOptions_WhenBuildWorldSelected_EnforcesBatchDefaults() {
            var request = new StartBuildRequestModel {
                CommandName = "build-world",
                RegionId = "world"
            };

            BuildOptionsModel options = request.ToBuildOptions(
                "C:\\workspace",
                "C:\\output",
                "C:\\profiles",
                "C:\\tools",
                "https://cdn.test/maps/"
            );

            Assert.Equal("build-world", options.CommandName);
            Assert.True(options.SplitSubregions);
            Assert.True(options.SliceGeoCells);
            Assert.True(options.CleanWorkspaceAfterBuild);
            Assert.True(options.ResumeBatch);
        }
    }
}
