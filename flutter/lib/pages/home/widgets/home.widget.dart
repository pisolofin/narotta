import 'package:flutter/widgets.dart';

import '../../map/widgets/map-view.widget.dart';
import '../../settings/widgets/settings.widget.dart';

/// Main body widget for the home screen, switching between the Map and Settings tabs.
class Home extends StatelessWidget {
  final int currentIndex;

  const Home({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (this.currentIndex == 1) {
      return const Settings();
    }
    return const MapView();
  }
}
