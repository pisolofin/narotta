using Microsoft.Data.Sqlite;
using NaRotta.MapBuilder.Core.Models;
using NetTopologySuite.Geometries;
using NetTopologySuite.Index.Strtree;
using OsmSharp;
using OsmSharp.Streams;
using OsmSharp.Tags;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Services {
    /// <summary>
    /// Pure C# two-pass OpenStreetMap .osm.pbf extractor that resolves street-to-municipality relationships via a spatial STRtree and builds the SQLite FTS5 & R-Tree search database.
    /// </summary>
    public class SearchDatabaseService {
        private const double SearchEnvelopeRadiusDegrees = 0.15; // ~15 km search radius for nearest municipality resolution

        /// <summary>
        /// Builds the <region>_search.db SQLite database with FTS5 full-text search and R-Tree spatial indexing from an .osm.pbf file.
        /// </summary>
        public async Task<string> BuildSearchDatabaseAsync(
            GeofabrikRegionModel region,
            string pbfFilePath,
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            if (!File.Exists(pbfFilePath)) {
                throw new FileNotFoundException("Input .osm.pbf file not found for search extraction.", pbfFilePath);
            }

            string regionOutputDirectory = Path.Combine(options.OutputDirectory, "regions", region.Id.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(regionOutputDirectory);

            string fileSlug = region.GetFileSlug();
            string outputDbPath = Path.Combine(regionOutputDirectory, fileSlug + "_search.db");
            string tempDbPath = outputDbPath + ".tmp";

            if (File.Exists(tempDbPath)) {
                File.Delete(tempDbPath);
            }

            Console.WriteLine("[SearchDB] Pass 1/2: Scanning municipalities, places, and node coordinates in " + Path.GetFileName(pbfFilePath) + "...");

            var placeSpatialTree = new STRtree<AdminPlaceModel>();
            var placeList = new List<AdminPlaceModel>();
            var nodeCoordinateDictionary = new Dictionary<long, (float Latitude, float Longitude)>();

            // Pass 1: Extract administrative places and cache node coordinates
            await Task.Run(() => {
                using var pbfStream = new FileStream(pbfFilePath, FileMode.Open, FileAccess.Read, FileShare.Read, 131072);
                var osmSource = new PBFOsmStreamSource(pbfStream);

                long nextPlaceId = 1L;
                foreach (OsmGeo osmElement in osmSource) {
                    cancellationToken.ThrowIfCancellationRequested();

                    if (osmElement.Type == OsmGeoType.Node) {
                        var nodeItem = (OsmSharp.Node)osmElement;
                        if (nodeItem.Id.HasValue && nodeItem.Latitude.HasValue && nodeItem.Longitude.HasValue) {
                            double lat = nodeItem.Latitude.Value;
                            double lon = nodeItem.Longitude.Value;
                            nodeCoordinateDictionary[nodeItem.Id.Value] = ((float)lat, (float)lon);

                            if ((nodeItem.Tags != null) && (nodeItem.Tags.Count > 0)) {
                                AdminPlaceModel? extractedPlace = TryExtractPlaceFromTags(
                                    nextPlaceId,
                                    nodeItem.Id.Value,
                                    lat,
                                    lon,
                                    nodeItem.Tags
                                );
                                if (extractedPlace != null) {
                                    placeList.Add(extractedPlace);
                                    placeSpatialTree.Insert(extractedPlace.BoundingEnvelope, extractedPlace);
                                    nextPlaceId++;
                                }
                            }
                        }
                    }
                }

                placeSpatialTree.Build();
            }, cancellationToken);

            Console.WriteLine(
                "[SearchDB] Pass 1 complete: indexed " + placeList.Count.ToString("N0", CultureInfo.InvariantCulture) +
                " municipalities/settlements and " + nodeCoordinateDictionary.Count.ToString("N0", CultureInfo.InvariantCulture) + " nodes."
            );

            // Pass 2: Extract streets (deduplicated per municipality) and POIs/addresses
            Console.WriteLine("[SearchDB] Pass 2/2: Extracting streets, house numbers, and POIs with spatial city assignment...");

            var streetDeduplicationDictionary = new Dictionary<string, StreetRecordModel>(StringComparer.OrdinalIgnoreCase);
            var poiList = new List<PoiRecordModel>();

            await Task.Run(() => {
                using var pbfStream = new FileStream(pbfFilePath, FileMode.Open, FileAccess.Read, FileShare.Read, 131072);
                var osmSource = new PBFOsmStreamSource(pbfStream);

                long nextStreetId = 1L;
                long nextPoiId = 1L;

                foreach (OsmGeo osmElement in osmSource) {
                    cancellationToken.ThrowIfCancellationRequested();
                    if ((osmElement.Tags == null) || (osmElement.Tags.Count == 0)) {
                        continue;
                    }

                    double elementLat = 0.0;
                    double elementLon = 0.0;
                    bool hasCoordinates = false;

                    if (osmElement.Type == OsmGeoType.Node) {
                        var nodeItem = (OsmSharp.Node)osmElement;
                        if (nodeItem.Latitude.HasValue && nodeItem.Longitude.HasValue) {
                            elementLat = nodeItem.Latitude.Value;
                            elementLon = nodeItem.Longitude.Value;
                            hasCoordinates = true;
                        }
                    }else if (osmElement.Type == OsmGeoType.Way) {
                        var wayItem = (OsmSharp.Way)osmElement;
                        hasCoordinates = TryComputeWayCentroid(wayItem, nodeCoordinateDictionary, out elementLat, out elementLon);
                    }

                    if (!hasCoordinates) {
                        continue;
                    }

                    // A. Check if element is a named street (Way with highway + name)
                    if (osmElement.Type == OsmGeoType.Way) {
                        string highwayValue = GetTagValue(osmElement.Tags, "highway");
                        string streetName = GetTagValue(osmElement.Tags, "name");

                        if ((!string.IsNullOrWhiteSpace(highwayValue)) && (!string.IsNullOrWhiteSpace(streetName)) && IsIndexableHighway(highwayValue)) {
                            string explicitCity = GetTagValue(osmElement.Tags, "addr:city");
                            string explicitPostcode = GetTagValue(osmElement.Tags, "addr:postcode");
                            AdminPlaceModel? nearestPlace = ResolveNearestPlace(placeSpatialTree, elementLat, elementLon);

                            string resolvedCityName = !string.IsNullOrWhiteSpace(explicitCity)
                                ? explicitCity
                                : ((nearestPlace != null) ? nearestPlace.Name : region.Name);

                            string resolvedPostcode = !string.IsNullOrWhiteSpace(explicitPostcode)
                                ? explicitPostcode
                                : ((nearestPlace != null) ? nearestPlace.Postcode : string.Empty);

                            long resolvedPlaceId = (nearestPlace != null) ? nearestPlace.Id : 0L;

                            string dedupKey = resolvedCityName.ToLowerInvariant() + "|" + streetName.ToLowerInvariant();
                            if (streetDeduplicationDictionary.TryGetValue(dedupKey, out StreetRecordModel? existingStreet)) {
                                existingStreet.SegmentCount++;
                            }else {
                                var newStreet = new StreetRecordModel {
                                    Id = nextStreetId,
                                    PlaceId = resolvedPlaceId,
                                    Name = streetName,
                                    CityName = resolvedCityName,
                                    Postcode = resolvedPostcode,
                                    Latitude = elementLat,
                                    Longitude = elementLon,
                                    SegmentCount = 1
                                };
                                streetDeduplicationDictionary[dedupKey] = newStreet;
                                nextStreetId++;
                            }
                        }
                    }

                    // B. Check if element is a POI or has an address house number
                    PoiRecordModel? poiRecord = TryExtractPoiOrAddress(
                        nextPoiId,
                        osmElement.Id ?? 0L,
                        elementLat,
                        elementLon,
                        osmElement.Tags,
                        placeSpatialTree,
                        region.Name
                    );

                    if (poiRecord != null) {
                        poiList.Add(poiRecord);
                        nextPoiId++;
                    }
                }
            }, cancellationToken);

            // Free node coordinate cache before SQLite bulk insert
            nodeCoordinateDictionary.Clear();
            nodeCoordinateDictionary.TrimExcess();
            GC.Collect(2, GCCollectionMode.Forced, true);

            Console.WriteLine(
                "[SearchDB] Writing " + placeList.Count.ToString("N0", CultureInfo.InvariantCulture) + " places, " +
                streetDeduplicationDictionary.Count.ToString("N0", CultureInfo.InvariantCulture) + " unique streets, and " +
                poiList.Count.ToString("N0", CultureInfo.InvariantCulture) + " POIs/addresses to SQLite (FTS5 + R-Tree)..."
            );

            await WriteSqliteDatabaseAsync(
                tempDbPath,
                placeList,
                new List<StreetRecordModel>(streetDeduplicationDictionary.Values),
                poiList,
                cancellationToken
            );

            if (File.Exists(outputDbPath)) {
                File.Delete(outputDbPath);
            }
            File.Move(tempDbPath, outputDbPath);

            Console.WriteLine("[SearchDB] Database ready: " + outputDbPath);
            return outputDbPath;
        }

        /// <summary>
        /// Creates the SQLite database tables, bulk inserts places, streets, and POIs, and populates the FTS5 and R-Tree virtual tables.
        /// </summary>
        private static async Task WriteSqliteDatabaseAsync(
            string databasePath,
            List<AdminPlaceModel> placeList,
            List<StreetRecordModel> streetList,
            List<PoiRecordModel> poiList,
            CancellationToken cancellationToken
        ) {
            string connectionString = new SqliteConnectionStringBuilder {
                DataSource = databasePath,
                Mode = SqliteOpenMode.ReadWriteCreate,
                Pooling = false
            }.ToString();

            await using var connection = new SqliteConnection(connectionString);
            await connection.OpenAsync(cancellationToken);

            // Configure high-speed bulk write pragmas
            await ExecuteSqlAsync(connection, "PRAGMA synchronous = OFF; PRAGMA journal_mode = MEMORY; PRAGMA temp_store = MEMORY;", cancellationToken);

            // Create relational tables, FTS5 full-text index, and R-Tree spatial index
            string schemaSql = @"
                CREATE TABLE places (
                    id INTEGER PRIMARY KEY,
                    osm_id INTEGER NOT NULL,
                    name TEXT NOT NULL,
                    place_type TEXT NOT NULL,
                    postcode TEXT,
                    admin_region TEXT,
                    latitude REAL NOT NULL,
                    longitude REAL NOT NULL,
                    population INTEGER DEFAULT 0
                );

                CREATE TABLE streets (
                    id INTEGER PRIMARY KEY,
                    place_id INTEGER,
                    name TEXT NOT NULL,
                    city_name TEXT NOT NULL,
                    postcode TEXT,
                    latitude REAL NOT NULL,
                    longitude REAL NOT NULL
                );

                CREATE TABLE pois (
                    id INTEGER PRIMARY KEY,
                    osm_id INTEGER NOT NULL,
                    category TEXT NOT NULL,
                    sub_category TEXT NOT NULL,
                    name TEXT NOT NULL,
                    street_name TEXT,
                    house_number TEXT,
                    city_name TEXT,
                    postcode TEXT,
                    phone TEXT,
                    website TEXT,
                    opening_hours TEXT,
                    latitude REAL NOT NULL,
                    longitude REAL NOT NULL
                );

                CREATE VIRTUAL TABLE search_fts USING fts5(
                    entity_type UNINDEXED,
                    entity_id UNINDEXED,
                    title,
                    subtitle,
                    tokens,
                    latitude UNINDEXED,
                    longitude UNINDEXED,
                    tokenize = 'unicode61 remove_diacritics 2'
                );

                CREATE VIRTUAL TABLE poi_rtree USING rtree(
                    id,
                    min_latitude,
                    max_latitude,
                    min_longitude,
                    max_longitude
                );
            ";
            await ExecuteSqlAsync(connection, schemaSql, cancellationToken);

            await using SqliteTransaction transaction = (SqliteTransaction)await connection.BeginTransactionAsync(cancellationToken);

            // 1. Insert Places + FTS5 entries
            using (var placeCmd = connection.CreateCommand())
            using (var ftsCmd = CreateFtsInsertCommand(connection, transaction)) {
                placeCmd.Transaction = transaction;
                placeCmd.CommandText = @"
                    INSERT INTO places (id, osm_id, name, place_type, postcode, admin_region, latitude, longitude, population)
                    VALUES ($id, $osmId, $name, $placeType, $postcode, $adminRegion, $lat, $lon, $pop);
                ";

                SqliteParameter idParam = placeCmd.Parameters.Add("$id", SqliteType.Integer);
                SqliteParameter osmIdParam = placeCmd.Parameters.Add("$osmId", SqliteType.Integer);
                SqliteParameter nameParam = placeCmd.Parameters.Add("$name", SqliteType.Text);
                SqliteParameter typeParam = placeCmd.Parameters.Add("$placeType", SqliteType.Text);
                SqliteParameter postcodeParam = placeCmd.Parameters.Add("$postcode", SqliteType.Text);
                SqliteParameter regionParam = placeCmd.Parameters.Add("$adminRegion", SqliteType.Text);
                SqliteParameter latParam = placeCmd.Parameters.Add("$lat", SqliteType.Real);
                SqliteParameter lonParam = placeCmd.Parameters.Add("$lon", SqliteType.Real);
                SqliteParameter popParam = placeCmd.Parameters.Add("$pop", SqliteType.Integer);

                foreach (AdminPlaceModel place in placeList) {
                    idParam.Value = place.Id;
                    osmIdParam.Value = place.OsmId;
                    nameParam.Value = place.Name;
                    typeParam.Value = place.PlaceType;
                    postcodeParam.Value = place.Postcode;
                    regionParam.Value = place.AdminRegion;
                    latParam.Value = place.Latitude;
                    lonParam.Value = place.Longitude;
                    popParam.Value = place.Population;
                    await placeCmd.ExecuteNonQueryAsync(cancellationToken);

                    await InsertFtsRowAsync(
                        ftsCmd,
                        "place",
                        place.Id,
                        place.Name,
                        place.AdminRegion,
                        place.Postcode,
                        place.Latitude,
                        place.Longitude,
                        cancellationToken
                    );
                }
            }

            // 2. Insert Streets + FTS5 entries
            using (var streetCmd = connection.CreateCommand())
            using (var ftsCmd = CreateFtsInsertCommand(connection, transaction)) {
                streetCmd.Transaction = transaction;
                streetCmd.CommandText = @"
                    INSERT INTO streets (id, place_id, name, city_name, postcode, latitude, longitude)
                    VALUES ($id, $placeId, $name, $cityName, $postcode, $lat, $lon);
                ";

                SqliteParameter idParam = streetCmd.Parameters.Add("$id", SqliteType.Integer);
                SqliteParameter placeIdParam = streetCmd.Parameters.Add("$placeId", SqliteType.Integer);
                SqliteParameter nameParam = streetCmd.Parameters.Add("$name", SqliteType.Text);
                SqliteParameter cityParam = streetCmd.Parameters.Add("$cityName", SqliteType.Text);
                SqliteParameter postcodeParam = streetCmd.Parameters.Add("$postcode", SqliteType.Text);
                SqliteParameter latParam = streetCmd.Parameters.Add("$lat", SqliteType.Real);
                SqliteParameter lonParam = streetCmd.Parameters.Add("$lon", SqliteType.Real);

                foreach (StreetRecordModel street in streetList) {
                    idParam.Value = street.Id;
                    placeIdParam.Value = street.PlaceId;
                    nameParam.Value = street.Name;
                    cityParam.Value = street.CityName;
                    postcodeParam.Value = street.Postcode;
                    latParam.Value = street.Latitude;
                    lonParam.Value = street.Longitude;
                    await streetCmd.ExecuteNonQueryAsync(cancellationToken);

                    await InsertFtsRowAsync(
                        ftsCmd,
                        "street",
                        street.Id,
                        street.Name,
                        street.CityName,
                        street.CityName + " " + street.Postcode,
                        street.Latitude,
                        street.Longitude,
                        cancellationToken
                    );
                }
            }

            // 3. Insert POIs + FTS5 + R-Tree entries
            using (var poiCmd = connection.CreateCommand())
            using (var rtreeCmd = connection.CreateCommand())
            using (var ftsCmd = CreateFtsInsertCommand(connection, transaction)) {
                poiCmd.Transaction = transaction;
                poiCmd.CommandText = @"
                    INSERT INTO pois (id, osm_id, category, sub_category, name, street_name, house_number, city_name, postcode, phone, website, opening_hours, latitude, longitude)
                    VALUES ($id, $osmId, $cat, $subCat, $name, $street, $houseNum, $city, $postcode, $phone, $web, $hours, $lat, $lon);
                ";

                SqliteParameter idParam = poiCmd.Parameters.Add("$id", SqliteType.Integer);
                SqliteParameter osmIdParam = poiCmd.Parameters.Add("$osmId", SqliteType.Integer);
                SqliteParameter catParam = poiCmd.Parameters.Add("$cat", SqliteType.Text);
                SqliteParameter subCatParam = poiCmd.Parameters.Add("$subCat", SqliteType.Text);
                SqliteParameter nameParam = poiCmd.Parameters.Add("$name", SqliteType.Text);
                SqliteParameter streetParam = poiCmd.Parameters.Add("$street", SqliteType.Text);
                SqliteParameter houseParam = poiCmd.Parameters.Add("$houseNum", SqliteType.Text);
                SqliteParameter cityParam = poiCmd.Parameters.Add("$city", SqliteType.Text);
                SqliteParameter postcodeParam = poiCmd.Parameters.Add("$postcode", SqliteType.Text);
                SqliteParameter phoneParam = poiCmd.Parameters.Add("$phone", SqliteType.Text);
                SqliteParameter webParam = poiCmd.Parameters.Add("$web", SqliteType.Text);
                SqliteParameter hoursParam = poiCmd.Parameters.Add("$hours", SqliteType.Text);
                SqliteParameter latParam = poiCmd.Parameters.Add("$lat", SqliteType.Real);
                SqliteParameter lonParam = poiCmd.Parameters.Add("$lon", SqliteType.Real);

                rtreeCmd.Transaction = transaction;
                rtreeCmd.CommandText = @"
                    INSERT INTO poi_rtree (id, min_latitude, max_latitude, min_longitude, max_longitude)
                    VALUES ($id, $minLat, $maxLat, $minLon, $maxLon);
                ";
                SqliteParameter rtreeIdParam = rtreeCmd.Parameters.Add("$id", SqliteType.Integer);
                SqliteParameter rtreeMinLatParam = rtreeCmd.Parameters.Add("$minLat", SqliteType.Real);
                SqliteParameter rtreeMaxLatParam = rtreeCmd.Parameters.Add("$maxLat", SqliteType.Real);
                SqliteParameter rtreeMinLonParam = rtreeCmd.Parameters.Add("$minLon", SqliteType.Real);
                SqliteParameter rtreeMaxLonParam = rtreeCmd.Parameters.Add("$maxLon", SqliteType.Real);

                foreach (PoiRecordModel poi in poiList) {
                    idParam.Value = poi.Id;
                    osmIdParam.Value = poi.OsmId;
                    catParam.Value = poi.Category;
                    subCatParam.Value = poi.SubCategory;
                    nameParam.Value = poi.Name;
                    streetParam.Value = poi.StreetName;
                    houseParam.Value = poi.HouseNumber;
                    cityParam.Value = poi.CityName;
                    postcodeParam.Value = poi.Postcode;
                    phoneParam.Value = poi.Phone;
                    webParam.Value = poi.Website;
                    hoursParam.Value = poi.OpeningHours;
                    latParam.Value = poi.Latitude;
                    lonParam.Value = poi.Longitude;
                    await poiCmd.ExecuteNonQueryAsync(cancellationToken);

                    rtreeIdParam.Value = poi.Id;
                    rtreeMinLatParam.Value = poi.Latitude;
                    rtreeMaxLatParam.Value = poi.Latitude;
                    rtreeMinLonParam.Value = poi.Longitude;
                    rtreeMaxLonParam.Value = poi.Longitude;
                    await rtreeCmd.ExecuteNonQueryAsync(cancellationToken);

                    string subtitleText = string.IsNullOrWhiteSpace(poi.StreetName)
                        ? poi.CityName
                        : (poi.StreetName + " " + poi.HouseNumber).Trim() + ", " + poi.CityName;

                    string tokenText = poi.Category + " " + poi.SubCategory + " " + poi.StreetName + " " + poi.HouseNumber + " " + poi.CityName + " " + poi.Postcode;

                    await InsertFtsRowAsync(
                        ftsCmd,
                        "poi",
                        poi.Id,
                        poi.Name,
                        subtitleText,
                        tokenText,
                        poi.Latitude,
                        poi.Longitude,
                        cancellationToken
                    );
                }
            }

            await transaction.CommitAsync(cancellationToken);

            // Create standard B-Tree indexes and compact database
            await ExecuteSqlAsync(
                connection,
                "CREATE INDEX idx_places_name ON places(name); " +
                "CREATE INDEX idx_streets_city ON streets(city_name, name); " +
                "CREATE INDEX idx_pois_category ON pois(category, sub_category); " +
                "INSERT INTO search_fts(search_fts) VALUES('optimize'); " +
                "PRAGMA optimize; " +
                "VACUUM;",
                cancellationToken
            );
        }

        private static SqliteCommand CreateFtsInsertCommand(SqliteConnection connection, SqliteTransaction transaction) {
            SqliteCommand command = connection.CreateCommand();
            command.Transaction = transaction;
            command.CommandText = @"
                INSERT INTO search_fts (entity_type, entity_id, title, subtitle, tokens, latitude, longitude)
                VALUES ($type, $id, $title, $subtitle, $tokens, $lat, $lon);
            ";
            command.Parameters.Add("$type", SqliteType.Text);
            command.Parameters.Add("$id", SqliteType.Integer);
            command.Parameters.Add("$title", SqliteType.Text);
            command.Parameters.Add("$subtitle", SqliteType.Text);
            command.Parameters.Add("$tokens", SqliteType.Text);
            command.Parameters.Add("$lat", SqliteType.Real);
            command.Parameters.Add("$lon", SqliteType.Real);
            return command;
        }

        private static async Task InsertFtsRowAsync(
            SqliteCommand ftsCommand,
            string entityType,
            long entityId,
            string title,
            string subtitle,
            string tokens,
            double latitude,
            double longitude,
            CancellationToken cancellationToken
        ) {
            ftsCommand.Parameters["$type"].Value = entityType;
            ftsCommand.Parameters["$id"].Value = entityId;
            ftsCommand.Parameters["$title"].Value = title;
            ftsCommand.Parameters["$subtitle"].Value = subtitle;
            ftsCommand.Parameters["$tokens"].Value = tokens;
            ftsCommand.Parameters["$lat"].Value = latitude;
            ftsCommand.Parameters["$lon"].Value = longitude;
            await ftsCommand.ExecuteNonQueryAsync(cancellationToken);
        }

        private static AdminPlaceModel? TryExtractPlaceFromTags(
            long id,
            long osmId,
            double latitude,
            double longitude,
            TagsCollectionBase tags
        ) {
            string placeType = GetTagValue(tags, "place");
            if (string.IsNullOrWhiteSpace(placeType)) {
                return null;
            }

            if ((placeType != "city") &&
                (placeType != "town") &&
                (placeType != "village") &&
                (placeType != "municipality") &&
                (placeType != "hamlet") &&
                (placeType != "suburb")) {
                return null;
            }

            string name = GetTagValue(tags, "name");
            if (string.IsNullOrWhiteSpace(name)) {
                return null;
            }

            int population = 0;
            string popText = GetTagValue(tags, "population");
            if (!string.IsNullOrWhiteSpace(popText)) {
                int.TryParse(popText, NumberStyles.Integer, CultureInfo.InvariantCulture, out population);
            }

            var envelope = new Envelope(
                longitude - SearchEnvelopeRadiusDegrees,
                longitude + SearchEnvelopeRadiusDegrees,
                latitude - SearchEnvelopeRadiusDegrees,
                latitude + SearchEnvelopeRadiusDegrees
            );

            return new AdminPlaceModel {
                Id = id,
                OsmId = osmId,
                Name = name,
                PlaceType = placeType,
                Postcode = GetTagValue(tags, "postal_code", "addr:postcode"),
                AdminRegion = GetTagValue(tags, "is_in:province", "addr:province"),
                Latitude = latitude,
                Longitude = longitude,
                Population = population,
                BoundingEnvelope = envelope
            };
        }

        private static PoiRecordModel? TryExtractPoiOrAddress(
            long id,
            long osmId,
            double latitude,
            double longitude,
            TagsCollectionBase tags,
            STRtree<AdminPlaceModel> placeSpatialTree,
            string fallbackRegionName
        ) {
            string amenity = GetTagValue(tags, "amenity");
            string tourism = GetTagValue(tags, "tourism");
            string shop = GetTagValue(tags, "shop");
            string natural = GetTagValue(tags, "natural");
            string mountainPass = GetTagValue(tags, "mountain_pass");
            string highway = GetTagValue(tags, "highway");

            string category = string.Empty;
            string subCategory = string.Empty;

            if (!string.IsNullOrWhiteSpace(amenity)) {
                category = "amenity";
                subCategory = amenity;
            }else if (!string.IsNullOrWhiteSpace(tourism)) {
                category = "tourism";
                subCategory = tourism;
            }else if (!string.IsNullOrWhiteSpace(shop)) {
                category = "shop";
                subCategory = shop;
            }else if (mountainPass == "yes") {
                category = "alpine";
                subCategory = "mountain_pass";
            }else if ((natural == "peak") || (natural == "saddle") || (natural == "spring")) {
                category = "natural";
                subCategory = natural;
            }else if ((highway == "services") || (highway == "rest_area")) {
                category = "highway";
                subCategory = highway;
            }

            string streetName = GetTagValue(tags, "addr:street");
            string houseNumber = GetTagValue(tags, "addr:housenumber");
            string name = GetTagValue(tags, "name");

            bool isAddressOnly = string.IsNullOrWhiteSpace(category) &&
                (!string.IsNullOrWhiteSpace(streetName)) &&
                (!string.IsNullOrWhiteSpace(houseNumber));

            if (isAddressOnly) {
                category = "address";
                subCategory = "housenumber";
                if (string.IsNullOrWhiteSpace(name)) {
                    name = streetName + " " + houseNumber;
                }
            }

            if (string.IsNullOrWhiteSpace(category) || string.IsNullOrWhiteSpace(name)) {
                return null;
            }

            string explicitCity = GetTagValue(tags, "addr:city");
            string explicitPostcode = GetTagValue(tags, "addr:postcode");
            AdminPlaceModel? nearestPlace = ResolveNearestPlace(placeSpatialTree, latitude, longitude);

            string resolvedCity = !string.IsNullOrWhiteSpace(explicitCity)
                ? explicitCity
                : ((nearestPlace != null) ? nearestPlace.Name : fallbackRegionName);

            string resolvedPostcode = !string.IsNullOrWhiteSpace(explicitPostcode)
                ? explicitPostcode
                : ((nearestPlace != null) ? nearestPlace.Postcode : string.Empty);

            return new PoiRecordModel {
                Id = id,
                OsmId = osmId,
                Category = category,
                SubCategory = subCategory,
                Name = name,
                StreetName = streetName,
                HouseNumber = houseNumber,
                CityName = resolvedCity,
                Postcode = resolvedPostcode,
                Phone = GetTagValue(tags, "phone", "contact:phone"),
                Website = GetTagValue(tags, "website", "contact:website"),
                OpeningHours = GetTagValue(tags, "opening_hours"),
                Latitude = latitude,
                Longitude = longitude
            };
        }

        /// <summary>
        /// Queries the in-memory STRtree spatial index to find the closest municipality/settlement to the given coordinates.
        /// </summary>
        private static AdminPlaceModel? ResolveNearestPlace(
            STRtree<AdminPlaceModel> placeSpatialTree,
            double latitude,
            double longitude
        ) {
            var queryEnvelope = new Envelope(longitude, longitude, latitude, latitude);
            IList<AdminPlaceModel> candidateList = placeSpatialTree.Query(queryEnvelope);
            if ((candidateList == null) || (candidateList.Count == 0)) {
                return null;
            }

            AdminPlaceModel? bestCandidate = null;
            double bestDistanceSquared = double.MaxValue;

            foreach (AdminPlaceModel candidate in candidateList) {
                double deltaLat = candidate.Latitude - latitude;
                double deltaLon = candidate.Longitude - longitude;
                double distSq = (deltaLat * deltaLat) + (deltaLon * deltaLon);

                // Slightly weight cities/towns over tiny hamlets when distances are comparable
                if ((candidate.PlaceType == "city") || (candidate.PlaceType == "town") || (candidate.PlaceType == "municipality")) {
                    distSq *= 0.65;
                }

                if (distSq < bestDistanceSquared) {
                    bestDistanceSquared = distSq;
                    bestCandidate = candidate;
                }
            }

            return bestCandidate;
        }

        private static bool TryComputeWayCentroid(
            OsmSharp.Way wayItem,
            Dictionary<long, (float Latitude, float Longitude)> nodeCoordinateDictionary,
            out double centroidLat,
            out double centroidLon
        ) {
            centroidLat = 0.0;
            centroidLon = 0.0;

            if ((wayItem.Nodes == null) || (wayItem.Nodes.Length == 0)) {
                return false;
            }

            int midIndex = wayItem.Nodes.Length / 2;
            long midNodeId = wayItem.Nodes[midIndex];
            if (nodeCoordinateDictionary.TryGetValue(midNodeId, out (float Latitude, float Longitude) midCoord)) {
                centroidLat = midCoord.Latitude;
                centroidLon = midCoord.Longitude;
                return true;
            }

            long firstNodeId = wayItem.Nodes[0];
            if (nodeCoordinateDictionary.TryGetValue(firstNodeId, out (float Latitude, float Longitude) firstCoord)) {
                centroidLat = firstCoord.Latitude;
                centroidLon = firstCoord.Longitude;
                return true;
            }

            long lastNodeId = wayItem.Nodes[wayItem.Nodes.Length - 1];
            if (nodeCoordinateDictionary.TryGetValue(lastNodeId, out (float Latitude, float Longitude) lastCoord)) {
                centroidLat = lastCoord.Latitude;
                centroidLon = lastCoord.Longitude;
                return true;
            }

            return false;
        }

        private static bool IsIndexableHighway(string highwayType) {
            return (highwayType == "residential") ||
                (highwayType == "Primary") ||
                (highwayType == "primary") ||
                (highwayType == "secondary") ||
                (highwayType == "tertiary") ||
                (highwayType == "unclassified") ||
                (highwayType == "living_street") ||
                (highwayType == "pedestrian") ||
                (highwayType == "trunk");
        }

        private static string GetTagValue(TagsCollectionBase tags, string primaryKey, string? fallbackKey = null) {
            if (tags.TryGetValue(primaryKey, out string? primaryValue) && (!string.IsNullOrWhiteSpace(primaryValue))) {
                return primaryValue.Trim();
            }
            if ((!string.IsNullOrWhiteSpace(fallbackKey)) && tags.TryGetValue(fallbackKey, out string? fallbackValue) && (!string.IsNullOrWhiteSpace(fallbackValue))) {
                return fallbackValue.Trim();
            }
            return string.Empty;
        }

        private static async Task ExecuteSqlAsync(SqliteConnection connection, string sqlText, CancellationToken cancellationToken) {
            using var command = connection.CreateCommand();
            command.CommandText = sqlText;
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
    }
}
