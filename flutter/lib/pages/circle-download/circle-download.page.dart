import 'package:flutter/widgets.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../l10n/app_localizations.dart';
import 'widgets/circle-download.widget.dart';

/// Screen displaying the interactive circle and download canvas for 0.5° × 0.5° geo-cells.
class CircleDownloadPage extends StatelessWidget {
  const CircleDownloadPage({ super.key });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return NaScaffold(
      appBar: NaAppBar(
        leading: NaIconButton(
          icon     : const NaIcon(NaIcons.arrowBack),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.circleDownloadTitle),
      ),
      body: const SafeArea(
        child: CircleDownload(),
      ),
    );
  }
}
