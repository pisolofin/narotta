import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/location-service.dart';

/// Floating telemetry card displaying real-time GPS telemetry and tracking status.
class MapTelemetryCard extends StatefulWidget {
  final LocationStatus status;
  final Position? position;
  final bool isFollowingUser;
  final VoidCallback onRefresh;

  const MapTelemetryCard({
    super.key,
    required this.status,
    required this.position,
    required this.isFollowingUser,
    required this.onRefresh,
  });

  @override
  State<MapTelemetryCard> createState() => _MapTelemetryCardState();
}

class _MapTelemetryCardState extends State<MapTelemetryCard> {
  static const int _coordinateDecimalDigits = 6;
  static const int _metricDecimalDigits = 1;
  static const double _metersPerSecondToKmh = 3.6;

  bool _isExpanded = false;

  /// Returns the localized status message when a GPS position is not available.
  String _getStatusMessage(LocationStatus status, AppLocalizations l10n) {
    if (status == LocationStatus.serviceDisabled) {
      return l10n.locationServiceDisabled;
    }
    if (status == LocationStatus.permissionDenied) {
      return l10n.locationPermissionDenied;
    }
    if (status == LocationStatus.error) {
      return l10n.locationError;
    }
    return l10n.locationSearching;
  }

  /// Builds the coordinate text and metric chips row for active GPS position.
  Widget _buildCoordinatesHeader(BuildContext context, Position position, AppLocalizations l10n) {
    final String latitudeText = position.latitude.toStringAsFixed(_coordinateDecimalDigits);
    final String longitudeText = position.longitude.toStringAsFixed(_coordinateDecimalDigits);

    return Text(
      l10n.locationCoordinates(latitudeText, longitudeText),
      style: TextStyle(
        fontSize  : AppSizes.font14,
        fontWeight: FontWeight.bold,
        color     : AppColors.textPrimary(context),
      ),
    );
  }

  /// Builds the full telemetry telemetry metrics in expanded view.
  Widget _buildExpandedTelemetry(BuildContext context, Position position, AppLocalizations l10n) {
    final String accuracyText = position.accuracy.toStringAsFixed(_metricDecimalDigits);
    final String altitudeText = position.altitude.toStringAsFixed(_metricDecimalDigits);
    final double rawSpeedKmh = (position.speed > 0.0) ? (position.speed * _metersPerSecondToKmh) : 0.0;
    final String speedText = rawSpeedKmh.toStringAsFixed(_metricDecimalDigits);
    final String headingText = (position.heading >= 0.0)
      ? position.heading.toStringAsFixed(0)
      : 0.0.toStringAsFixed(0)
    ;

    return Wrap(
      spacing   : AppSizes.p16,
      runSpacing: AppSizes.p8,
      children  : [
        // Accuracy label
        Text(
          l10n.locationAccuracyValue(accuracyText),
          style: TextStyle(
            fontSize: AppSizes.font12,
            color   : AppColors.textSecondary(context),
          ),
        ),

        // Altitude label
        Text(
          l10n.locationAltitudeValue(altitudeText),
          style: TextStyle(
            fontSize: AppSizes.font12,
            color   : AppColors.textSecondary(context),
          ),
        ),

        // Speed label
        Text(
          l10n.locationSpeedValue(speedText),
          style: TextStyle(
            fontSize: AppSizes.font12,
            color   : AppColors.textSecondary(context),
          ),
        ),

        // Heading direction label
        Text(
          l10n.mapHeadingValue(headingText),
          style: TextStyle(
            fontSize: AppSizes.font12,
            color   : AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Position? position = widget.position;
    final LocationStatus status = widget.status;
    final bool isLoading = (status == LocationStatus.loading) && (position == null);

    final String modeLabel = widget.isFollowingUser
      ? l10n.mapFollowingUser
      : l10n.mapFreeExploration
    ;

    return Container(
      width     : double.infinity,
      padding   : const EdgeInsets.all(AppSizes.p16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize      : MainAxisSize.min,
        children          : [
          // Header row with pin icon, mode indicator, and action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children         : [
              // Title and status badge group
              Row(
                mainAxisSize: MainAxisSize.min,
                children    : [
                  // Location pin icon
                  NaIcon(
                    NaIcons.locationOn,
                    size : AppSizes.icon20,
                    color: AppColors.primary(context),
                  ),

                  // Horizontal spacing between icon and title
                  const SizedBox(width: AppSizes.p8),

                  // Position title
                  Text(
                    l10n.locationCurrentPositionTitle,
                    style: TextStyle(
                      fontSize  : AppSizes.font14,
                      fontWeight: FontWeight.bold,
                      color     : AppColors.textPrimary(context),
                    ),
                  ),

                  // Horizontal spacing before mode chip
                  const SizedBox(width: AppSizes.p8),

                  // Mode badge indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p6,
                      vertical  : AppSizes.p2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isFollowingUser
                        ? AppColors.primary(context).withValues(alpha: 0.12)
                        : AppColors.surface(context),
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                      border      : Border.all(
                        color: widget.isFollowingUser
                          ? AppColors.primary(context).withValues(alpha: 0.3)
                          : AppColors.border(context),
                      ),
                    ),
                    child: Text(
                      modeLabel,
                      style: TextStyle(
                        fontSize  : AppSizes.font10,
                        fontWeight: FontWeight.bold,
                        color     : widget.isFollowingUser
                          ? AppColors.primary(context)
                          : AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),

              // Action buttons group (refresh + collapse/expand)
              Row(
                mainAxisSize: MainAxisSize.min,
                children    : [
                  // Refresh GPS fix button
                  NaIconButton(
                    icon     : const NaIcon(NaIcons.refresh),
                    onPressed: widget.onRefresh,
                  ),

                  // Toggle expanded telemetry button
                  if (position != null) ...[
                    NaIconButton(
                      icon: NaIcon(
                        _isExpanded ? NaIcons.expandLess : NaIcons.expandMore,
                      ),
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Vertical spacing between header and content
          const SizedBox(height: AppSizes.p8),

          // Position coordinates summary
          if (position != null) ...[
            _buildCoordinatesHeader(context, position, l10n),
          ],

          // Expanded telemetry rows
          if ((position != null) && _isExpanded) ...[
            const SizedBox(height: AppSizes.p8),
            _buildExpandedTelemetry(context, position, l10n),
          ],

          // Loading indicator when acquiring GPS fix
          if (isLoading) ...[
            Row(
              children: [
                // Loading spinner
                const NaProgressIndicator(),

                // Spacing between spinner and text
                const SizedBox(width: AppSizes.p12),

                // Searching status message
                Expanded(
                  child: Text(
                    l10n.locationSearching,
                    style: TextStyle(
                      fontSize: AppSizes.font14,
                      color   : AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Error or disabled service message
          if ((position == null) && (!isLoading)) ...[
            Text(
              _getStatusMessage(status, l10n),
              style: TextStyle(
                fontSize: AppSizes.font14,
                color   : AppColors.textSecondary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
