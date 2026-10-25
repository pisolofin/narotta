using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Core.Services;
using NaRotta.MapServer.Models;
using NaRotta.MapServer.Services;
using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapServer {
    public static class Program {
        public static async Task Main(string[] argumentList) {
            WebApplicationBuilder builder = WebApplication.CreateBuilder(argumentList);

            // Configure HTTP port from environment variable (standard in Docker / Coolify) or fallback to 5001
            string? portEnvironment = Environment.GetEnvironmentVariable("PORT");
            if (!string.IsNullOrEmpty(portEnvironment)) {
                builder.WebHost.UseUrls("http://0.0.0.0:" + portEnvironment);
            }else {
                builder.WebHost.UseUrls("http://0.0.0.0:5001;http://localhost:5001");
            }

            // Configure options
            builder.Services.Configure<MapServerSettingsModel>((MapServerSettingsModel options) => {
                builder.Configuration.GetSection("MapServer").Bind(options);

                string? envStorage = Environment.GetEnvironmentVariable("STORAGE_DIR") ?? Environment.GetEnvironmentVariable("OUTPUT_DIR");
                if (!string.IsNullOrWhiteSpace(envStorage)) {
                    options.StorageDirectory = envStorage;
                }

                string? envBaseUrl = Environment.GetEnvironmentVariable("PUBLIC_BASE_URL");
                if (!string.IsNullOrWhiteSpace(envBaseUrl)) {
                    options.PublicBaseUrl = envBaseUrl;
                }
            });

            // Register services
            builder.Services.AddSingleton<GeoCellGridService>();
            builder.Services.AddSingleton<MapDistributionService>();

            // Enable CORS
            builder.Services.AddCors((options) => {
                options.AddDefaultPolicy((policy) => {
                    policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
                });
            });

            WebApplication app = builder.Build();

            app.UseCors();

            // -------------------------------------------------------------
            // API Endpoints
            // -------------------------------------------------------------

            // GET /health - Service health check
            app.MapGet("/health", () => Results.Ok(new {
                status = "Healthy",
                service = "NaRotta.MapServer",
                timestamp = DateTime.UtcNow
            }));

            app.MapGet("/api/v1/health", () => Results.Ok(new {
                status = "Healthy",
                service = "NaRotta.MapServer",
                timestamp = DateTime.UtcNow
            }));

            // GET /api/v1/manifest - Full catalog manifest (schema v2.2)
            app.MapGet("/api/v1/manifest", async (
                MapDistributionService distributionService,
                CancellationToken cancellationToken
            ) => {
                ManifestRootModel manifest = await distributionService.GetManifestAsync(cancellationToken);
                return Results.Ok(manifest);
            });

            // GET /api/v1/regions - Available downloadable regions
            app.MapGet("/api/v1/regions", async (
                MapDistributionService distributionService,
                CancellationToken cancellationToken
            ) => {
                List<ManifestRegionModel> regionList = await distributionService.GetRegionListAsync(cancellationToken);
                return Results.Ok(regionList);
            });

            // GET /api/v1/regions/{*regionId} - Specific region metadata
            app.MapGet("/api/v1/regions/{*regionId}", async (
                string regionId,
                MapDistributionService distributionService,
                CancellationToken cancellationToken
            ) => {
                ManifestRegionModel? region = await distributionService.GetRegionByIdAsync(regionId, cancellationToken);
                if (region == null) {
                    return Results.NotFound(new { error = "Region not found: " + regionId });
                }
                return Results.Ok(region);
            });

            // POST /api/v1/cells/query-lasso - Intersecting cells for finger-drawn polygon / lasso
            app.MapPost("/api/v1/cells/query-lasso", async (
                QueryPolygonRequestModel request,
                MapDistributionService distributionService,
                CancellationToken cancellationToken
            ) => {
                if ((request == null) || (request.PointList == null) || (request.PointList.Count == 0)) {
                    return Results.BadRequest(new { error = "PointList must contain at least one point." });
                }

                QueryPolygonResponseModel response = await distributionService.QueryCellsForPolygonAsync(
                    request.PointList,
                    request.LayerList,
                    cancellationToken
                );
                return Results.Ok(response);
            });

            // GET /api/v1/cells/query-bbox - Intersecting cells for bounding box
            app.MapGet("/api/v1/cells/query-bbox", async (
                double minLon,
                double minLat,
                double maxLon,
                double maxLat,
                string? layers,
                MapDistributionService distributionService,
                CancellationToken cancellationToken
            ) => {
                List<string>? layerList = null;
                if (!string.IsNullOrWhiteSpace(layers)) {
                    layerList = new List<string>(layers.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
                }

                QueryPolygonResponseModel response = await distributionService.QueryCellsForBoundingBoxAsync(
                    minLon,
                    minLat,
                    maxLon,
                    maxLat,
                    layerList,
                    cancellationToken
                );
                return Results.Ok(response);
            });

            // GET /api/v1/cells/{cellId} - Single cell info
            app.MapGet("/api/v1/cells/{cellId}", async (
                string cellId,
                MapDistributionService distributionService,
                CancellationToken cancellationToken
            ) => {
                GeoCellDetailModel? cell = await distributionService.GetCellByIdAsync(cellId, cancellationToken);
                if (cell == null) {
                    return Results.NotFound(new { error = "Cell not found: " + cellId });
                }
                return Results.Ok(cell);
            });

            // GET /api/v1/download/{*filePath} - Resumable file stream with HTTP Range support
            app.MapGet("/api/v1/download/{*filePath}", (
                string filePath,
                MapDistributionService distributionService
            ) => {
                if (!distributionService.TryResolveFilePath(filePath, out string fullPath, out string contentType)) {
                    return Results.NotFound(new { error = "File not found: " + filePath });
                }

                return Results.File(
                    fullPath,
                    contentType: contentType,
                    fileDownloadName: Path.GetFileName(fullPath),
                    enableRangeProcessing: true
                );
            });

            // GET / - Root info
            app.MapGet("/", () => Results.Ok(new {
                service = "NaRotta.MapServer",
                description = "Map Distribution Web API for NaRotta Navigation App",
                version = "1.0.0",
                endpoints = new List<string> {
                    "/health",
                    "/api/v1/manifest",
                    "/api/v1/regions",
                    "/api/v1/cells/query-lasso",
                    "/api/v1/cells/query-bbox",
                    "/api/v1/download/{*filePath}"
                }
            }));

            await app.RunAsync();
        }
    }
}
