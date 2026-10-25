# ==============================================================================
# Multi-Stage Dockerfile for NaRotta Map Builder Server (.NET 10 + Java OpenJDK 21)
# Ready for remote deployment on Linux VPS with Coolify
# ==============================================================================

# --- Stage 1: Build .NET 10 solution ---
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source

# Copy project files and restore dependencies
COPY src/NaRotta.MapBuilder.Core/NaRotta.MapBuilder.Core.csproj src/NaRotta.MapBuilder.Core/
COPY src/NaRotta.MapBuilder.Web/NaRotta.MapBuilder.Web.csproj src/NaRotta.MapBuilder.Web/
RUN dotnet restore src/NaRotta.MapBuilder.Web/NaRotta.MapBuilder.Web.csproj

# Copy complete source code and compile Release artifacts
COPY src/ src/
RUN dotnet publish src/NaRotta.MapBuilder.Web/NaRotta.MapBuilder.Web.csproj -c Release -o /app/publish /p:UseAppHost=false

# --- Stage 2: Runtime Environment (.NET 10 + OpenJDK 21 for Planetiler) ---
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Install OpenJDK 21 (required by Planetiler) and runtime tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-21-jre-headless \
    curl \
    ca-certificates \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Copy published ASP.NET Core web application
COPY --from=build /app/publish .

# Copy schema profiles
COPY profiles/ /app/profiles/

# Create persistent storage mount points
RUN mkdir -p /app/workspace /app/output /app/tools /app/profiles

# Configure environment variables
ENV ASPNETCORE_URLS=http://+:8080 \
    PORT=8080 \
    WORKSPACE_DIR=/app/workspace \
    OUTPUT_DIR=/app/output \
    PROFILES_DIR=/app/profiles \
    TOOLS_DIR=/app/tools \
    BASE_URL=https://storage.narotta.app/maps/

# Coolify exposes port 8080
EXPOSE 8080

# Healthcheck probe
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/api/status || exit 1

ENTRYPOINT ["dotnet", "NaRotta.MapBuilder.Web.dll"]
