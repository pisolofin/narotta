import 'package:flutter/widgets.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';

/// Displays the main map viewport (currently in empty placeholder state with no cartographic data).
class MapView extends StatelessWidget {
  const MapView({ super.key });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Container(
      width : double.infinity,
      height: double.infinity,
      color : AppColors.background(context),
      child : Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child  : Container(
            padding   : const EdgeInsets.all(AppSizes.p24),
            decoration: BoxDecoration(
              color       : AppColors.surface(context),
              borderRadius: BorderRadius.circular(AppSizes.radius16),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children    : [
                // Map placeholder icon
                NaIcon(
                  NaIcons.map,
                  size : AppSizes.icon64,
                  color: AppColors.primary(context),
                ),

                // Vertical spacing between icon and title
                const SizedBox(height: AppSizes.p16),

                // Empty map state title
                Text(
                  l10n.mapEmptyTitle,
                  textAlign: TextAlign.center,
                  style    : TextStyle(
                    fontSize  : AppSizes.font18,
                    fontWeight: FontWeight.bold,
                    color     : AppColors.textPrimary(context),
                  ),
                ),

                // Vertical spacing between title and description
                const SizedBox(height: AppSizes.p8),

                // Empty map state description
                Text(
                  l10n.mapEmptySubtitle,
                  textAlign: TextAlign.center,
                  style    : TextStyle(
                    fontSize: AppSizes.font14,
                    color   : AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
