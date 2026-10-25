using NetTopologySuite.Geometries;

namespace NaRotta.MapBuilder.Cli.Models {
    /// <summary>
    /// Represents a city, municipality, or settlement indexed spatially during Pass 1 of the PBF search extractor.
    /// </summary>
    public class AdminPlaceModel {
        public long Id { get; set; }
        public long OsmId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string PlaceType { get; set; } = string.Empty;
        public string Postcode { get; set; } = string.Empty;
        public string AdminRegion { get; set; } = string.Empty;
        public double Latitude { get; set; }
        public double Longitude { get; set; }
        public int Population { get; set; }
        public Geometry? BoundaryPolygon { get; set; }
        public Envelope BoundingEnvelope { get; set; } = new Envelope();
    }

    /// <summary>
    /// Represents a deduplicated street within a specific municipality.
    /// </summary>
    public class StreetRecordModel {
        public long Id { get; set; }
        public long PlaceId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string CityName { get; set; } = string.Empty;
        public string Postcode { get; set; } = string.Empty;
        public double Latitude { get; set; }
        public double Longitude { get; set; }
        public int SegmentCount { get; set; }
    }

    /// <summary>
    /// Represents an extracted Point of Interest (POI) or address with house number.
    /// </summary>
    public class PoiRecordModel {
        public long Id { get; set; }
        public long OsmId { get; set; }
        public string Category { get; set; } = string.Empty;
        public string SubCategory { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string StreetName { get; set; } = string.Empty;
        public string HouseNumber { get; set; } = string.Empty;
        public string CityName { get; set; } = string.Empty;
        public string Postcode { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public string Website { get; set; } = string.Empty;
        public string OpeningHours { get; set; } = string.Empty;
        public double Latitude { get; set; }
        public double Longitude { get; set; }
    }
}
