using NaRotta.MapBuilder.Core.Models;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Services {
    /// <summary>
    /// Service that queries OpenStreetMap/Geofabrik servers to detect upstream updates and compare them against local builds.
    /// </summary>
    public class OsmUpdateCheckerService {
        private readonly HttpClient _httpClient;
        private readonly GeofabrikCatalogService _catalogService;

        public OsmUpdateCheckerService(HttpClient httpClient, GeofabrikCatalogService catalogService) {
            _httpClient = httpClient;
            _catalogService = catalogService;
        }

        /// <summary>
        /// Checks a single region for updates by inspecting local manifest artifacts and upstream Geofabrik metadata.
        /// </summary>
        public async Task<OsmRegionUpdateModel> CheckRegionUpdateAsync(
            GeofabrikRegionModel region,
            string outputDirectory,
            CancellationToken cancellationToken
        ) {
            var resultModel = new OsmRegionUpdateModel {
                RegionId = region.Id,
                RegionName = region.Name,
                ParentId = region.ParentId,
                RemotePbfUrl = region.PbfUrl,
                Status = OsmUpdateStatus.Checking
            };

            // Step 1: Check local manifest in outputDirectory
            string manifestPath = Path.Combine(outputDirectory, "manifest.json");
            DateTime? localLastBuiltUtc = null;
            long localTotalSizeBytes = 0;

            if (File.Exists(manifestPath)) {
                try {
                    string manifestJson = await File.ReadAllTextAsync(manifestPath, cancellationToken);
                    using var jsonDocument = JsonDocument.Parse(manifestJson);
                    JsonElement rootElement = jsonDocument.RootElement;

                    if (rootElement.TryGetProperty("generated_at", out JsonElement genElement)) {
                        if (DateTime.TryParse(genElement.GetString(), out DateTime parsedGen)) {
                            localLastBuiltUtc = parsedGen;
                        }
                    }

                    if (rootElement.TryGetProperty("regions", out JsonElement regionsElement) && (regionsElement.ValueKind == JsonValueKind.Array)) {
                        foreach (JsonElement regionElement in regionsElement.EnumerateArray()) {
                            string? regionId = regionElement.TryGetProperty("id", out JsonElement idElement) ? idElement.GetString() : null;
                            if (string.Equals(regionId, region.Id, StringComparison.OrdinalIgnoreCase) ||
                                string.Equals(regionId, region.GetFileSlug(), StringComparison.OrdinalIgnoreCase)) {
                                
                                if (regionElement.TryGetProperty("search", out JsonElement searchElement)) {
                                    if (searchElement.TryGetProperty("size_bytes", out JsonElement searchSize)) {
                                        localTotalSizeBytes += searchSize.GetInt64();
                                    }
                                }

                                if (regionElement.TryGetProperty("layers", out JsonElement layersElement)) {
                                    foreach (JsonProperty layerProp in layersElement.EnumerateObject()) {
                                        if (layerProp.Value.TryGetProperty("tiles_size_bytes", out JsonElement tilesSize)) {
                                            localTotalSizeBytes += tilesSize.GetInt64();
                                        }
                                        if (layerProp.Value.TryGetProperty("routing_size_bytes", out JsonElement routingSize)) {
                                            localTotalSizeBytes += routingSize.GetInt64();
                                        }
                                    }
                                }
                                break;
                            }
                        }
                    }
                }catch {
                    // Fall back if manifest cannot be read
                }
            }

            resultModel.LocalLastBuiltUtc = localLastBuiltUtc;
            resultModel.LocalTotalSizeBytes = (localTotalSizeBytes > 0) ? localTotalSizeBytes : null;

            // Step 2: Query remote Geofabrik PBF header
            if (string.IsNullOrEmpty(region.PbfUrl)) {
                resultModel.Status = OsmUpdateStatus.CheckFailed;
                resultModel.StatusMessage = "No PBF URL configured for region";
                return resultModel;
            }

            try {
                using var request = new HttpRequestMessage(HttpMethod.Head, region.PbfUrl);
                using HttpResponseMessage response = await _httpClient.SendAsync(
                    request,
                    HttpCompletionOption.ResponseHeadersRead,
                    cancellationToken
                );

                if (response.IsSuccessStatusCode) {
                    if (response.Content.Headers.LastModified.HasValue) {
                        resultModel.RemoteLastModifiedUtc = response.Content.Headers.LastModified.Value.UtcDateTime;
                    }

                    if (response.Content.Headers.ContentLength.HasValue) {
                        resultModel.RemoteSizeBytes = response.Content.Headers.ContentLength.Value;
                    }

                    if (localLastBuiltUtc == null) {
                        resultModel.Status = OsmUpdateStatus.NotBuiltYet;
                        resultModel.StatusMessage = "Region not built yet (remote available: " + (resultModel.RemoteLastModifiedUtc?.ToString("yyyy-MM-dd") ?? "unknown") + ")";
                    }else if ((resultModel.RemoteLastModifiedUtc.HasValue) && (resultModel.RemoteLastModifiedUtc.Value > localLastBuiltUtc.Value.AddHours(6.0))) {
                        resultModel.Status = OsmUpdateStatus.UpdateAvailable;
                        TimeSpan difference = resultModel.RemoteLastModifiedUtc.Value - localLastBuiltUtc.Value;
                        resultModel.StatusMessage = "Update available! Upstream is " + Math.Round(difference.TotalDays, 0).ToString() + " days newer";
                    }else {
                        resultModel.Status = OsmUpdateStatus.UpToDate;
                        resultModel.StatusMessage = "Up to date with OpenStreetMap";
                    }
                }else {
                    resultModel.Status = OsmUpdateStatus.CheckFailed;
                    resultModel.StatusMessage = "HTTP " + ((int)response.StatusCode).ToString() + " " + response.ReasonPhrase;
                }
            }catch (Exception exception) {
                resultModel.Status = OsmUpdateStatus.CheckFailed;
                resultModel.StatusMessage = "Failed to query Geofabrik: " + exception.Message;
            }

            return resultModel;
        }

        /// <summary>
        /// Checks a batch of regions in parallel, returning the update status for each.
        /// </summary>
        public async Task<List<OsmRegionUpdateModel>> CheckBatchUpdatesAsync(
            List<GeofabrikRegionModel> regionList,
            string outputDirectory,
            int maxConcurrency,
            CancellationToken cancellationToken
        ) {
            var updateResultList = new ConcurrentBag<OsmRegionUpdateModel>();
            using var throttler = new SemaphoreSlim(maxConcurrency, maxConcurrency);

            var taskList = new List<Task>();
            foreach (GeofabrikRegionModel region in regionList) {
                taskList.Add(Task.Run(async () => {
                    try {
                        await throttler.WaitAsync(cancellationToken);
                        try {
                            OsmRegionUpdateModel result = await CheckRegionUpdateAsync(region, outputDirectory, cancellationToken);
                            updateResultList.Add(result);
                        }finally {
                            throttler.Release();
                        }
                    }catch (OperationCanceledException) {
                        // Request cancelled cleanly, ignore task
                    }
                }, cancellationToken));
            }

            try {
                await Task.WhenAll(taskList);
            }catch (OperationCanceledException) {
                // Request cancelled cleanly
            }
            return updateResultList.OrderBy((OsmRegionUpdateModel item) => item.RegionId).ToList();
        }
    }
}
