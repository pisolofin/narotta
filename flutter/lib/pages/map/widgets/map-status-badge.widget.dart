import 'package:flutter/widgets.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';

/// Represents the cartographic coverage level for the active viewport.
enum MapCoverageStatus {
  offlineData,
  worldBase,
  voidGrid,
}

/// Floating top badge indicating whether the user is viewing offline cell data, the world base map, or the cartographic grid.
class MapStatusBadge extends StatelessWidget {
  final MapCoverageStatus coverageStatus;

  const MapStatusBadge({
    super.key,
    this.coverageStatus = MapCoverageStatus.voidGrid,
  });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final String label;
    final NaIconData iconData;
    final Color iconColor;

    if (this.coverageStatus == MapCoverageStatus.offlineData) {
      label     = l10n.mapStatusOfflineReady;
      iconData  = NaIcons.cloudDone;
      iconColor = AppColors.detailComplete(context);
    }else if (this.coverageStatus == MapCoverageStatus.worldBase) {
      label     = l10n.mapStatusWorldOverview;
      iconData  = NaIcons.public;
      iconColor = AppColors.primary(context);
    }else {
      label     = l10n.mapVoidGridBadge;
      iconData  = NaIcons.map;
      iconColor = AppColors.textSecondary(context);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p12,
        vertical  : AppSizes.p6,
      ),
      decoration: BoxDecoration(
        color       : AppColors.surface(context).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSizes.radius20),
        border      : Border.all(
          color: AppColors.border(context),
        ),
        boxShadow: [
          BoxShadow(
            color     : AppColors.shadow(context),
            blurRadius: AppSizes.shadowBlur10,
            offset    : AppSizes.shadowOffset4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children    : [
          // Coverage status icon
          NaIcon(
            iconData,
            size : AppSizes.icon16,
            color: iconColor,
          ),

          // Horizontal spacing between icon and badge label
          const SizedBox(width: AppSizes.p8),

          // Badge status text
          Text(
            label,
            style: TextStyle(
              fontSize  : AppSizes.font12,
              fontWeight: FontWeight.w600,
              color     : AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
