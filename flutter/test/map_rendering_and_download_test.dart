import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:narotta/app.dart';
import 'package:narotta/services/geo-cell-service.dart';
import 'package:narotta/services/settings-service.dart';
import 'package:narotta/services/map-server-service.dart';
import 'package:narotta/services/map-download-service.dart';
import 'package:narotta/pages/map/widgets/map-view.widget.dart';
import 'package:narotta/pages/map/widgets/map-grid-painter.dart';
import 'package:narotta/pages/map/widgets/map-status-badge.widget.dart';

void main() {
  setUp(() async {
    MapDownloadService.mapsDirectoryOverride = Directory.systemTemp;
    MapServerService().healthCheckOverride   = () async => true;
    await SettingsService().updateLanguageCodeAsync('it');
    await MapDownloadService().initAsync();
    await MapDownloadService().deleteWorldMapAsync();
  });

  tearDown(() async {
    MapDownloadService.mapsDirectoryOverride = null;
    MapServerService().healthCheckOverride   = null;
    await MapDownloadService().deleteWorldMapAsync();
  });

  test('MapDownloadService supports real resumable pause, resume, and cancel', () async {
    final MapDownloadService downloadService = MapDownloadService();
    expect(downloadService.isWorldMapDownloaded, isFalse);

    // 1. Start world map download
    final Future<bool> downloadFuture = downloadService.downloadWorldMapAsync(skipServerCheck: true);
    await Future.delayed(const Duration(milliseconds: 60));

    expect(downloadService.isItemDownloading(MapDownloadService.worldOverviewId), isTrue);

    // 2. Pause download
    downloadService.pauseDownload(MapDownloadService.worldOverviewId);
    expect(downloadService.isItemPaused(MapDownloadService.worldOverviewId), isTrue);
    expect(downloadService.getTaskStatus(MapDownloadService.worldOverviewId), equals(DownloadTaskStatus.paused));

    // Await initial paused future result
    final bool firstResult = await downloadFuture;
    expect(firstResult, isFalse);

    // 3. Resume download and verify completion
    final Future<bool> resumeFuture = downloadService.downloadWorldMapAsync(skipServerCheck: true);
    final bool resumeResult = await resumeFuture;

    expect(resumeResult, isTrue);
    expect(downloadService.isWorldMapDownloaded, isTrue);
    expect(downloadService.getTaskStatus(MapDownloadService.worldOverviewId), equals(DownloadTaskStatus.completed));

    // 4. Delete world map
    await downloadService.deleteWorldMapAsync();
    expect(downloadService.isWorldMapDownloaded, isFalse);
  });

  testWidgets('MapView dynamically updates MapStatusBadge and MapGridPainter based on download state', (WidgetTester tester) async {
    final MapDownloadService downloadService = MapDownloadService();
    await downloadService.deleteWorldMapAsync();

    await tester.pumpWidget(const NaRottaApp());
    await tester.pump();

    expect(find.byType(MapView), findsOneWidget);
    expect(find.byType(MapStatusBadge), findsOneWidget);

    final Finder painterFinder = find.byWidgetPredicate(
      (widget) => (widget is CustomPaint) && (widget.painter is MapGridPainter),
    );

    // 1. Initial state: No world map, no offline cells -> Cartographic void grid
    expect(find.text('Reticolo cartografico - In attesa della mappa'), findsOneWidget);

    CustomPaint customPaint = tester.widget<CustomPaint>(painterFinder);
    MapGridPainter painter = customPaint.painter! as MapGridPainter;
    expect(painter.isWorldMapDownloaded, isFalse);
    expect(painter.downloadedCellLevelMap.isEmpty, isTrue);

    // 2. Download world map -> Global base map status
    final Future<bool> worldFuture = downloadService.downloadWorldMapAsync(skipServerCheck: true);
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final bool worldSuccess = await worldFuture;
    expect(worldSuccess, isTrue);
    await tester.pump();

    expect(find.text('Mappa base globale'), findsOneWidget);

    customPaint = tester.widget<CustomPaint>(painterFinder);
    painter = customPaint.painter! as MapGridPainter;
    expect(painter.isWorldMapDownloaded, isTrue);

    // 3. Download regional cell for Italy/Rome -> Offline map active status
    final String romeCellId = GeoCellService.getCellForCoordinates(12.4964, 41.9028).cellId;
    final Future<bool> selectionFuture = downloadService.downloadSelectionAsync(
      cellIdList     : [romeCellId],
      level          : MapDetailLevel.complete,
      zoneDisplayName: 'Roma',
      skipServerCheck: true,
    );
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final bool selectionSuccess = await selectionFuture;
    expect(selectionSuccess, isTrue);
    await tester.pump();

    expect(find.text('Mappa offline attiva'), findsOneWidget);

    customPaint = tester.widget<CustomPaint>(painterFinder);
    painter = customPaint.painter! as MapGridPainter;
    expect(painter.downloadedCellLevelMap.containsKey(romeCellId), isTrue);
    expect(painter.downloadedCellLevelMap[romeCellId], equals(MapDetailLevel.complete));
  });
}
