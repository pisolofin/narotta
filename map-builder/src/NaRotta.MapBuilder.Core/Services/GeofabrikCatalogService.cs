using NaRotta.MapBuilder.Core.Models;
using NetTopologySuite.Geometries;
using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Services {
    /// <summary>
    /// Downloads, caches, and parses the official Geofabrik GeoJSON region catalog (index-v1.json).
    /// </summary>
    public class GeofabrikCatalogService {
        private const string GeofabrikIndexUrl = "https://download.geofabrik.de/index-v1.json";
        private const string CachedIndexFileName = "geofabrik-index-v1.json";

        private readonly HttpClient _httpClient;
        private readonly GeometryFactory _geometryFactory;

        public GeofabrikCatalogService(HttpClient httpClient) {
            _httpClient = httpClient;
            _geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);
        }

        /// <summary>
        /// Loads the complete list of Geofabrik regions from cache or downloads it from Geofabrik.
        /// </summary>
        public async Task<List<GeofabrikRegionModel>> LoadCatalogAsync(
            string workspaceDirectory,
            bool forceRefresh,
            CancellationToken cancellationToken
        ) {
            Directory.CreateDirectory(workspaceDirectory);
            string cacheFilePath = Path.Combine(workspaceDirectory, CachedIndexFileName);

            bool shouldDownload = forceRefresh || (!File.Exists(cacheFilePath));
            if (!shouldDownload) {
                FileInfo existingInfo = new FileInfo(cacheFilePath);
                if ((DateTime.UtcNow - existingInfo.LastWriteTimeUtc).TotalHours > 24.0) {
                    shouldDownload = true;
                }
            }

            if (shouldDownload) {
                Console.WriteLine("[Catalog] Downloading Geofabrik region index from " + GeofabrikIndexUrl + "...");
                using HttpResponseMessage response = await _httpClient.GetAsync(GeofabrikIndexUrl, cancellationToken);
                response.EnsureSuccessStatusCode();
                string jsonContent = await response.Content.ReadAsStringAsync(cancellationToken);
                await File.WriteAllTextAsync(cacheFilePath, jsonContent, cancellationToken);
            }

            string cachedJson = await File.ReadAllTextAsync(cacheFilePath, cancellationToken);
            return ParseCatalogJson(cachedJson);
        }

        /// <summary>
        /// Finds a specific region by its ID or normalized path (e.g. "europe/italy/trentino-alto-adige" or "trentino-alto-adige").
        /// </summary>
        public GeofabrikRegionModel? FindRegion(List<GeofabrikRegionModel> regionList, string regionQuery) {
            if ((regionList == null) || string.IsNullOrWhiteSpace(regionQuery)) {
                return null;
            }

            string normalizedQuery = regionQuery.Trim().Trim('/').ToLowerInvariant();
            string lastSegment = normalizedQuery;
            if (normalizedQuery.Contains('/')) {
                string[] partList = normalizedQuery.Split('/', StringSplitOptions.RemoveEmptyEntries);
                lastSegment = partList[partList.Length - 1];
            }

            // 1. Exact ID match or full hierarchy match
            foreach (GeofabrikRegionModel region in regionList) {
                string regionIdLower = region.Id.ToLowerInvariant();
                string fullPathLower = string.IsNullOrEmpty(region.ParentId)
                    ? regionIdLower
                    : (region.ParentId.ToLowerInvariant() + "/" + regionIdLower);

                if ((regionIdLower == normalizedQuery) || (fullPathLower == normalizedQuery)) {
                    return region;
                }
            }

            // 2. Match by leaf slug (e.g. "trentino-alto-adige" or "italy/trentino-alto-adige")
            foreach (GeofabrikRegionModel region in regionList) {
                if (region.Id.ToLowerInvariant() == lastSegment) {
                    return region;
                }
            }

            return null;
        }

        /// <summary>
        /// Returns all direct child subregions belonging to the specified parent region ID.
        /// </summary>
        public List<GeofabrikRegionModel> GetSubregionList(List<GeofabrikRegionModel> regionList, string parentRegionId) {
            var childRegionList = new List<GeofabrikRegionModel>();
            if ((regionList == null) || string.IsNullOrWhiteSpace(parentRegionId)) {
                return childRegionList;
            }

            GeofabrikRegionModel? parentRegion = this.FindRegion(regionList, parentRegionId);
            string resolvedParentId = (parentRegion != null) ? parentRegion.Id.ToLowerInvariant() : parentRegionId.ToLowerInvariant();

            foreach (GeofabrikRegionModel region in regionList) {
                if (region.ParentId.ToLowerInvariant() == resolvedParentId) {
                    childRegionList.Add(region);
                }else if ((resolvedParentId == "us") && region.Id.ToLowerInvariant().StartsWith("us/")) {
                    childRegionList.Add(region);
                }
            }

            childRegionList.Sort((GeofabrikRegionModel left, GeofabrikRegionModel right) =>
                string.Compare(left.Id, right.Id, StringComparison.OrdinalIgnoreCase)
            );
            return childRegionList;
        }

        /// <summary>
        /// Parses the Geofabrik GeoJSON FeatureCollection into a list of <see cref="GeofabrikRegionModel"/>.
        /// </summary>
        private List<GeofabrikRegionModel> ParseCatalogJson(string jsonText) {
            var regionList = new List<GeofabrikRegionModel>();
            using JsonDocument document = JsonDocument.Parse(jsonText);

            if (!document.RootElement.TryGetProperty("features", out JsonElement featuresElement)) {
                return regionList;
            }

            foreach (JsonElement featureItem in featuresElement.EnumerateArray()) {
                if (!featureItem.TryGetProperty("properties", out JsonElement propertiesElement)) {
                    continue;
                }

                string regionId = GetStringProperty(propertiesElement, "id");
                if (string.IsNullOrWhiteSpace(regionId)) {
                    continue;
                }

                var model = new GeofabrikRegionModel {
                    Id = regionId,
                    ParentId = GetStringProperty(propertiesElement, "parent"),
                    Name = GetStringProperty(propertiesElement, "name"),
                    IsoCountryCode = ExtractIsoCode(propertiesElement)
                };

                // Extract URLs
                if (propertiesElement.TryGetProperty("urls", out JsonElement urlsElement)) {
                    model.PbfUrl = GetStringProperty(urlsElement, "pbf");
                    model.PolyUrl = GetStringProperty(urlsElement, "poly");
                    if (!string.IsNullOrWhiteSpace(model.PbfUrl)) {
                        model.Md5Url = model.PbfUrl + ".md5";
                    }
                }

                // Extract geometry and compute bounding box [minLon, minLat, maxLon, maxLat]
                if (featureItem.TryGetProperty("geometry", out JsonElement geometryElement)) {
                    Geometry? parsedGeometry = ParseGeoJsonGeometry(geometryElement);
                    if (parsedGeometry != null) {
                        model.BoundaryGeometry = parsedGeometry;
                        Envelope envelope = parsedGeometry.EnvelopeInternal;
                        if (!envelope.IsNull) {
                            model.BoundingBoxList = new List<double> {
                                Math.Round(envelope.MinX, 4),
                                Math.Round(envelope.MinY, 4),
                                Math.Round(envelope.MaxX, 4),
                                Math.Round(envelope.MaxY, 4)
                            };
                        }
                    }
                }

                regionList.Add(model);
            }

            return regionList;
        }

        /// <summary>
        /// Safely extracts a string property from a <see cref="JsonElement"/>.
        /// </summary>
        private static string GetStringProperty(JsonElement parentElement, string propertyName) {
            if (parentElement.TryGetProperty(propertyName, out JsonElement valueElement)) {
                if (valueElement.ValueKind == JsonValueKind.String) {
                    return valueElement.GetString() ?? string.Empty;
                }
            }
            return string.Empty;
        }

        /// <summary>
        /// Extracts ISO3166-1 alpha2 country code if available.
        /// </summary>
        private static string ExtractIsoCode(JsonElement propertiesElement) {
            if (propertiesElement.TryGetProperty("iso3166-1:alpha2", out JsonElement isoElement)) {
                if (isoElement.ValueKind == JsonValueKind.Array) {
                    foreach (JsonElement item in isoElement.EnumerateArray()) {
                        if (item.ValueKind == JsonValueKind.String) {
                            return item.GetString() ?? string.Empty;
                        }
                    }
                }else if (isoElement.ValueKind == JsonValueKind.String) {
                    return isoElement.GetString() ?? string.Empty;
                }
            }
            return string.Empty;
        }

        /// <summary>
        /// Parses a GeoJSON Polygon or MultiPolygon into a NetTopologySuite <see cref="Geometry"/>.
        /// </summary>
        private Geometry? ParseGeoJsonGeometry(JsonElement geometryElement) {
            try {
                string geometryType = GetStringProperty(geometryElement, "type");
                if (!geometryElement.TryGetProperty("coordinates", out JsonElement coordinatesElement)) {
                    return null;
                }

                if (geometryType == "Polygon") {
                    return ParsePolygonCoordinates(coordinatesElement);
                }else if (geometryType == "MultiPolygon") {
                    var polygonList = new List<Polygon>();
                    foreach (JsonElement polygonElement in coordinatesElement.EnumerateArray()) {
                        Polygon? parsedPolygon = ParsePolygonCoordinates(polygonElement);
                        if (parsedPolygon != null) {
                            polygonList.Add(parsedPolygon);
                        }
                    }

                    if (polygonList.Count > 0) {
                        return _geometryFactory.CreateMultiPolygon(polygonList.ToArray());
                    }
                }
            }catch (Exception) {
                // Ignore malformed geometry entries
            }

            return null;
        }

        /// <summary>
        /// Parses a GeoJSON Polygon coordinate array into a NetTopologySuite <see cref="Polygon"/>.
        /// </summary>
        private Polygon? ParsePolygonCoordinates(JsonElement polygonCoordinatesElement) {
            var ringCoordinateList = new List<LinearRing>();

            foreach (JsonElement ringElement in polygonCoordinatesElement.EnumerateArray()) {
                var coordinateList = new List<Coordinate>();
                foreach (JsonElement pointElement in ringElement.EnumerateArray()) {
                    if ((pointElement.ValueKind == JsonValueKind.Array) && (pointElement.GetArrayLength() >= 2)) {
                        double longitude = pointElement[0].GetDouble();
                        double latitude = pointElement[1].GetDouble();
                        coordinateList.Add(new Coordinate(longitude, latitude));
                    }
                }

                if (coordinateList.Count >= 4) {
                    Coordinate firstCoord = coordinateList[0];
                    Coordinate lastCoord = coordinateList[coordinateList.Count - 1];
                    if (!firstCoord.Equals2D(lastCoord)) {
                        coordinateList.Add(new Coordinate(firstCoord.X, firstCoord.Y));
                    }
                    ringCoordinateList.Add(_geometryFactory.CreateLinearRing(coordinateList.ToArray()));
                }
            }

            if (ringCoordinateList.Count == 0) {
                return null;
            }

            LinearRing shellRing = ringCoordinateList[0];
            var holeRingList = new List<LinearRing>();
            for (int ringIndex = 1; ringIndex < ringCoordinateList.Count; ringIndex++) {
                holeRingList.Add(ringCoordinateList[ringIndex]);
            }

            return _geometryFactory.CreatePolygon(shellRing, holeRingList.ToArray());
        }
    }
}
