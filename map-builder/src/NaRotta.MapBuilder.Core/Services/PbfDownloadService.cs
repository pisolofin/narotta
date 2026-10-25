using NaRotta.MapBuilder.Core.Models;
using System;
using System.Globalization;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Services {
    /// <summary>
    /// Downloads OpenStreetMap .osm.pbf files from Geofabrik with HTTP Range resume and MD5 integrity verification.
    /// </summary>
    public class PbfDownloadService {
        private const int DownloadBufferSizeBytes = 131072; // 128 KB buffer

        private readonly HttpClient _httpClient;

        public PbfDownloadService(HttpClient httpClient) {
            _httpClient = httpClient;
        }

        /// <summary>
        /// Downloads the .osm.pbf extract for the given region if not already cached and verified.
        /// </summary>
        public async Task<string> EnsurePbfDownloadedAsync(
            GeofabrikRegionModel region,
            string workspaceDirectory,
            bool forceDownload,
            CancellationToken cancellationToken
        ) {
            if (string.IsNullOrWhiteSpace(region.PbfUrl)) {
                throw new InvalidOperationException("Region '" + region.Id + "' does not have a valid .osm.pbf URL.");
            }

            string pbfDirectory = Path.Combine(workspaceDirectory, "pbf");
            Directory.CreateDirectory(pbfDirectory);

            string fileSlug = region.GetFileSlug();
            string targetPbfPath = Path.Combine(pbfDirectory, fileSlug + "-latest.osm.pbf");
            string partialPbfPath = targetPbfPath + ".part";

            // Fetch remote MD5 hash if available
            string expectedMd5Hash = await FetchExpectedMd5Async(region.Md5Url, cancellationToken);

            // Check if local file already exists and matches remote MD5
            if ((!forceDownload) && File.Exists(targetPbfPath)) {
                if (string.IsNullOrWhiteSpace(expectedMd5Hash)) {
                    Console.WriteLine("[Download] Existing PBF found at " + targetPbfPath + " (skipping download).");
                    return targetPbfPath;
                }

                string existingMd5 = await ComputeFileMd5Async(targetPbfPath, cancellationToken);
                if (string.Equals(existingMd5, expectedMd5Hash, StringComparison.OrdinalIgnoreCase)) {
                    Console.WriteLine("[Download] Cached PBF verified via MD5 (" + expectedMd5Hash + "): " + targetPbfPath);
                    return targetPbfPath;
                }

                Console.WriteLine("[Download] Cached PBF MD5 mismatch (local: " + existingMd5 + ", remote: " + expectedMd5Hash + "). Re-downloading...");
            }

            if (forceDownload && File.Exists(partialPbfPath)) {
                File.Delete(partialPbfPath);
            }

            // Perform resumable HTTP download with exponential backoff retry on transient errors
            const int maxRetryCount = 8;
            int attemptIndex = 0;
            while (true) {
                attemptIndex++;
                cancellationToken.ThrowIfCancellationRequested();

                try {
                    long existingByteCount = File.Exists(partialPbfPath) ? new FileInfo(partialPbfPath).Length : 0L;
                    using var requestMessage = new HttpRequestMessage(HttpMethod.Get, region.PbfUrl);
                    if (existingByteCount > 0L) {
                        requestMessage.Headers.Range = new RangeHeaderValue(existingByteCount, null);
                        Console.WriteLine("[Download] Resuming download from byte " + existingByteCount.ToString("N0", CultureInfo.InvariantCulture) + "...");
                    }else {
                        Console.WriteLine("[Download] Starting download: " + region.PbfUrl);
                    }

                    using HttpResponseMessage response = await _httpClient.SendAsync(
                        requestMessage,
                        HttpCompletionOption.ResponseHeadersRead,
                        cancellationToken
                    );

                    if (!response.IsSuccessStatusCode) {
                        int statusCodeNumber = (int)response.StatusCode;
                        bool isTransient = (statusCodeNumber == 502) || (statusCodeNumber == 503) || (statusCodeNumber == 504) || (statusCodeNumber == 429) || (statusCodeNumber == 500);
                        if (isTransient && (attemptIndex < maxRetryCount)) {
                            int delaySeconds = (int)Math.Min(120, Math.Pow(2, attemptIndex) * 2);
                            Console.WriteLine(
                                "[Download] Transient HTTP " + statusCodeNumber.ToString(CultureInfo.InvariantCulture) +
                                " (" + response.ReasonPhrase + ") on " + region.PbfUrl +
                                ". Retrying in " + delaySeconds.ToString(CultureInfo.InvariantCulture) +
                                "s (attempt " + attemptIndex.ToString(CultureInfo.InvariantCulture) + "/" + maxRetryCount.ToString(CultureInfo.InvariantCulture) + ")..."
                            );
                            await Task.Delay(TimeSpan.FromSeconds(delaySeconds), cancellationToken);
                            continue;
                        }

                        response.EnsureSuccessStatusCode();
                    }

                    bool isPartialContent = (response.StatusCode == HttpStatusCode.PartialContent);
                    if ((!isPartialContent) && (existingByteCount > 0L)) {
                        existingByteCount = 0L;
                    }

                    long? contentLength = response.Content.Headers.ContentLength;
                    long totalExpectedBytes = contentLength.HasValue ? (existingByteCount + contentLength.Value) : -1L;

                    FileMode fileMode = isPartialContent ? FileMode.Append : FileMode.Create;
                    await using (var fileStream = new FileStream(partialPbfPath, fileMode, FileAccess.Write, FileShare.None, DownloadBufferSizeBytes, true)) {
                        await using Stream networkStream = await response.Content.ReadAsStreamAsync(cancellationToken);

                        byte[] bufferList = new byte[DownloadBufferSizeBytes];
                        long totalBytesRead = existingByteCount;
                        DateTime lastLogTime = DateTime.UtcNow;

                        while (true) {
                            int bytesRead = await networkStream.ReadAsync(bufferList, 0, bufferList.Length, cancellationToken);
                            if (bytesRead <= 0) {
                                break;
                            }

                            await fileStream.WriteAsync(bufferList, 0, bytesRead, cancellationToken);
                            totalBytesRead += bytesRead;

                            if ((DateTime.UtcNow - lastLogTime).TotalSeconds >= 2.0) {
                                PrintProgress(fileSlug, totalBytesRead, totalExpectedBytes);
                                lastLogTime = DateTime.UtcNow;
                            }
                        }

                        PrintProgress(fileSlug, totalBytesRead, totalExpectedBytes);
                    }

                    // Download completed successfully
                    break;
                }catch (Exception exception) when (((exception is HttpRequestException) || (exception is IOException)) && (!(exception is OperationCanceledException))) {
                    if (attemptIndex >= maxRetryCount) {
                        throw;
                    }

                    int delaySeconds = (int)Math.Min(120, Math.Pow(2, attemptIndex) * 2);
                    Console.WriteLine(
                        "[Download] Transient network error (" + exception.Message + ") on " + region.PbfUrl +
                        ". Retrying in " + delaySeconds.ToString(CultureInfo.InvariantCulture) +
                        "s (attempt " + attemptIndex.ToString(CultureInfo.InvariantCulture) + "/" + maxRetryCount.ToString(CultureInfo.InvariantCulture) + ")..."
                    );
                    await Task.Delay(TimeSpan.FromSeconds(delaySeconds), cancellationToken);
                }
            }

            // Verify MD5 checksum of the downloaded file
            if (!string.IsNullOrWhiteSpace(expectedMd5Hash)) {
                Console.WriteLine("[Download] Verifying MD5 checksum...");
                string downloadedMd5 = await ComputeFileMd5Async(partialPbfPath, cancellationToken);
                if (!string.Equals(downloadedMd5, expectedMd5Hash, StringComparison.OrdinalIgnoreCase)) {
                    throw new InvalidDataException(
                        "MD5 checksum verification failed for " + partialPbfPath +
                        ". Expected: " + expectedMd5Hash + ", Actual: " + downloadedMd5
                    );
                }
                Console.WriteLine("[Download] MD5 checksum verified: " + downloadedMd5);
            }

            if (File.Exists(targetPbfPath)) {
                File.Delete(targetPbfPath);
            }
            File.Move(partialPbfPath, targetPbfPath);

            return targetPbfPath;
        }

        /// <summary>
        /// Downloads and parses the remote .md5 file from Geofabrik.
        /// </summary>
        private async Task<string> FetchExpectedMd5Async(string md5Url, CancellationToken cancellationToken) {
            if (string.IsNullOrWhiteSpace(md5Url)) {
                return string.Empty;
            }

            try {
                using HttpResponseMessage response = await _httpClient.GetAsync(md5Url, cancellationToken);
                if (!response.IsSuccessStatusCode) {
                    return string.Empty;
                }

                string rawText = await response.Content.ReadAsStringAsync(cancellationToken);
                if (string.IsNullOrWhiteSpace(rawText)) {
                    return string.Empty;
                }

                string[] tokenList = rawText.Trim().Split(new char[] { ' ', '\t', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
                if (tokenList.Length > 0) {
                    return tokenList[0].Trim().ToLowerInvariant();
                }
            }catch (Exception) {
                // Ignore MD5 fetch failure and proceed without remote checksum if offline/unavailable
            }

            return string.Empty;
        }

        /// <summary>
        /// Computes the lowercase hexadecimal MD5 hash of a local file.
        /// </summary>
        private async Task<string> ComputeFileMd5Async(string filePath, CancellationToken cancellationToken) {
            using var md5Hasher = MD5.Create();
            await using var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read, DownloadBufferSizeBytes, true);
            byte[] hashByteList = await md5Hasher.ComputeHashAsync(fileStream, cancellationToken);
            return Convert.ToHexStringLower(hashByteList);
        }

        /// <summary>
        /// Prints download progress in megabytes and percentage.
        /// </summary>
        private static void PrintProgress(string slug, long currentBytes, long totalBytes) {
            double currentMegabytes = currentBytes / (1024.0 * 1024.0);
            if (totalBytes > 0L) {
                double totalMegabytes = totalBytes / (1024.0 * 1024.0);
                double percentage = (currentBytes * 100.0) / totalBytes;
                Console.WriteLine(string.Format(
                    System.Globalization.CultureInfo.InvariantCulture,
                    "[Download] {0}: {1:F1} MB / {2:F1} MB ({3:F1}%)",
                    slug,
                    currentMegabytes,
                    totalMegabytes,
                    percentage
                ));
            }else {
                Console.WriteLine(string.Format(
                    System.Globalization.CultureInfo.InvariantCulture,
                    "[Download] {0}: {1:F1} MB downloaded",
                    slug,
                    currentMegabytes
                ));
            }
        }
    }
}
