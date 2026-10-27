# ==============================================================================
# Multi-Stage Dockerfile for NaRotta Map Server API (.NET 10)
# Map distribution, Geo-Cell spatial query & resumable download API
# Ready for remote deployment on Linux VPS with Coolify
# NOTE: Build context must be the repository root to access shared Core models.
# ==============================================================================

# --- Stage 1: Build .NET 10 solution ---
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source

# Copy project files and restore dependencies
COPY map-builder/src/NaRotta.MapBuilder.Core/NaRotta.MapBuilder.Core.csproj map-builder/src/NaRotta.MapBuilder.Core/
COPY map-api/src/NaRotta.MapServer.Api/NaRotta.MapServer.Api.csproj map-api/src/NaRotta.MapServer.Api/
RUN dotnet restore map-api/src/NaRotta.MapServer.Api/NaRotta.MapServer.Api.csproj

# Copy source code and compile Release artifacts
COPY map-builder/src/NaRotta.MapBuilder.Core/ map-builder/src/NaRotta.MapBuilder.Core/
COPY map-api/src/NaRotta.MapServer.Api/ map-api/src/NaRotta.MapServer.Api/
RUN dotnet publish map-api/src/NaRotta.MapServer.Api/NaRotta.MapServer.Api.csproj -c Release -o /app/publish /p:UseAppHost=false

# --- Stage 2: Runtime Environment (.NET 10 ASP.NET Core) ---
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Install runtime utilities (curl for healthcheck, ca-certificates)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy published ASP.NET Core web application
COPY --from=build /app/publish .

# Create output mount point
RUN mkdir -p /app/output

# Configure environment variables
ENV ASPNETCORE_URLS=http://+:5001 \
    PORT=5001 \
    ASPNETCORE_ENVIRONMENT=Production \
    OUTPUT_DIR=/app/output \
    PUBLIC_BASE_URL=https://maps.narotta.app

# Coolify exposes port 5001
EXPOSE 5001

# Healthcheck probe
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:5001/health || exit 1

ENTRYPOINT ["dotnet", "NaRotta.MapServer.dll"]
