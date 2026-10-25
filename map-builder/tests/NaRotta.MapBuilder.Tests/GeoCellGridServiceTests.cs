using Microsoft.Data.Sqlite;
using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Core.Services;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit and integration tests for <see cref="GeoCellGridService"/> covering 0.5x0.5 degree cell math, finger-drawn lasso polygon intersection, smart route corridor planning, cell deduplication, and SQLite MBTiles slicing.
    /// </summary>
    public class GeoCellGridServiceTests {
        [Fact]
        public void GetCellForCoordinates_And_TryParseCellId_RoundTripSuccessfully() {
            // Arrange
            var service = new GeoCellGridService();
            double gardaLongitude = 10.65;
            double gardaLatitude = 45.62;

            // Act
            GeoCellCoordinateModel cell = service.GetCellForCoordinates(gardaLongitude, gardaLatitude);
            GeoCellCoordinateModel? parsedCell = service.TryParseCellId(cell.CellId);

            // Assert
            Assert.Equal("N45_50_E010_50", cell.CellId);
            Assert.Equal(10.5, cell.MinLongitude);
            Assert.Equal(45.5, cell.MinLatitude);
            Assert.Equal(11.0, cell.MaxLongitude);
            Assert.Equal(46.0, cell.MaxLatitude);

            Assert.NotNull(parsedCell);
            Assert.Equal(cell.CellId, parsedCell.CellId);
            Assert.Equal(cell.MinLongitude, parsedCell.MinLongitude);
            Assert.Equal(cell.MinLatitude, parsedCell.MinLatitude);
        }

        [Fact]
        public void GetIntersectingCellListForPolygon_WhenUserCirclesLakeGardaWithFinger_ReturnsExactCells() {
            // Arrange: A freehand polygon drawn by the user with their finger around Lake Garda (spanning Lombardy, Veneto, and Trentino)
            var service = new GeoCellGridService();
            var fingerLassoPointList = new List<(double Longitude, double Latitude)> {
                (10.52, 45.45), // Sirmione / Desenzano
                (10.75, 45.45), // Peschiera / Lazise
                (10.88, 45.88), // Riva del Garda (Trentino)
                (10.55, 45.80)  // Gargnano / Salò (Lombardy)
            };

            // Act
            List<GeoCellCoordinateModel> selectedCellList = service.GetIntersectingCellListForPolygon(fingerLassoPointList);

            // Assert
            Assert.Equal(2, selectedCellList.Count);
            Assert.Equal("N45_00_E010_50", selectedCellList[0].CellId);
            Assert.Equal("N45_50_E010_50", selectedCellList[1].CellId);
        }

        [Fact]
        public void ComputeRouteCorridorCellPlan_WhenRouteFromMilanToBologna_SelectsCorridorBaseAndDestinationHdCells() {
            // Arrange: Route from Milan (45.46, 9.19) -> Parma (44.80, 10.32) -> Bologna (44.49, 11.34)
            var service = new GeoCellGridService();
            var routePointList = new List<(double Longitude, double Latitude)> {
                (9.19, 45.46),
                (10.32, 44.80),
                (11.34, 44.49)
            };

            // Act
            RouteCorridorCellPlanModel plan = service.ComputeRouteCorridorCellPlan(
                routePointList,
                null,
                15.0,
                10.0
            );

            List<string> baseCorridorIdList = plan.GetCorridorBaseCellIdList();
            List<string> destinationHdIdList = plan.GetDestinationHdCellIdList();

            // Assert: Corridor Base covers Milan, Parma, and Bologna cells
            Assert.Contains("N45_00_E009_00", baseCorridorIdList); // Milan cell
            Assert.Contains("N44_50_E010_00", baseCorridorIdList); // Parma cell
            Assert.Contains("N44_00_E011_00", baseCorridorIdList); // Bologna cell

            // Assert: Destination HD only covers the arrival area around Bologna (not Milan or Parma)
            Assert.Contains("N44_00_E011_00", destinationHdIdList);
            Assert.DoesNotContain("N45_00_E009_00", destinationHdIdList);
            Assert.True(destinationHdIdList.Count < baseCorridorIdList.Count);
        }

        [Fact]
        public void ComputeMissingCellIdList_DeduplicatesAlreadyInstalledCorridorCellsWhenDownloadingRegion() {
            // Arrange
            var service = new GeoCellGridService();
            var regionCellIdList = new List<string> {
                "N45_00_E009_00",
                "N45_00_E009_50",
                "N45_50_E009_00",
                "N45_50_E010_50"
            };
            var alreadyInstalledFromRouteList = new List<string> {
                "N45_00_E009_00",
                "N45_50_E010_50"
            };

            // Act
            List<string> missingCellIdList = service.ComputeMissingCellIdList(regionCellIdList, alreadyInstalledFromRouteList);

            // Assert
            Assert.Equal(2, missingCellIdList.Count);
            Assert.Contains("N45_00_E009_50", missingCellIdList);
            Assert.Contains("N45_50_E009_00", missingCellIdList);
        }

        [Fact]
        public async Task SliceMbtilesIntoGeoCellsAsync_ExtractsPopulatedCellDatabase() {
            // Arrange
            string tempDir = Path.Combine(Path.GetTempPath(), "narotta_test_cells_" + Path.GetRandomFileName());
            Directory.CreateDirectory(tempDir);

            string sourceMbtilesPath = Path.Combine(tempDir, "source_base.mbtiles");
            string connectionString = new SqliteConnectionStringBuilder {
                DataSource = sourceMbtilesPath,
                Mode = SqliteOpenMode.ReadWriteCreate,
                Pooling = false
            }.ToString();

            using var cancellationTokenSource = new CancellationTokenSource();

            try {
                await using (var connection = new SqliteConnection(connectionString)) {
                    await connection.OpenAsync(cancellationTokenSource.Token);
                    using var command = connection.CreateCommand();
                    // Zoom 8 tile (x=135, osmY=91 -> tmsY = 255 - 91 = 164) covers Longitude ~9.84..11.25, Latitude ~45.08..46.07
                    command.CommandText = @"
                        CREATE TABLE metadata (name TEXT, value TEXT);
                        CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
                        INSERT INTO tiles (zoom_level, tile_column, tile_row, tile_data) VALUES (8, 135, 164, X'01020304');
                    ";
                    await command.ExecuteNonQueryAsync(cancellationTokenSource.Token);
                }

                var region = new GeofabrikRegionModel {
                    Id = "europe/italy/trentino-alto-adige",
                    Name = "Trentino-Alto Adige",
                    BoundingBoxList = new List<double> { 10.55, 45.55, 10.95, 45.95 }
                };

                var options = new BuildOptionsModel {
                    OutputDirectory = tempDir
                };

                var service = new GeoCellGridService();

                // Act
                List<GeoCellCoordinateModel> populatedCellList = await service.SliceMbtilesIntoGeoCellsAsync(
                    sourceMbtilesPath,
                    region,
                    MapResolutionLayer.Base,
                    options,
                    cancellationTokenSource.Token
                );

                // Assert
                Assert.Single(populatedCellList);
                Assert.Equal("N45_50_E010_50", populatedCellList[0].CellId);

                string expectedCellFile = Path.Combine(tempDir, "cells", "N45_50_E010_50", "N45_50_E010_50_tiles_base.mbtiles");
                Assert.True(File.Exists(expectedCellFile));
            }finally {
                SqliteConnection.ClearAllPools();
                if (Directory.Exists(tempDir)) {
                    Directory.Delete(tempDir, true);
                }
            }
        }
    }
}
