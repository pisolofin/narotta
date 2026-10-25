using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace NaRotta.MapServer.Models {
    /// <summary>
    /// Configuration settings for the map distribution server.
    /// </summary>
    public class MapServerSettingsModel {
        public string StorageDirectory { get; set; } = string.Empty;
        public string PublicBaseUrl { get; set; } = "http://localhost:5001";
    }

    /// <summary>
    /// Geographic point with latitude and longitude.
    /// </summary>
    public class GeoPointModel {
        [JsonPropertyName("latitude")]
        public double Latitude { get; set; }

        [JsonPropertyName("longitude")]
        public double Longitude { get; set; }
    }

    /// <summary>
    /// Request payload for calculating intersecting cells from a finger-drawn polygon / lasso.
    /// </summary>
    public class QueryPolygonRequestModel {
        [JsonPropertyName("points")]
        public List<GeoPointModel> PointList { get; set; } = new List<GeoPointModel>();

        [JsonPropertyName("layers")]
        public List<string> LayerList { get; set; } = new List<string>();
    }

    /// <summary>
    /// Detailed information about a single 0.5 x 0.5 degree grid cell.
    /// </summary>
    public class GeoCellDetailModel {
        [JsonPropertyName("cell_id")]
        public string CellId { get; set; } = string.Empty;

        [JsonPropertyName("bbox")]
        public List<double> BoundingBoxList { get; set; } = new List<double>();

        [JsonPropertyName("size_bytes")]
        public long SizeBytes { get; set; }

        [JsonPropertyName("size_mb")]
        public double SizeMb => Math.Round(this.SizeBytes / (1024.0 * 1024.0), 2);

        [JsonPropertyName("layers")]
        public List<string> LayerList { get; set; } = new List<string>();

        [JsonPropertyName("download_urls")]
        public Dictionary<string, string> DownloadUrlDictionary { get; set; } = new Dictionary<string, string>();
    }

    /// <summary>
    /// Response payload containing the computed cells and estimated download size for a lasso polygon.
    /// </summary>
    public class QueryPolygonResponseModel {
        [JsonPropertyName("total_cells")]
        public int TotalCells { get; set; }

        [JsonPropertyName("total_size_bytes")]
        public long TotalSizeBytes { get; set; }

        [JsonPropertyName("total_size_mb")]
        public double TotalSizeMb => Math.Round(this.TotalSizeBytes / (1024.0 * 1024.0), 2);

        [JsonPropertyName("cells")]
        public List<GeoCellDetailModel> CellList { get; set; } = new List<GeoCellDetailModel>();
    }
}
