import '../l10n/app_localizations.dart';

/// Available cartographic display styles for map visualization.
///
/// Every display style is designed to seamlessly support both Light and Dark themes,
/// dynamically adapting background void, landmasses, roads, labels, and precision reticles.
enum MapDisplayStyle {
  /// High-contrast tactical cartography with coordinate reticles, clean vector landmasses,
  /// city landmarks, and major highway spines.
  tactical;

  /// Parses a persisted string into a [MapDisplayStyle], defaulting to [tactical].
  static MapDisplayStyle fromName(String? rawName) {
    if (rawName == 'tactical') {
      return MapDisplayStyle.tactical;
    }
    return MapDisplayStyle.tactical;
  }

  /// Returns the localized title of this map display style.
  String getTitle(AppLocalizations l10n) {
    if (this == MapDisplayStyle.tactical) {
      return l10n.mapStyleTacticalTitle;
    }
    return l10n.mapStyleTacticalTitle;
  }

  /// Returns the localized description explaining this map display style.
  String getDescription(AppLocalizations l10n) {
    if (this == MapDisplayStyle.tactical) {
      return l10n.mapStyleTacticalDesc;
    }
    return l10n.mapStyleTacticalDesc;
  }
}
