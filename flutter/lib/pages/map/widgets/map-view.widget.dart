import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/location-service.dart';

/// Displays the main map viewport (currently in empty placeholder state with live GPS position panel).
class MapView extends StatefulWidget {
  const MapView({ super.key });

  @override
  State<MapView> createState() => _MapViewState();
}

/// State for [MapView].
class _MapViewState extends State<MapView> {
  static const int    _coordinateDecimalDigits = 6;
  static const int    _metricDecimalDigits     = 1;
  static const double _metersPerSecondToKmh    = 3.6;

  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    if (_locationService.status == LocationStatus.idle) {
      _locationService.startTrackingAsync();
    }
  }

  /// Builds the card displaying the empty cartographic state.
  Widget _buildMapPlaceholderCard(BuildContext context, AppLocalizations l10n) {
    return Container(
      width     : double.infinity,
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
    );
  }

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

  /// Builds the coordinate and telemetry details for an active [Position].
  Widget _buildPositionDetails(BuildContext context, Position position, AppLocalizations l10n) {
    final String latitudeText  = position.latitude.toStringAsFixed(_coordinateDecimalDigits);
    final String longitudeText = position.longitude.toStringAsFixed(_coordinateDecimalDigits);
    final String accuracyText  = position.accuracy.toStringAsFixed(_metricDecimalDigits);
    final String altitudeText  = position.altitude.toStringAsFixed(_metricDecimalDigits);
    final double rawSpeedKmh   = (position.speed > 0) ? (position.speed * _metersPerSecondToKmh) : 0.0;
    final String speedText     = rawSpeedKmh.toStringAsFixed(_metricDecimalDigits);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize      : MainAxisSize.min,
      children          : [
        // Coordinates text
        Text(
          l10n.locationCoordinates(latitudeText, longitudeText),
          style: TextStyle(
            fontSize  : AppSizes.font16,
            fontWeight: FontWeight.bold,
            color     : AppColors.textPrimary(context),
          ),
        ),

        // Vertical spacing between coordinates and telemetry metrics
        const SizedBox(height: AppSizes.p8),

        // Accuracy, altitude, and speed telemetry row
        Wrap(
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
          ],
        ),
      ],
    );
  }

  /// Builds the card displaying the current GPS position or tracking status.
  Widget _buildLocationCard(BuildContext context, AppLocalizations l10n) {
    final LocationStatus status   = _locationService.status;
    final Position?      position = _locationService.currentPosition;
    final bool           isLoading = (status == LocationStatus.loading) && (position == null);

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
          // Header row with location icon, title, and refresh button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children         : [
              // Leading icon and title group
              Row(
                mainAxisSize: MainAxisSize.min,
                children    : [
                  // Location pin icon
                  NaIcon(
                    NaIcons.locationOn,
                    size : AppSizes.icon24,
                    color: AppColors.primary(context),
                  ),

                  // Horizontal spacing between icon and title
                  const SizedBox(width: AppSizes.p8),

                  // Current position card title
                  Text(
                    l10n.locationCurrentPositionTitle,
                    style: TextStyle(
                      fontSize  : AppSizes.font16,
                      fontWeight: FontWeight.bold,
                      color     : AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),

              // Refresh location button
              NaIconButton(
                icon     : const NaIcon(NaIcons.refresh),
                onPressed: () {
                  _locationService.refreshPositionAsync();
                },
              ),
            ],
          ),

          // Vertical spacing between header and content
          const SizedBox(height: AppSizes.p12),

          // Position telemetry when available
          if (position != null) ...[
            _buildPositionDetails(context, position, l10n),
          ],

          // Loading indicator when acquiring initial fix
          if (isLoading) ...[
            Row(
              children: [
                // Spinner indicator
                const NaProgressIndicator(),

                // Spacing between spinner and text
                const SizedBox(width: AppSizes.p12),

                // Acquiring GPS message
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

          // Status or error message when position is unavailable and not loading
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: _locationService,
      builder   : (BuildContext context, Widget? child) {
        return Container(
          width : double.infinity,
          height: double.infinity,
          color : AppColors.background(context),
          child : Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child  : Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children         : [
                // Centered map placeholder card
                Expanded(
                  child: Center(
                    child: _buildMapPlaceholderCard(context, l10n),
                  ),
                ),

                // Spacing before bottom GPS status card
                const SizedBox(height: AppSizes.p16),

                // Current GPS position card at the bottom of the map viewport
                _buildLocationCard(context, l10n),
              ],
            ),
          ),
        );
      },
    );
  }
}
