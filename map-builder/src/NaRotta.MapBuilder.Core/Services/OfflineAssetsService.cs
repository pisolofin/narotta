using NaRotta.MapBuilder.Core.Models;
using System;
using System.IO;
using System.IO.Compression;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Services {
    /// <summary>
    /// Generates the offline MapLibre assets archive (map_assets.zip) containing day/night multi-resolution styles, sprite definitions, and glyph directory structure.
    /// </summary>
    public class OfflineAssetsService {
        /// <summary>
        /// Builds the output/assets/map_assets.zip archive for 100% offline MapLibre rendering.
        /// </summary>
        public async Task<string> BuildOfflineAssetsPackageAsync(
            BuildOptionsModel options,
            CancellationToken cancellationToken
        ) {
            string assetsOutputDirectory = Path.Combine(options.OutputDirectory, "assets");
            Directory.CreateDirectory(assetsOutputDirectory);

            string outputZipPath = Path.Combine(assetsOutputDirectory, "map_assets.zip");
            if (File.Exists(outputZipPath)) {
                File.Delete(outputZipPath);
            }

            Console.WriteLine("[Assets] Building offline MapLibre styles and assets package: " + outputZipPath + "...");

            await using var fileStream = new FileStream(outputZipPath, FileMode.Create, FileAccess.Write, FileShare.None, 65536, true);
            using var zipArchive = new ZipArchive(fileStream, ZipArchiveMode.Create, false);

            // 1. Write style-day.json configured for the 5 multi-resolution vector tile sources
            string dayStyleJson = BuildMapLibreStyleJson(false);
            await WriteZipTextEntryAsync(zipArchive, "styles/style-day.json", dayStyleJson, cancellationToken);

            // 2. Write style-night.json configured for dark navigation HUD
            string nightStyleJson = BuildMapLibreStyleJson(true);
            await WriteZipTextEntryAsync(zipArchive, "styles/style-night.json", nightStyleJson, cancellationToken);

            // 3. Write default sprite metadata (sprites/sprite.json and sprites/sprite@2x.json)
            string spriteIndexJson = "{\n  \"motorway_shield\": { \"x\": 0, \"y\": 0, \"width\": 48, \"height\": 24, \"pixelRatio\": 1 }\n}\n";
            await WriteZipTextEntryAsync(zipArchive, "sprites/sprite.json", spriteIndexJson, cancellationToken);
            await WriteZipTextEntryAsync(zipArchive, "sprites/sprite@2x.json", spriteIndexJson, cancellationToken);

            // 4. Write glyph font readme/manifest for offline Noto Sans Regular/Bold PBF ranges
            string glyphManifestJson = "{\n  \"fonts\": [ \"Noto Sans Regular\", \"Noto Sans Bold\" ],\n  \"range_format\": \"glyphs/{fontstack}/{range}.pbf\"\n}\n";
            await WriteZipTextEntryAsync(zipArchive, "glyphs/manifest.json", glyphManifestJson, cancellationToken);

            Console.WriteLine("[Assets] Offline assets archive created: " + outputZipPath);
            return outputZipPath;
        }

        /// <summary>
        /// Builds the multi-resolution MapLibre GL style JSON combining Overview (Z0-7), Base (Z8-14), Pedestrian (Z13-15), 3D Buildings (Z13-15), and Terrain HD (Z9-14).
        /// </summary>
        private static string BuildMapLibreStyleJson(bool isNightMode) {
            string backgroundColor = isNightMode ? "#0F172A" : "#F8FAFC";
            string waterColor = isNightMode ? "#1E293B" : "#38BDF8";
            string parkColor = isNightMode ? "#064E3B" : "#BBF7D0";
            string motorwayColor = isNightMode ? "#3B82F6" : "#2563EB";
            string primaryRoadColor = isNightMode ? "#F59E0B" : "#D97706";
            string localRoadColor = isNightMode ? "#334155" : "#FFFFFF";
            string buildingColor = isNightMode ? "#1E293B" : "#E2E8F0";
            string pedestrianColor = isNightMode ? "#10B981" : "#059669";
            string textColor = isNightMode ? "#F1F5F9" : "#0F172A";

            var builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine("  \"version\": 8,");
            builder.AppendLine("  \"name\": \"" + (isNightMode ? "NaRotta Night Navigation" : "NaRotta Day Navigation") + "\",");
            builder.AppendLine("  \"glyphs\": \"file://{local_assets_dir}/glyphs/{fontstack}/{range}.pbf\",");
            builder.AppendLine("  \"sprite\": \"file://{local_assets_dir}/sprites/sprite\",");
            builder.AppendLine("  \"sources\": {");
            builder.AppendLine("    \"overview_source\": { \"type\": \"vector\", \"url\": \"mbtiles://{local_maps_dir}/overview/world_overview.mbtiles\", \"minzoom\": 0, \"maxzoom\": 7 },");
            builder.AppendLine("    \"base_source\": { \"type\": \"vector\", \"url\": \"mbtiles://{local_maps_dir}/active_base.mbtiles\", \"minzoom\": 8, \"maxzoom\": 14 },");
            builder.AppendLine("    \"pedestrian_source\": { \"type\": \"vector\", \"url\": \"mbtiles://{local_maps_dir}/active_pedestrian.mbtiles\", \"minzoom\": 13, \"maxzoom\": 15 },");
            builder.AppendLine("    \"buildings_source\": { \"type\": \"vector\", \"url\": \"mbtiles://{local_maps_dir}/active_buildings.mbtiles\", \"minzoom\": 13, \"maxzoom\": 15 },");
            builder.AppendLine("    \"terrain_source\": { \"type\": \"vector\", \"url\": \"mbtiles://{local_maps_dir}/active_terrain_hd.mbtiles\", \"minzoom\": 9, \"maxzoom\": 14 }");
            builder.AppendLine("  },");
            builder.AppendLine("  \"layers\": [");
            builder.AppendLine("    { \"id\": \"background\", \"type\": \"background\", \"paint\": { \"background-color\": \"" + backgroundColor + "\" } },");
            builder.AppendLine("    { \"id\": \"overview-water\", \"type\": \"fill\", \"source\": \"overview_source\", \"source-layer\": \"water\", \"maxzoom\": 8, \"paint\": { \"fill-color\": \"" + waterColor + "\" } },");
            builder.AppendLine("    { \"id\": \"base-landcover\", \"type\": \"fill\", \"source\": \"base_source\", \"source-layer\": \"landcover\", \"minzoom\": 8, \"paint\": { \"fill-color\": \"" + parkColor + "\", \"fill-opacity\": 0.45 } },");
            builder.AppendLine("    { \"id\": \"base-water\", \"type\": \"fill\", \"source\": \"base_source\", \"source-layer\": \"water\", \"minzoom\": 8, \"paint\": { \"fill-color\": \"" + waterColor + "\" } },");
            builder.AppendLine("    { \"id\": \"pedestrian-paths\", \"type\": \"line\", \"source\": \"pedestrian_source\", \"source-layer\": \"pedestrian_paths\", \"minzoom\": 13, \"paint\": { \"line-color\": \"" + pedestrianColor + "\", \"line-width\": 1.5, \"line-dasharray\": [2, 2] } },");
            builder.AppendLine("    { \"id\": \"base-roads-local\", \"type\": \"line\", \"source\": \"base_source\", \"source-layer\": \"transportation\", \"minzoom\": 12, \"paint\": { \"line-color\": \"" + localRoadColor + "\", \"line-width\": 3.0 } },");
            builder.AppendLine("    { \"id\": \"base-roads-primary\", \"type\": \"line\", \"source\": \"base_source\", \"source-layer\": \"transportation\", \"minzoom\": 10, \"paint\": { \"line-color\": \"" + primaryRoadColor + "\", \"line-width\": 4.5 } },");
            builder.AppendLine("    { \"id\": \"overview-motorway\", \"type\": \"line\", \"source\": \"overview_source\", \"source-layer\": \"transportation\", \"minzoom\": 4, \"maxzoom\": 8, \"paint\": { \"line-color\": \"" + motorwayColor + "\", \"line-width\": 2.0 } },");
            builder.AppendLine("    { \"id\": \"base-roads-motorway\", \"type\": \"line\", \"source\": \"base_source\", \"source-layer\": \"transportation\", \"minzoom\": 8, \"paint\": { \"line-color\": \"" + motorwayColor + "\", \"line-width\": 6.0 } },");
            builder.AppendLine("    { \"id\": \"buildings-3d\", \"type\": \"fill-extrusion\", \"source\": \"buildings_source\", \"source-layer\": \"building\", \"minzoom\": 13, \"paint\": { \"fill-extrusion-color\": \"" + buildingColor + "\", \"fill-extrusion-height\": [\"coalesce\", [\"to-number\", [\"get\", \"height\"]], 10], \"fill-extrusion-opacity\": 0.8 } },");
            builder.AppendLine("    { \"id\": \"terrain-peaks\", \"type\": \"symbol\", \"source\": \"terrain_source\", \"source-layer\": \"mountain_peak\", \"minzoom\": 10, \"layout\": { \"text-field\": [\"get\", \"name\"], \"text-font\": [\"Noto Sans Regular\"], \"text-size\": 11 }, \"paint\": { \"text-color\": \"" + textColor + "\" } },");
            builder.AppendLine("    { \"id\": \"place-labels\", \"type\": \"symbol\", \"source\": \"base_source\", \"source-layer\": \"place\", \"minzoom\": 8, \"layout\": { \"text-field\": [\"get\", \"name\"], \"text-font\": [\"Noto Sans Bold\"], \"text-size\": 14 }, \"paint\": { \"text-color\": \"" + textColor + "\" } }");
            builder.AppendLine("  ]");
            builder.AppendLine("}");
            return builder.ToString();
        }

        private static async Task WriteZipTextEntryAsync(
            ZipArchive archive,
            string entryPath,
            string content,
            CancellationToken cancellationToken
        ) {
            ZipArchiveEntry entry = archive.CreateEntry(entryPath, CompressionLevel.Optimal);
            await using Stream entryStream = entry.Open();
            byte[] byteList = Encoding.UTF8.GetBytes(content);
            await entryStream.WriteAsync(byteList, 0, byteList.Length, cancellationToken);
        }
    }
}
