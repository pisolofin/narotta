import 'package:flutter_test/flutter_test.dart';
import 'package:nanna_platform/nanna_platform.dart';

import 'package:narotta/app.dart';
import 'package:narotta/pages/home/home.page.dart';
import 'package:narotta/pages/map/widgets/map-view.widget.dart';
import 'package:narotta/pages/settings/widgets/settings.widget.dart';

void main() {
  testWidgets('NaRottaApp renders MapView, switches to Settings, and changes language and theme', (WidgetTester tester) async {
    await tester.pumpWidget(const NaRottaApp());
    await tester.pumpAndSettle();

    // Verify that HomePage and MapView are displayed initially
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(MapView), findsOneWidget);
    expect(find.byType(Settings), findsNothing);
    expect(find.byType(NaBottomNavigationBar), findsOneWidget);

    // Tap the Settings icon in the bottom navigation bar
    await tester.tap(find.byWidgetPredicate((widget) => (widget is NaIcon) && (widget.icon == NaIcons.settings)));
    await tester.pumpAndSettle();

    // Verify that the Settings tab and tiles (Language and Theme) are displayed
    expect(find.byType(Settings), findsOneWidget);
    expect(find.byType(NaListTile), findsNWidgets(2));

    // Tap the Language tile to open the language selection modal
    await tester.tap(find.byType(NaListTile).first);
    await tester.pumpAndSettle();

    // Select Italian ('Italiano' or 'Italian')
    final Finder italianOption = find.text('Italian').evaluate().isNotEmpty
      ? find.text('Italian')
      : find.text('Italiano')
    ;
    await tester.tap(italianOption);
    await tester.pumpAndSettle();

    // Verify UI is now localized in Italian
    expect(find.text('Lingua'), findsOneWidget);
    expect(find.text('Italiano'), findsOneWidget);
    expect(find.text('Tema'), findsOneWidget);

    // Tap the Theme tile to open the theme selection modal
    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();

    // Select Dark theme ('Scuro')
    await tester.tap(find.text('Scuro'));
    await tester.pumpAndSettle();

    // Verify Dark theme is now selected
    expect(find.text('Scuro'), findsOneWidget);
  });
}
