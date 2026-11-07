import 'package:narotta/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanna_platform/nanna_platform.dart';
import 'package:narotta/services/settings-service.dart';
import 'package:narotta/services/map-server-service.dart';
import 'package:narotta/services/map-download-service.dart';
import 'package:narotta/pages/map-download/map-download.page.dart';
import 'package:narotta/pages/settings/widgets/settings.widget.dart';
import 'package:narotta/pages/map-download/widgets/world-selection-map.widget.dart';
import 'package:narotta/pages/map-download/widgets/downloaded-zones-modal.widget.dart';

void main() {
  tearDown(() {
    MapServerService().healthCheckOverride = null;
  });

  testWidgets('Simplified Settings navigates to MapDownloadPage with Server, Base Map, Search, and Downloaded Zones management', (WidgetTester tester) async {
    MapServerService().healthCheckOverride = () async => true;
    await SettingsService().updateLanguageCodeAsync('it');

    await tester.pumpWidget(const NaRottaApp());
    await tester.pump();

    // Navigate to Settings tab
    await tester.tap(find.byWidgetPredicate((widget) => (widget is NaIcon) && (widget.icon == NaIcons.settings)));
    await tester.pumpAndSettle();

    expect(find.byType(Settings), findsOneWidget);

    // Verify simplified Settings structure: General + Download maps, Map style & Wi-Fi only
    expect(find.text('Generali'), findsOneWidget);
    expect(find.text('Mappe e download'), findsOneWidget);
    expect(find.text('Scarica mappe'), findsOneWidget);
    expect(find.text('Stile mappa'), findsOneWidget);
    expect(find.text('Scarica solo Wi-Fi'), findsOneWidget);
    expect(find.textContaining('Livelli di dettaglio'), findsNothing);

    // Test Map Style selector modal
    await tester.tap(find.text('Stile mappa'));
    await tester.pumpAndSettle();
    expect(find.text('Seleziona stile mappa'), findsOneWidget);
    expect(find.text('Cartografico Tattico'), findsWidgets);
    await tester.tap(find.text('Cartografico Tattico').last);
    await tester.pumpAndSettle();
    expect(SettingsService().mapDisplayStyle.name, equals('tactical'));

    // Tap "Scarica mappe" to open unified MapDownloadPage
    await tester.tap(find.text('Scarica mappe'));
    await tester.pumpAndSettle();

    expect(find.byType(MapDownloadPage), findsOneWidget);
    expect(find.text('Server'), findsOneWidget);
    expect(find.text('Mappa base'), findsOneWidget);
    expect(find.text('Selezione'), findsOneWidget);
    expect(find.byType(WorldSelectionMap), findsOneWidget);

    // 1. Test Server preset & Custom URL inside MapDownloadPage
    final Finder serverTile = find.byWidgetPredicate(
      (widget) => (widget is NaListTile) && (widget.leading is NaIcon) && ((widget.leading as NaIcon).icon == NaIcons.dns),
    );
    expect(serverTile, findsOneWidget);

    await tester.tap(serverTile);
    await tester.pumpAndSettle();

    final Finder localhostOption = find.textContaining('localhost:5001');
    expect(localhostOption, findsOneWidget);
    await tester.tap(localhostOption);
    await tester.pumpAndSettle();

    expect(find.text('localhost:5001'), findsOneWidget);

    await tester.tap(serverTile);
    await tester.pumpAndSettle();

    final Finder customOption = find.textContaining('Personalizzato');
    expect(customOption, findsOneWidget);
    await tester.tap(customOption);
    await tester.pumpAndSettle();

    expect(find.byType(NaAlertDialog), findsOneWidget);
    await tester.enterText(find.byType(NaTextField), 'http://192.168.1.100:8080');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('http://192.168.1.100:8080'), findsOneWidget);

    // 2. Test searching a region ("Lombardia") and selecting all its cells completely
    await tester.enterText(find.byType(NaSearchBar), 'Lombardia');
    await tester.pumpAndSettle();

    final Finder lombardiaResult = find.text('Regione • Italia');
    expect(lombardiaResult, findsOneWidget);
    await tester.tap(lombardiaResult);
    await tester.pumpAndSettle();

    // Verify Lombardia cells are selected and switch mode to "Dettagliato"
    expect(find.textContaining('Lombardia •'), findsOneWidget);
    final Finder detailedModeChip = find.text('Dettagliato').last;
    await tester.tap(detailedModeChip);
    await tester.pumpAndSettle();

    // Trigger download of Lombardia at Detailed level
    final Finder downloadActionBtn = find.textContaining('Scarica Dettagliato');
    expect(downloadActionBtn, findsOneWidget);
    await tester.tap(downloadActionBtn);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(MapDownloadService().downloadedZoneCount, equals(1));
    expect(find.text('Zone scaricate (1)'), findsOneWidget);

    // 3. Open Downloaded Zones modal, select zone, change level to "Completo", then remove it
    await tester.tap(find.text('Zone scaricate (1)'));
    await tester.pumpAndSettle();

    expect(find.byType(DownloadedZonesModal), findsOneWidget);
    expect(find.text('Lombardia'), findsWidgets);

    // Select all zones
    await tester.tap(find.text('Seleziona tutte'));
    await tester.pumpAndSettle();
    expect(find.text('1 selezionata'), findsOneWidget);

    // Change detail level to Completo
    await tester.tap(find.text('Cambia livello'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Completo (+ 3D'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(MapDownloadService().getDownloadedZoneList().first.level, equals(MapDetailLevel.complete));

    // Remove the selected zone
    final Finder modalRemoveBtn = find.descendant(
      of      : find.byType(DownloadedZonesModal),
      matching: find.text('Rimuovi'),
    );
    await tester.tap(modalRemoveBtn);
    await tester.pumpAndSettle();

    // Confirm deletion in alert dialog
    final Finder confirmRemoveBtn = find.descendant(
      of      : find.byType(NaAlertDialog),
      matching: find.text('Rimuovi'),
    );
    await tester.tap(confirmRemoveBtn);
    await tester.pumpAndSettle();

    expect(MapDownloadService().downloadedZoneCount, equals(0));
    expect(find.text('Nessuna zona scaricata'), findsOneWidget);
  });
}