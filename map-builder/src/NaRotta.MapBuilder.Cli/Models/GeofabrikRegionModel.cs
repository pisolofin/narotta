using NetTopologySuite.Geometries;
using System;
using System.Collections.Generic;

namespace NaRotta.MapBuilder.Cli.Models {
    /// <summary>
    /// Represents a geographical region or country entry from the Geofabrik catalog index.
    /// </summary>
    public class GeofabrikRegionModel {
        public string Id { get; set; } = string.Empty;
        public string ParentId { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string IsoCountryCode { get; set; } = string.Empty;
        public string PbfUrl { get; set; } = string.Empty;
        public string Md5Url { get; set; } = string.Empty;
        public string PolyUrl { get; set; } = string.Empty;
        public List<double> BoundingBoxList { get; set; } = new List<double>();
        public Geometry? BoundaryGeometry { get; set; }

        /// <summary>
        /// Gets the sanitized file slug for naming local output files (e.g. "italy" or "trentino-alto-adige").
        /// </summary>
        public string GetFileSlug() {
            if (string.IsNullOrWhiteSpace(this.Id)) {
                return "unknown";
            }

            string[] segmentList = this.Id.Split('/', StringSplitOptions.RemoveEmptyEntries);
            if (segmentList.Length == 0) {
                return this.Id;
            }

            return segmentList[segmentList.Length - 1].ToLowerInvariant();
        }

        /// <summary>
        /// Formats the bounding box as a Planetiler/Valhalla compatible string "minLon,minLat,maxLon,maxLat".
        /// </summary>
        public string GetBoundingBoxString() {
            if ((this.BoundingBoxList == null) || (this.BoundingBoxList.Count < 4)) {
                return "-180.0,-85.0,180.0,85.0";
            }

            return string.Format(
                System.Globalization.CultureInfo.InvariantCulture,
                "{0:F4},{1:F4},{2:F4},{3:F4}",
                this.BoundingBoxList[0],
                this.BoundingBoxList[1],
                this.BoundingBoxList[2],
                this.BoundingBoxList[3]
            );
        }
    }
}
