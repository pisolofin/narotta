import 'package:flutter/widgets.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';

/// Floating top badge indicating the cartographic void grid state.
class MapStatusBadge extends StatelessWidget {
  const MapStatusBadge({ super.key });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

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
          // Grid indicator icon
          NaIcon(
            NaIcons.map,
            size : AppSizes.icon16,
            color: AppColors.primary(context),
          ),

          // Horizontal spacing between icon and badge label
          const SizedBox(width: AppSizes.p8),

          // Badge status text
          Text(
            l10n.mapVoidGridBadge,
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
