import 'package:flutter/widgets.dart';
import 'package:nanna_platform/nanna_platform.dart';

import 'widgets/home.widget.dart';
import '../../l10n/app_localizations.dart';

/// Main screen of the application with the map view and bottom navigation bar.
class HomePage extends StatefulWidget {
  const HomePage({ super.key });

  @override
  State<HomePage> createState() => _HomePageState();
}

/// State for [HomePage].
class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  /// Updates the active tab index when a bottom navigation item is tapped.
  void _onTabTapped(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String titleText      = _currentIndex == 0 ? l10n.mapTab : l10n.settingsTitle;

    return NaScaffold(
      appBar: NaAppBar(
        title: Text(titleText),
      ),
      body: SafeArea(
        child: Home(
          currentIndex: _currentIndex,
        ),
      ),
      bottomNavigationBar: NaBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap       : _onTabTapped,
        items       : [
          BottomNavigationBarItem(
            icon : const NaIcon(NaIcons.map),
            label: l10n.mapTab,
          ),
          BottomNavigationBarItem(
            icon : const NaIcon(NaIcons.settings),
            label: l10n.settingsTab,
          ),
        ],
      ),
    );
  }
}
