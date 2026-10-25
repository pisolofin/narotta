import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'geo-cell-service.dart';
import 'settings-service.dart';

/// Client service communicating with NaRotta.MapServer Web API for map downloads.
class MapServerService {
  static final MapServerService _instance = MapServerService._internal();

  /// Returns the singleton instance of [MapServerService].
  factory MapServerService() {
    return _instance;
  }

  MapServerService._internal();

  /// Checks the connectivity and health status of the configured Map Server, with smart local port detection.
  Future<bool> checkHealthAsync() async {
    final String serverUrl = SettingsService().mapServerUrl.replaceAll(RegExp(r'/+$'), '');
    final HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    try {
      final Uri uri = Uri.parse('$serverUrl/health');
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode == HttpStatus.ok) {
        return true;
      }
    }catch (_) {
      // Primary attempt failed, try fallback loop below
    }finally {
      client.close();
    }

    // If local test server is configured, check alternative ports/IPv4 mappings
    if (serverUrl.contains('localhost') || serverUrl.contains('127.0.0.1')) {
      final List<String> candidateUrlList = [
        'http://127.0.0.1:5001',
        'http://localhost:5001',
        'http://localhost:58229',
        'http://127.0.0.1:58229',
      ];

      for (final String candidateUrl in candidateUrlList) {
        if (candidateUrl == serverUrl) {
          continue;
        }
        final HttpClient fallbackClient = HttpClient();
        fallbackClient.connectionTimeout = const Duration(seconds: 2);
        try {
          final Uri altUri = Uri.parse('$candidateUrl/health');
          final HttpClientRequest altReq = await fallbackClient.getUrl(altUri);
          final HttpClientResponse altResp = await altReq.close();
          if (altResp.statusCode == HttpStatus.ok) {
            await SettingsService().updateMapServerUrlAsync(candidateUrl);
            return true;
          }
        }catch (_) {
          // Continue checking next candidate
        }finally {
          fallbackClient.close();
        }
      }
    }

    return false;
  }

  /// Downloads a file stream from the server with progress notification.
  Future<bool> downloadFileStreamAsync(
    String relativePath, {
    void Function(double progress)? onProgress,
  }) async {
    final String serverUrl = SettingsService().mapServerUrl.replaceAll(RegExp(r'/+$'), '');
    final HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final String cleanPath = relativePath.replaceAll(RegExp(r'^/+'), '');
      final Uri uri = Uri.parse('$serverUrl/api/v1/download/$cleanPath');
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final int totalLength = response.contentLength;
        int receivedBytes = 0;

        await for (final List<int> chunk in response) {
          receivedBytes += chunk.length;
          if ((totalLength > 0) && (onProgress != null)) {
            onProgress((receivedBytes / totalLength).clamp(0.0, 1.0));
          }
        }
        return true;
      }
      return false;
    }catch (_) {
      return false;
    }finally {
      client.close();
    }
  }

  /// Queries the intersecting cells and estimated size for a finger-drawn polygon from the Map Server, falling back to local computation if offline.
  Future<List<GeoCellModel>> queryPolygonCellsAsync(
    List<math.Point<double>> coordinateList, {
    List<String>? layerList,
  }) async {
    final String serverUrl = SettingsService().mapServerUrl.replaceAll(RegExp(r'/+$'), '');
    final HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    try {
      final Uri uri = Uri.parse('$serverUrl/api/v1/cells/query-lasso');
      final HttpClientRequest request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;

      final List<Map<String, double>> pointsPayloadList = [];
      for (final math.Point<double> point in coordinateList) {
        pointsPayloadList.add({
          'latitude' : point.y,
          'longitude': point.x,
        });
      }

      final Map<String, dynamic> body = {
        'points': pointsPayloadList,
        'layers': layerList ?? ['transit_and_driving'],
      };

      request.write(jsonEncode(body));
      final HttpClientResponse response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final String responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> json = jsonDecode(responseBody) as Map<String, dynamic>;
        final List<dynamic>? rawCellList = json['cells'] as List<dynamic>?;

        if (rawCellList != null) {
          final List<GeoCellModel> resultList = [];
          for (final dynamic item in rawCellList) {
            final Map<String, dynamic> cellMap = item as Map<String, dynamic>;
            final List<dynamic> bbox = cellMap['bbox'] as List<dynamic>;
            resultList.add(
              GeoCellModel(
                cellId         : cellMap['cell_id'] as String,
                minLongitude   : (bbox[0] as num).toDouble(),
                minLatitude    : (bbox[1] as num).toDouble(),
                maxLongitude   : (bbox[2] as num).toDouble(),
                maxLatitude    : (bbox[3] as num).toDouble(),
                estimatedSizeMb: ((cellMap['size_mb'] as num?) ?? 12.0).toDouble(),
              ),
            );
          }
          return resultList;
        }
      }
    }catch (_) {
      // Offline fallback
    }finally {
      client.close();
    }

    // Local fallback calculation
    return GeoCellService.getIntersectingCellListForPolygon(coordinateList);
  }
}
