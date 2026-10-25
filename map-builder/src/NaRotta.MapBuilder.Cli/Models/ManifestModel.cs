using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace NaRotta.MapBuilder.Cli.Models {
    /// <summary>
    /// Root catalog model serialized as manifest.json (schema v2.2) for the NaRotta mobile app.
    /// </summary>
    public class ManifestRootModel {
        [JsonPropertyName("schema_version")]
        public string SchemaVersion { get; set; } = "2.2";

        [JsonPropertyName("generated_at")]
        public string GeneratedAt { get; set; } = string.Empty;

        [JsonPropertyName("base_url")]
        public string BaseUrl { get; set; } = "https://storage.narotta.app/maps/";

        [JsonPropertyName("cell_size_degrees")]
        public double CellSizeDegrees { get; set; } = GeoCellCoordinateModel.DefaultCellSizeDegrees;

        [JsonPropertyName("overview")]
        public ManifestOverviewModel? Overview { get; set; }

        [JsonPropertyName("assets")]
        public ManifestAssetsModel? Assets { get; set; }

        [JsonPropertyName("regions")]
        public List<ManifestRegionModel> RegionList { get; set; } = new List<ManifestRegionModel>();

        [JsonPropertyName("cells")]
        public List<ManifestCellModel> CellList { get; set; } = new List<ManifestCellModel>();
    }

    /// <summary>
    /// Metadata for the low-zoom global/continental overview map (Zoom 0 to 7).
    /// </summary>
    public class ManifestOverviewModel {
        [JsonPropertyName("filename")]
        public string Filename { get; set; } = string.Empty;

        [JsonPropertyName("min_zoom")]
        public int MinZoom { get; set; } = 0;

        [JsonPropertyName("max_zoom")]
        public int MaxZoom { get; set; } = 7;

        [JsonPropertyName("size_bytes")]
        public long SizeBytes { get; set; }

        [JsonPropertyName("sha256")]
        public string Sha256 { get; set; } = string.Empty;
    }

    /// <summary>
    /// Metadata for the offline MapLibre fonts, sprites, and day/night style archive.
    /// </summary>
    public class ManifestAssetsModel {
        [JsonPropertyName("filename")]
        public string Filename { get; set; } = string.Empty;

        [JsonPropertyName("version")]
        public string Version { get; set; } = string.Empty;

        [JsonPropertyName("size_bytes")]
        public long SizeBytes { get; set; }

        [JsonPropertyName("sha256")]
        public string Sha256 { get; set; } = string.Empty;
    }

    /// <summary>
    /// Metadata for a downloadable geographical region or country package.
    /// </summary>
    public class ManifestRegionModel {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("parent_id")]
        public string ParentId { get; set; } = string.Empty;

        [JsonPropertyName("country_code")]
        public string CountryCode { get; set; } = string.Empty;

        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("version")]
        public string Version { get; set; } = string.Empty;

        [JsonPropertyName("bbox")]
        public List<double> BoundingBoxList { get; set; } = new List<double>();

        [JsonPropertyName("cell_ids")]
        public List<string> CellIdList { get; set; } = new List<string>();

        [JsonPropertyName("search")]
        public ManifestSearchModel? Search { get; set; }

        [JsonPropertyName("layers")]
        public Dictionary<string, ManifestLayerModel> Layers { get; set; } = new Dictionary<string, ManifestLayerModel>();
    }

    /// <summary>
    /// Metadata for a 0.5 x 0.5 degree modular cell package used for finger-drawn areas and route corridors.
    /// </summary>
    public class ManifestCellModel {
        [JsonPropertyName("cell_id")]
        public string CellId { get; set; } = string.Empty;

        [JsonPropertyName("bbox")]
        public List<double> BoundingBoxList { get; set; } = new List<double>();

        [JsonPropertyName("layers")]
        public Dictionary<string, ManifestLayerModel> Layers { get; set; } = new Dictionary<string, ManifestLayerModel>();
    }

    /// <summary>
    /// Metadata for the regional offline SQLite FTS5 & R-Tree search database.
    /// </summary>
    public class ManifestSearchModel {
        [JsonPropertyName("filename")]
        public string Filename { get; set; } = string.Empty;

        [JsonPropertyName("size_bytes")]
        public long SizeBytes { get; set; }

        [JsonPropertyName("sha256")]
        public string Sha256 { get; set; } = string.Empty;
    }

    /// <summary>
    /// Metadata for a specific resolution/functional layer (base, pedestrian, buildings_3d, terrain_hd).
    /// </summary>
    public class ManifestLayerModel {
        [JsonPropertyName("description")]
        public string Description { get; set; } = string.Empty;

        [JsonPropertyName("min_zoom")]
        public int MinZoom { get; set; }

        [JsonPropertyName("max_zoom")]
        public int MaxZoom { get; set; }

        [JsonPropertyName("tiles")]
        public string? TilesFilename { get; set; }

        [JsonPropertyName("tiles_size_bytes")]
        public long? TilesSizeBytes { get; set; }

        [JsonPropertyName("tiles_sha256")]
        public string? TilesSha256 { get; set; }

        [JsonPropertyName("routing")]
        public string? RoutingFilename { get; set; }

        [JsonPropertyName("routing_size_bytes")]
        public long? RoutingSizeBytes { get; set; }

        [JsonPropertyName("routing_sha256")]
        public string? RoutingSha256 { get; set; }
    }
}
