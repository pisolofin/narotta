using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using NaRotta.MapBuilder.Core.Logging;
using NaRotta.MapBuilder.Core.Models;
using NaRotta.MapBuilder.Core.Orchestrator;
using NaRotta.MapBuilder.Core.Runners;
using NaRotta.MapBuilder.Core.Services;
using NaRotta.MapBuilder.Web.Models;
using NaRotta.MapBuilder.Web.Services;
using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Channels;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Web {
    public static class Program {
        private static readonly JsonSerializerOptions _jsonWebOptions = new JsonSerializerOptions(JsonSerializerDefaults.Web);

        public static async Task Main(string[] argumentList) {
            WebApplicationBuilder builder = WebApplication.CreateBuilder(argumentList);

            // Load optional Local settings overrides (not tracked in Git)
            builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true);

            // Load optional persistent settings from workspace directory if present
            string? envWorkspace = Environment.GetEnvironmentVariable("WORKSPACE_DIR");
            string defaultWorkspaceDir = OperatingSystem.IsWindows() ? @"C:\narotta-workspace" : "/app/workspace";
            string effectiveWorkspaceDir = !string.IsNullOrEmpty(envWorkspace) ? envWorkspace : defaultWorkspaceDir;
            string workspaceSettingsFile = Path.Combine(effectiveWorkspaceDir, "mapbuilder.settings.json");
            if (File.Exists(workspaceSettingsFile)) {
                builder.Configuration.AddJsonFile(workspaceSettingsFile, optional: true, reloadOnChange: true);
            }

            // Environment variables have the highest precedence (Coolify / Docker overrides)
            builder.Configuration.AddEnvironmentVariables();

            // Configure HTTP port: listen on configured port (e.g. 8080) and port 80 (default for Coolify proxy)
            string? portEnvironment = Environment.GetEnvironmentVariable("PORT");
            if (!string.IsNullOrEmpty(portEnvironment)) {
                if (portEnvironment == "8080") {
                    builder.WebHost.UseUrls("http://0.0.0.0:8080;http://0.0.0.0:80");
                }else {
                    builder.WebHost.UseUrls("http://0.0.0.0:" + portEnvironment + ";http://0.0.0.0:80");
                }
            }else {
                builder.WebHost.UseUrls("http://0.0.0.0:8080;http://0.0.0.0:80");
            }

            // Register configuration manager singleton
            var configService = new MapBuilderConfigService(builder.Configuration, builder.Environment.ContentRootPath);
            builder.Services.AddSingleton(configService);

            // Register shared HttpClient
            var httpClient = new HttpClient {
                Timeout = TimeSpan.FromHours(6)
            };
            httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("NaRotta-MapBuilder-Web/1.0 (+https://narotta.app)");
            builder.Services.AddSingleton(httpClient);

            // Register core runners and logging buffer
            var logBuffer = new BuildLogBuffer(5000);
            builder.Services.AddSingleton(logBuffer);

            // Redirect Console.Out and Console.Error to stream all child process and service logs to BuildLogBuffer
            var consoleOutForwarder = new BufferedConsoleWriter(Console.Out, logBuffer, "INFO");
            var consoleErrorForwarder = new BufferedConsoleWriter(Console.Error, logBuffer, "ERROR");
            Console.SetOut(consoleOutForwarder);
            Console.SetError(consoleErrorForwarder);

            var processRunner = new CrossPlatformProcessRunner();
            builder.Services.AddSingleton<IProcessRunner>(processRunner);

            // Register core services
            var catalogService = new GeofabrikCatalogService(httpClient);
            builder.Services.AddSingleton(catalogService);

            var updateCheckerService = new OsmUpdateCheckerService(httpClient, catalogService);
            builder.Services.AddSingleton(updateCheckerService);

            // Register singleton MapBuildOrchestrator
            MapBuilderSettingsModel initialSettings = configService.GetSettings();
            var orchestrator = new MapBuildOrchestrator(httpClient, processRunner, logBuffer) {
                DefaultWorkspaceDirectory = initialSettings.WorkspaceDirectory,
                DefaultOutputDirectory = initialSettings.OutputDirectory
            };
            builder.Services.AddSingleton<IMapBuildOrchestrator>(orchestrator);

            // Enable CORS for local development or remote dashboard embedding
            builder.Services.AddCors((options) => {
                options.AddDefaultPolicy((policy) => {
                    policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
                });
            });

            WebApplication app = builder.Build();

            app.UseCors();
            app.UseDefaultFiles();
            app.UseStaticFiles();

            // -------------------------------------------------------------
            // API Endpoints
            // -------------------------------------------------------------

            // GET /health - Lightweight service health check
            app.MapGet("/health", () => Results.Ok(new {
                status = "Healthy",
                service = "NaRotta.MapBuilder.Web",
                timestamp = DateTime.UtcNow
            }));

            // GET /api/status - Current build progress, machine telemetry, and active directories
            app.MapGet("/api/status", async (
                IMapBuildOrchestrator buildOrchestrator,
                MapBuilderConfigService cfgSvc,
                CancellationToken cancellationToken
            ) => {
                MapBuilderSettingsModel settings = cfgSvc.GetSettings();
                BuildProgressModel progress = buildOrchestrator.GetCurrentProgress();
                HardwareProfileModel hardware = await buildOrchestrator.GetHardwareProfileAsync(settings.WorkspaceDirectory, cancellationToken);

                return Results.Ok(new {
                    progress = progress,
                    hardware = hardware,
                    config = settings
                });
            });

            // GET /api/config - Storage paths and disk capacity validation
            app.MapGet("/api/config", (MapBuilderConfigService cfgSvc) => {
                MapBuilderSettingsModel settings = cfgSvc.GetSettings();
                DirectoryValidationModel workspaceValidation = cfgSvc.ValidateDirectory(settings.WorkspaceDirectory);
                DirectoryValidationModel outputValidation = cfgSvc.ValidateDirectory(settings.OutputDirectory);

                return Results.Ok(new {
                    settings = settings,
                    workspaceValidation = workspaceValidation,
                    outputValidation = outputValidation
                });
            });

            // POST /api/config - Update storage paths and optionally save to appsettings.json
            app.MapPost("/api/config", (MapBuilderSettingsModel newSettings, bool? persist, MapBuilderConfigService cfgSvc, IMapBuildOrchestrator buildOrch) => {
                bool shouldPersist = persist ?? true;
                bool success = cfgSvc.UpdateSettings(newSettings, shouldPersist, out string? errorMessage);
                if (!success) {
                    return Results.BadRequest(new {
                        success = false,
                        message = errorMessage
                    });
                }

                MapBuilderSettingsModel current = cfgSvc.GetSettings();
                if (buildOrch is MapBuildOrchestrator concreteOrch) {
                    concreteOrch.DefaultWorkspaceDirectory = current.WorkspaceDirectory;
                    concreteOrch.DefaultOutputDirectory = current.OutputDirectory;
                }
                DirectoryValidationModel workspaceValidation = cfgSvc.ValidateDirectory(current.WorkspaceDirectory);
                DirectoryValidationModel outputValidation = cfgSvc.ValidateDirectory(current.OutputDirectory);

                return Results.Ok(new {
                    success = true,
                    message = "Storage configuration applied successfully",
                    settings = current,
                    workspaceValidation = workspaceValidation,
                    outputValidation = outputValidation
                });
            });

            // POST /api/build/start - Start a build job
            app.MapPost("/api/build/start", async (
                StartBuildRequestModel request,
                IMapBuildOrchestrator buildOrchestrator,
                MapBuilderConfigService cfgSvc
            ) => {
                MapBuilderSettingsModel settings = cfgSvc.GetSettings();
                BuildOptionsModel options = request.ToBuildOptions(
                    settings.WorkspaceDirectory,
                    settings.OutputDirectory,
                    settings.ProfilesDirectory,
                    settings.ToolsDirectory,
                    settings.BaseUrl
                );

                bool started = await buildOrchestrator.StartBuildAsync(options);
                if (!started) {
                    return Results.Conflict(new {
                        success = false,
                        message = "Another build is already running. Please stop it or wait for completion.",
                        progress = buildOrchestrator.GetCurrentProgress()
                    });
                }

                return Results.Ok(new {
                    success = true,
                    message = "Build started successfully",
                    jobId = buildOrchestrator.GetCurrentProgress().JobId,
                    progress = buildOrchestrator.GetCurrentProgress(),
                    effectiveWorkspace = options.WorkspaceDirectory,
                    effectiveOutput = options.OutputDirectory
                });
            });

            // POST /api/build/stop - Request cancellation of current build
            app.MapPost("/api/build/stop", async (IMapBuildOrchestrator buildOrchestrator) => {
                bool stopped = await buildOrchestrator.StopBuildAsync();
                if (!stopped) {
                    return Results.BadRequest(new {
                        success = false,
                        message = "No active build job is currently running."
                    });
                }

                return Results.Ok(new {
                    success = true,
                    message = "Cancellation signal sent to build pipeline."
                });
            });

            // GET /api/build/logs - Retrieve recent log buffer
            app.MapGet("/api/build/logs", (BuildLogBuffer buffer, int? tail) => {
                int count = tail ?? 500;
                List<BuildLogEntryModel> logList = buffer.GetRecentEntryList(count);
                return Results.Ok(logList);
            });

            // GET /api/build/logs/stream - Server-Sent Events (SSE) real-time log and progress streaming
            app.MapGet("/api/build/logs/stream", async (
                HttpContext httpContext,
                BuildLogBuffer buffer,
                IMapBuildOrchestrator buildOrchestrator,
                CancellationToken clientCancellationToken
            ) => {
                httpContext.Response.Headers.Append("Content-Type", "text/event-stream");
                httpContext.Response.Headers.Append("Cache-Control", "no-cache");
                httpContext.Response.Headers.Append("Connection", "keep-alive");

                ChannelReader<BuildLogEntryModel> channelReader = buffer.Subscribe(clientCancellationToken, out Guid subscriberId);

                try {
                    // Send initial snapshot of progress
                    BuildProgressModel initialProgress = buildOrchestrator.GetCurrentProgress();
                    string initialJson = JsonSerializer.Serialize(initialProgress, _jsonWebOptions);
                    await httpContext.Response.WriteAsync("event: progress\ndata: " + initialJson + "\n\n", clientCancellationToken);
                    await httpContext.Response.Body.FlushAsync(clientCancellationToken);

                    // Send recent logs backlog (up to 100 lines) so client doesn't see a blank screen
                    List<BuildLogEntryModel> backlogList = buffer.GetRecentEntryList(100);
                    foreach (BuildLogEntryModel entry in backlogList) {
                        string entryJson = JsonSerializer.Serialize(entry, _jsonWebOptions);
                        await httpContext.Response.WriteAsync("event: log\ndata: " + entryJson + "\n\n", clientCancellationToken);
                    }
                    await httpContext.Response.Body.FlushAsync(clientCancellationToken);

                    DateTime lastHeartbeatUtc = DateTime.UtcNow;

                    while (!clientCancellationToken.IsCancellationRequested) {
                        bool wroteAnyLog = false;
                        while (channelReader.TryRead(out BuildLogEntryModel? logEntry)) {
                            if (logEntry != null) {
                                string logJson = JsonSerializer.Serialize(logEntry, _jsonWebOptions);
                                await httpContext.Response.WriteAsync("event: log\ndata: " + logJson + "\n\n", clientCancellationToken);
                                wroteAnyLog = true;
                            }
                        }

                        if (wroteAnyLog) {
                            await httpContext.Response.Body.FlushAsync(clientCancellationToken);
                        }

                        // Send progress update and heartbeat every 1 second
                        if ((DateTime.UtcNow - lastHeartbeatUtc).TotalMilliseconds >= 1000) {
                            BuildProgressModel currentProgress = buildOrchestrator.GetCurrentProgress();
                            string progressJson = JsonSerializer.Serialize(currentProgress, _jsonWebOptions);
                            await httpContext.Response.WriteAsync("event: progress\ndata: " + progressJson + "\n\n", clientCancellationToken);
                            await httpContext.Response.WriteAsync(": heartbeat\n\n", clientCancellationToken);
                            await httpContext.Response.Body.FlushAsync(clientCancellationToken);
                            lastHeartbeatUtc = DateTime.UtcNow;
                        }

                        // Wait for next item with a 500ms timeout to ensure heartbeats and progress are dispatched promptly
                        using var waitTimeoutCts = CancellationTokenSource.CreateLinkedTokenSource(clientCancellationToken);
                        waitTimeoutCts.CancelAfter(TimeSpan.FromMilliseconds(500));
                        try {
                            if (await channelReader.WaitToReadAsync(waitTimeoutCts.Token)) {
                                continue;
                            }
                        }catch (OperationCanceledException) when (!clientCancellationToken.IsCancellationRequested) {
                            // 500ms timeout expired, loop around to check heartbeat and keep connection active
                        }
                    }
                }catch (OperationCanceledException) {
                    // Client disconnected cleanly
                }finally {
                    buffer.Unsubscribe(subscriberId);
                }
            });

            // GET /api/osm/updates - Check OpenStreetMap updates for regions
            app.MapGet("/api/osm/updates", async (
                string? query,
                string? continent,
                int? limit,
                GeofabrikCatalogService catalogSvc,
                OsmUpdateCheckerService checkerSvc,
                MapBuilderConfigService cfgSvc,
                CancellationToken cancellationToken
            ) => {
                MapBuilderSettingsModel settings = cfgSvc.GetSettings();
                List<GeofabrikRegionModel> allRegionList = await catalogSvc.LoadCatalogAsync(settings.WorkspaceDirectory, false, cancellationToken);
                var targetList = new List<GeofabrikRegionModel>();

                if (!string.IsNullOrEmpty(query)) {
                    string lowerQuery = query.Trim().ToLowerInvariant();
                    targetList = allRegionList.FindAll((GeofabrikRegionModel r) =>
                        r.Id.ToLowerInvariant().Contains(lowerQuery) || r.Name.ToLowerInvariant().Contains(lowerQuery)
                    );
                }else if (!string.IsNullOrEmpty(continent)) {
                    targetList = catalogSvc.GetSubregionList(allRegionList, continent);
                }else {
                    // Default to major European countries and subregions
                    targetList = catalogSvc.GetSubregionList(allRegionList, "europe");
                    GeofabrikRegionModel? italy = catalogSvc.FindRegion(allRegionList, "italy");
                    if (italy != null) {
                        List<GeofabrikRegionModel> italySubList = catalogSvc.GetSubregionList(allRegionList, italy.Id);
                        targetList.AddRange(italySubList);
                    }
                }

                int maxCount = limit ?? 25;
                if (targetList.Count > maxCount) {
                    targetList = targetList.GetRange(0, maxCount);
                }

                List<OsmRegionUpdateModel> updateList = await checkerSvc.CheckBatchUpdatesAsync(
                    targetList,
                    settings.OutputDirectory,
                    4,
                    cancellationToken
                );

                return Results.Ok(updateList);
            });

            // GET /api/regions - Complete Geofabrik catalog index
            app.MapGet("/api/regions", async (
                GeofabrikCatalogService catalogSvc,
                MapBuilderConfigService cfgSvc,
                string? search,
                CancellationToken cancellationToken
            ) => {
                MapBuilderSettingsModel settings = cfgSvc.GetSettings();
                List<GeofabrikRegionModel> allRegionList = await catalogSvc.LoadCatalogAsync(settings.WorkspaceDirectory, false, cancellationToken);

                if (!string.IsNullOrEmpty(search)) {
                    string lowerSearch = search.Trim().ToLowerInvariant();
                    return Results.Ok(allRegionList.FindAll((GeofabrikRegionModel r) =>
                        r.Id.ToLowerInvariant().Contains(lowerSearch) || r.Name.ToLowerInvariant().Contains(lowerSearch)
                    ));
                }

                return Results.Ok(allRegionList);
            });

            // GET /api/manifest - Current manifest.json
            app.MapGet("/api/manifest", async (
                IMapBuildOrchestrator buildOrchestrator,
                MapBuilderConfigService cfgSvc,
                CancellationToken cancellationToken
            ) => {
                MapBuilderSettingsModel settings = cfgSvc.GetSettings();
                ManifestRootModel? manifest = await buildOrchestrator.GetCurrentManifestAsync(settings.OutputDirectory, cancellationToken);
                if (manifest == null) {
                    return Results.NotFound(new {
                        message = "manifest.json not found in output directory: " + settings.OutputDirectory
                    });
                }
                return Results.Ok(manifest);
            });

            // GET /api/system/doctor - Diagnostics
            app.MapGet("/api/system/doctor", async (
                IMapBuildOrchestrator buildOrchestrator,
                MapBuilderConfigService cfgSvc,
                CancellationToken cancellationToken
            ) => {
                MapBuilderSettingsModel settings = cfgSvc.GetSettings();
                HardwareProfileModel profile = await buildOrchestrator.GetHardwareProfileAsync(settings.WorkspaceDirectory, cancellationToken);
                return Results.Ok(profile);
            });

            await app.RunAsync();
        }
    }
}
