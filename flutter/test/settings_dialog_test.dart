import 'package:flutter_test/flutter_test.dart';
import 'package:nanna_platform/nanna_platform.dart';

import 'package:narotta/app.dart';
import 'package:narotta/pages/settings/widgets/settings.widget.dart';

void main() {
  testWidgets('Select Map Server preset and configure custom URL in Settings', (WidgetTester tester) async {
    await tester.pumpWidget(const NaRottaApp());
    await tester.pump();

    // Tap Settings tab
    await tester.tap(find.byWidgetPredicate((widget) => (widget is NaIcon) && (widget.icon == NaIcons.settings)));
    await tester.pumpAndSettle();

    expect(find.byType(Settings), findsOneWidget);

    // Find the Server URL tile
    final Finder serverTile = find.widgetWithText(NaListTile, 'Server Mappe Web API').evaluate().isNotEmpty
      ? find.widgetWithText(NaListTile, 'Server Mappe Web API')
      : find.widgetWithText(NaListTile, 'Map Server Web API')
    ;
    expect(serverTile, findsOneWidget);

    // Tap the server tile to open selection modal
    await tester.tap(serverTile);
    await tester.pumpAndSettle();

    // Select Localhost preset
    final Finder localhostOption = find.textContaining('localhost:5001');
    expect(localhostOption, findsOneWidget);
    await tester.tap(localhostOption);
    await tester.pumpAndSettle();

    // Verify localhost is now displayed in the tile trailing
    expect(find.text('localhost:5001'), findsOneWidget);

    // Tap the server tile again to open custom URL dialog
    await tester.tap(serverTile);
    await tester.pumpAndSettle();

    final Finder customOption = find.textContaining('Personalizzato').evaluate().isNotEmpty
      ? find.textContaining('Personalizzato')
      : find.textContaining('Custom')
    ;
    expect(customOption, findsOneWidget);
    await tester.tap(customOption);
    await tester.pumpAndSettle();

    // Dialog is now open with input field
    expect(find.byType(NaAlertDialog), findsOneWidget);
    expect(find.byType(NaTextField), findsOneWidget);

    // Enter custom URL
    await tester.enterText(find.byType(NaTextField), 'http://192.168.1.100:8080');
    await tester.pumpAndSettle();

    // Tap Save
    final Finder saveButton = find.text('Salva').evaluate().isNotEmpty
      ? find.text('Salva')
      : find.text('Save')
    ;
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify dialog closed and custom URL is displayed
    expect(find.byType(NaAlertDialog), findsNothing);
    expect(find.text('http://192.168.1.100:8080'), findsOneWidget);
  });
}
