import 'package:flutter/widgets.dart';
import 'package:nanna_platform/nanna_platform.dart';

import 'widgets/map-download.widget.dart';
import '../../l10n/app_localizations.dart';

/// Screen displaying offline map download options: World Base Map, Countries/Regions, and Circle & Download.
class MapDownloadPage extends StatelessWidget {
  const MapDownloadPage({ super.key });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return NaScaffold(
      appBar: NaAppBar(
        leading: NaIconButton(
          icon     : const NaIcon(NaIcons.arrowBack),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.mapDownloadTitle),
      ),
      body: const SafeArea(
        child: MapDownload(),
      ),
    );
  }
}
