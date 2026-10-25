using System;
using System.Collections.Generic;
using System.Globalization;

namespace NaRotta.MapBuilder.Cli.Models {
    /// <summary>
    /// Represents a single 0.5 x 0.5 degree (~50 km x 50 km) geographical grid cell used for freehand polygon selection, route corridor downloads, and regional deduplication.
    /// </summary>
    public class GeoCellCoordinateModel {
        public const double DefaultCellSizeDegrees = 0.5;

        public string CellId { get; set; } = string.Empty;
        public int LatGridIndex { get; set; }
        public int LonGridIndex { get; set; }
        public double MinLongitude { get; set; }
        public double MinLatitude { get; set; }
        public double MaxLongitude { get; set; }
        public double MaxLatitude { get; set; }

        /// <summary>
        /// Returns the cell bounding box as [minLon, minLat, maxLon, maxLat].
        /// </summary>
        public List<double> GetBoundingBoxList() {
            return new List<double> {
                Math.Round(this.MinLongitude, 4),
                Math.Round(this.MinLatitude, 4),
                Math.Round(this.MaxLongitude, 4),
                Math.Round(this.MaxLatitude, 4)
            };
        }

        /// <summary>
        /// Formats the bounding box as an MBTiles metadata bounds string "minLon,minLat,maxLon,maxLat".
        /// </summary>
        public string GetBoundingBoxString() {
            return string.Format(
                CultureInfo.InvariantCulture,
                "{0:F4},{1:F4},{2:F4},{3:F4}",
                this.MinLongitude,
                this.MinLatitude,
                this.MaxLongitude,
                this.MaxLatitude
            );
        }
    }

    /// <summary>
    /// Represents the differentiated resolution download plan computed for a navigation route ("Smart Route Corridor").
    /// Outside the corridor the mobile app uses the global overview map (Z0-7) + primary routing backbone;
    /// along the corridor (±15 km) it downloads Base driving cells (Z8-14 + local routing + POIs);
    /// at the destination and intermediate stops (±10 km) it also downloads HD cells (3D buildings + pedestrian Z13-15).
    /// </summary>
    public class RouteCorridorCellPlanModel {
        public double CorridorRadiusKilometers { get; set; } = 15.0;
        public double StopHdRadiusKilometers { get; set; } = 10.0;
        public List<GeoCellCoordinateModel> CorridorBaseCellList { get; set; } = new List<GeoCellCoordinateModel>();
        public List<GeoCellCoordinateModel> DestinationHdCellList { get; set; } = new List<GeoCellCoordinateModel>();

        /// <summary>
        /// Returns the list of cell IDs required for the driving corridor (Base Z8-14 + Local Routing + Search).
        /// </summary>
        public List<string> GetCorridorBaseCellIdList() {
            var idList = new List<string>();
            foreach (GeoCellCoordinateModel cell in this.CorridorBaseCellList) {
                idList.Add(cell.CellId);
            }
            return idList;
        }

        /// <summary>
        /// Returns the list of cell IDs required for high-definition arrival/stop areas (Buildings 3D + Pedestrian Z13-15).
        /// </summary>
        public List<string> GetDestinationHdCellIdList() {
            var idList = new List<string>();
            foreach (GeoCellCoordinateModel cell in this.DestinationHdCellList) {
                idList.Add(cell.CellId);
            }
            return idList;
        }
    }
}
