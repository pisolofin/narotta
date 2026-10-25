using NaRotta.MapBuilder.Core.Models;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Services {
    /// <summary>
    /// Downloads and decompresses 1x1 degree SRTM/Skadi (.hgt) digital elevation model tiles for terrain and Valhalla routing slopes.
    /// </summary>
    public class DemElevationService {
        private const string SkadiElevationBaseUrl = "https://s3.amazonaws.com/elevation-tiles-prod/skadi";

        private readonly HttpClient _httpClient;

        public DemElevationService(HttpClient httpClient) {
            _httpClient = httpClient;
        }

        /// <summary>
        /// Ensures all 1x1 degree .hgt elevation files covering the region's bounding box are downloaded in workspace/elevation.
        /// </summary>
        public async Task<string> EnsureElevationTilesAsync(
            GeofabrikRegionModel region,
            string workspaceDirectory,
            CancellationToken cancellationToken
        ) {
            string elevationRootDirectory = Path.Combine(workspaceDirectory, "elevation");
            Directory.CreateDirectory(elevationRootDirectory);

            if ((region.BoundingBoxList == null) || (region.BoundingBoxList.Count < 4)) {
                return elevationRootDirectory;
            }

            int minLonFloor = (int)Math.Floor(region.BoundingBoxList[0]);
            int minLatFloor = (int)Math.Floor(region.BoundingBoxList[1]);
            int maxLonFloor = (int)Math.Floor(region.BoundingBoxList[2]);
            int maxLatFloor = (int)Math.Floor(region.BoundingBoxList[3]);

            var tileCoordList = new List<(int Latitude, int Longitude)>();
            for (int latitude = minLatFloor; latitude <= maxLatFloor; latitude++) {
                for (int longitude = minLonFloor; longitude <= maxLonFloor; longitude++) {
                    tileCoordList.Add((latitude, longitude));
                }
            }

            Console.WriteLine(
                "[Elevation] Checking " + tileCoordList.Count.ToString(CultureInfo.InvariantCulture) +
                " SRTM DEM (.hgt) cells for region '" + region.Id + "'..."
            );

            int downloadedCount = 0;
            int cachedCount = 0;

            int totalCellCount = tileCoordList.Count;
            int processedCellCount = 0;
            DateTime lastLogTime = DateTime.UtcNow;

            foreach ((int Latitude, int Longitude) tileCoord in tileCoordList) {
                processedCellCount++;
                string latitudePrefix = (tileCoord.Latitude >= 0) ? "N" : "S";
                string longitudePrefix = (tileCoord.Longitude >= 0) ? "E" : "W";

                int absLatitude = Math.Abs(tileCoord.Latitude);
                int absLongitude = Math.Abs(tileCoord.Longitude);

                string latitudeBand = latitudePrefix + absLatitude.ToString("D2", CultureInfo.InvariantCulture);
                string hgtFileName = latitudeBand + longitudePrefix + absLongitude.ToString("D3", CultureInfo.InvariantCulture) + ".hgt";

                string bandDirectory = Path.Combine(elevationRootDirectory, latitudeBand);
                Directory.CreateDirectory(bandDirectory);

                string localHgtPath = Path.Combine(bandDirectory, hgtFileName);
                if (File.Exists(localHgtPath) && (new FileInfo(localHgtPath).Length > 0L)) {
                    cachedCount++;
                }else {
                    string remoteUrl = SkadiElevationBaseUrl + "/" + latitudeBand + "/" + hgtFileName + ".gz";
                    bool isSuccess = await DownloadAndDecompressHgtAsync(remoteUrl, localHgtPath, cancellationToken);
                    if (isSuccess) {
                        downloadedCount++;
                    }
                }

                if (((processedCellCount % 500) == 0) || ((DateTime.UtcNow - lastLogTime).TotalSeconds >= 10.0)) {
                    double percentage = (processedCellCount * 100.0) / totalCellCount;
                    Console.WriteLine(string.Format(
                        CultureInfo.InvariantCulture,
                        "[Elevation] {0}: {1:N0} / {2:N0} cells checked ({3:F1}%) - {4} downloaded, {5} cached",
                        region.GetFileSlug(),
                        processedCellCount,
                        totalCellCount,
                        percentage,
                        downloadedCount,
                        cachedCount
                    ));
                    lastLogTime = DateTime.UtcNow;
                }
            }

            Console.WriteLine(
                "[Elevation] Ready: " + cachedCount.ToString(CultureInfo.InvariantCulture) +
                " cached, " + downloadedCount.ToString(CultureInfo.InvariantCulture) + " newly downloaded."
            );

            return elevationRootDirectory;
        }

        /// <summary>
        /// Downloads a gzipped .hgt.gz file from the elevation mirror and decompresses it to disk.
        /// </summary>
        private async Task<bool> DownloadAndDecompressHgtAsync(
            string remoteGzUrl,
            string destinationHgtPath,
            CancellationToken cancellationToken
        ) {
            string tempPath = destinationHgtPath + ".tmp";
            try {
                using HttpResponseMessage response = await _httpClient.GetAsync(
                    remoteGzUrl,
                    HttpCompletionOption.ResponseHeadersRead,
                    cancellationToken
                );

                if (!response.IsSuccessStatusCode) {
                    // Ocean tiles do not exist in SRTM and return 404
                    return false;
                }

                await using (Stream networkStream = await response.Content.ReadAsStreamAsync(cancellationToken)) {
                    await using var gzipStream = new GZipStream(networkStream, CompressionMode.Decompress);
                    await using var outputStream = new FileStream(tempPath, FileMode.Create, FileAccess.Write, FileShare.None, 65536, true);
                    await gzipStream.CopyToAsync(outputStream, cancellationToken);
                }

                if (File.Exists(destinationHgtPath)) {
                    File.Delete(destinationHgtPath);
                }
                File.Move(tempPath, destinationHgtPath);
                return true;
            }catch (Exception) {
                if (File.Exists(tempPath)) {
                    File.Delete(tempPath);
                }
                return false;
            }
        }
    }
}
