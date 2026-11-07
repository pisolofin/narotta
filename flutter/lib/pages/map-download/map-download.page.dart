import 'package:flutter/widgets.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../l10n/app_localizations.dart';

import 'widgets/map-download.widget.dart';

/// Screen displaying unified offline map configuration and downloads: Server, Base Map, and Interactive World Selection.
class MapDownloadPage extends StatelessWidget {
  const MapDownloadPage({ super.key });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return NaScaffold(
      appBar: NaAppBar(
        title: Text(l10n.mapDownloadTitle),
      ),
      body: const SafeArea(
        child: MapDownload(),
      ),
    );
  }
}
