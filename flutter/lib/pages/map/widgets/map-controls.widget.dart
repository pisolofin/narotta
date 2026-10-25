import 'package:flutter/widgets.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';

/// Floating map controls for zoom and recentering.
class MapControls extends StatelessWidget {
  final bool isFollowingUser;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;

  const MapControls({
    super.key,
    required this.isFollowingUser,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
  });

  /// Builds an individual circular control button with elevation and border.
  Widget _buildControlButton({
    required BuildContext context,
    required Widget icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    final Color backgroundColor = isActive
      ? AppColors.primary(context)
      : AppColors.surface(context)
    ;
    final Color borderColor = isActive
      ? AppColors.primary(context)
      : AppColors.border(context)
    ;

    return Container(
      width     : AppSizes.mapControlWidth,
      height    : AppSizes.mapControlHeight,
      decoration: BoxDecoration(
        color       : backgroundColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        border      : Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color     : AppColors.shadow(context),
            blurRadius: AppSizes.shadowBlur10,
            offset    : AppSizes.shadowOffset4,
          ),
        ],
      ),
      child: Center(
        child: NaIconButton(
          icon     : icon,
          onPressed: onPressed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children    : [
        // Recenter on user position button
        _buildControlButton(
          context: context,
          icon   : NaIcon(
            NaIcons.myLocation,
            size : AppSizes.icon20,
            color: this.isFollowingUser
              ? AppColors.white(context)
              : AppColors.primary(context),
          ),
          isActive : this.isFollowingUser,
          onPressed: this.onRecenter,
        ),

        // Vertical spacing between recenter and zoom group
        const SizedBox(height: AppSizes.p12),

        // Zoom in button
        _buildControlButton(
          context: context,
          icon   : NaIcon(
            NaIcons.add,
            size : AppSizes.icon20,
            color: AppColors.textPrimary(context),
          ),
          onPressed: this.onZoomIn,
        ),

        // Vertical spacing between zoom in and zoom out
        const SizedBox(height: AppSizes.p8),

        // Zoom out button
        _buildControlButton(
          context: context,
          icon   : NaIcon(
            NaIcons.remove,
            size : AppSizes.icon20,
            color: AppColors.textPrimary(context),
          ),
          onPressed: this.onZoomOut,
        ),
      ],
    );
  }
}
