// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonAppTitle => 'NaRotta';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonPause => 'Pause';

  @override
  String get commonResume => 'Resume';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSystemDefault => 'System Default';

  @override
  String get mapTab => 'Map';

  @override
  String get settingsTab => 'Settings';

  @override
  String get mapEmptyTitle => 'No cartographic data';

  @override
  String get mapEmptySubtitle => 'Offline map data has not been loaded yet.';

  @override
  String get locationCurrentPositionTitle => 'Current position';

  @override
  String get locationSearching => 'Detecting GPS position...';

  @override
  String get locationServiceDisabled => 'Location services disabled on device.';

  @override
  String get locationPermissionDenied => 'Location permission denied.';

  @override
  String get locationError => 'Unable to detect current position.';

  @override
  String get locationRefresh => 'Refresh position';

  @override
  String locationCoordinates(String latitude, String longitude) {
    return '$latitude, $longitude';
  }

  @override
  String locationAccuracyValue(String meters) {
    return 'Accuracy: +/-$meters m';
  }

  @override
  String locationAltitudeValue(String meters) {
    return 'Altitude: $meters m';
  }

  @override
  String locationSpeedValue(String kmh) {
    return 'Speed: $kmh km/h';
  }

  @override
  String get mapVoidGridBadge => 'Cartographic Grid - Awaiting map data';

  @override
  String get mapStatusOfflineReady => 'Offline map active';

  @override
  String get mapStatusWorldOverview => 'Global base map';

  @override
  String get mapZoomIn => 'Zoom In';

  @override
  String get mapZoomOut => 'Zoom Out';

  @override
  String get mapRecenter => 'Recenter on position';

  @override
  String get mapFollowingUser => 'Centered';

  @override
  String get mapFreeExploration => 'Free exploration';

  @override
  String mapScaleMeters(String meters) {
    return '$meters m';
  }

  @override
  String mapScaleKilometers(String kilometers) {
    return '$kilometers km';
  }

  @override
  String mapHeadingValue(String degrees) {
    return 'Heading: $degrees deg';
  }

  @override
  String get mapTelemetryToggle => 'Telemetry details';

  @override
  String get mapMainStreetLabel => 'Main Street';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneralSection => 'General';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSelect => 'Select language';

  @override
  String get settingsLanguageItalian => 'Italian';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSelect => 'Select theme';

  @override
  String get settingsLightTheme => 'Light';

  @override
  String get settingsDarkTheme => 'Dark';

  @override
  String get settingsMapsSection => 'Maps & Downloads';

  @override
  String get settingsDownloadMapsTitle => 'Download maps';

  @override
  String get settingsMapStorageFolderTitle => 'Map storage folder';

  @override
  String get settingsMapStorageFolderReset => 'Reset to default';

  @override
  String get settingsMapStorageFolderChange => 'Change folder';

  @override
  String get settingsMapStorageFolderDefaultBadge => 'Default';

  @override
  String get settingsMapStyleTitle => 'Map style';

  @override
  String get settingsMapStyleSelect => 'Select map style';

  @override
  String get mapStyleTacticalTitle => 'Tactical Cartographic';

  @override
  String get mapStyleTacticalDesc =>
      'High-contrast vectors with precision grid, cities, and major highways.';

  @override
  String get settingsMapWifiOnlyTitle => 'Download via Wi-Fi only';

  @override
  String get settingsMapWifiOnlyDesc =>
      'Prevent cellular data usage during map downloads';

  @override
  String get settingsMapServerUrlDialogTitle => 'Configure Map Server';

  @override
  String get settingsMapServerLocalhost => 'Local Server (localhost:5001)';

  @override
  String get settingsMapServerLocalhostDesc =>
      'For local development and testing on Windows or Mac';

  @override
  String get settingsMapServerAndroidEmulator =>
      'Android Emulator (10.0.2.2:5001)';

  @override
  String get settingsMapServerAndroidEmulatorDesc =>
      'Default network alias for Android emulator';

  @override
  String get settingsMapServerLan => 'Local Network (192.168.8.53:5001)';

  @override
  String get settingsMapServerLanDesc =>
      'MapBuilder storage server on local LAN';

  @override
  String get settingsMapServerProduction => 'Production (maps.narotta.app)';

  @override
  String get settingsMapServerProductionDesc =>
      'Official cloud map distribution server';

  @override
  String get settingsMapServerCustom => 'Custom URL...';

  @override
  String get settingsMapServerCustomDesc =>
      'Manually enter IP address and port';

  @override
  String get settingsMapServerCustomHint => 'http://192.168.x.x:5001';

  @override
  String get mapDownloadTitle => 'Download Maps';

  @override
  String get mapDownloadServerSection => 'Server';

  @override
  String get mapDownloadServerChecking => 'Checking...';

  @override
  String get mapDownloadServerStatusOnline => 'Online';

  @override
  String get mapDownloadServerStatusOffline => 'Offline';

  @override
  String mapDownloadServerOnline(String url) {
    return 'Map Server online ($url)';
  }

  @override
  String mapDownloadServerOffline(String url) {
    return 'Map Server unreachable ($url)';
  }

  @override
  String mapDownloadServerOfflineError(String url) {
    return 'Unable to download: Map Server ($url) is unreachable. Please verify it is running.';
  }

  @override
  String get mapDownloadBaseMapSection => 'Base map';

  @override
  String get mapDownloadBaseMapTitle => 'World overview map';

  @override
  String mapDownloadBaseMapSubtitle(String size) {
    return 'Zoom 0-7 • ~$size MB';
  }

  @override
  String get mapDownloadBaseMapDownloadAction => 'Download';

  @override
  String get mapDownloadWorldDownloaded => 'Downloaded';

  @override
  String mapDownloadStatusDownloading(int percent) {
    return 'Downloading ($percent%)';
  }

  @override
  String mapDownloadStatusPaused(int percent) {
    return 'Paused ($percent%)';
  }

  @override
  String get mapDownloadActionDeleteConfirmTitle => 'Delete map';

  @override
  String mapDownloadActionDeleteConfirmMsg(String name) {
    return 'Are you sure you want to delete offline data for $name?';
  }

  @override
  String get mapDownloadSelectionSection => 'Selection';

  @override
  String mapDownloadDownloadedZonesBtn(int count) {
    return 'Downloaded zones ($count)';
  }

  @override
  String get mapDownloadSearchPlaceholder =>
      'Search city, region or country...';

  @override
  String get mapDownloadSearchNoResults => 'No results found';

  @override
  String get mapDownloadPlaceTypeCountry => 'Country';

  @override
  String get mapDownloadPlaceTypeRegion => 'Region';

  @override
  String get mapDownloadPlaceTypeCity => 'City';

  @override
  String get mapDownloadPlaceTypeCustom => 'Custom area';

  @override
  String mapDownloadCustomZoneLabel(String coordinates, int count) {
    return 'Area $coordinates ($count cells)';
  }

  @override
  String get mapDownloadLegendLabel => 'Downloaded:';

  @override
  String get mapDownloadDetailBaseTitle => 'Base (Roads & Navigation)';

  @override
  String get mapDownloadDetailBaseDesc =>
      'Full road network, cities and vehicle routing (Z8-14)';

  @override
  String get mapDownloadDetailDetailedTitle =>
      'Detailed (+ Pedestrian & Trails)';

  @override
  String get mapDownloadDetailDetailedDesc =>
      'Roads + hiking trails, walking paths and cycle tracks (Z8-16)';

  @override
  String get mapDownloadDetailCompleteTitle => 'Complete (+ 3D & HD Terrain)';

  @override
  String get mapDownloadDetailCompleteDesc =>
      'Roads + trails + 3D building extrusions and DEM contours (Z8-16)';

  @override
  String get mapDownloadDetailLevelsInfoTitle => 'Map Detail Levels';

  @override
  String get mapDownloadDetailLevelsInfoSubtitle =>
      'Choose the data detail level to download for offline navigation:';

  @override
  String get mapDownloadDetailBaseBadge => 'Base';

  @override
  String get mapDownloadDetailDetailedBadge => 'Detailed';

  @override
  String get mapDownloadDetailCompleteBadge => 'Complete';

  @override
  String get mapDownloadModeRemoveBadge => 'Remove';

  @override
  String get mapDownloadToolPan => 'Pan';

  @override
  String get mapDownloadToolLasso => 'Circle';

  @override
  String get mapDownloadWorldView => 'World view';

  @override
  String get mapDownloadFullscreenEnter => 'Expand map';

  @override
  String get mapDownloadFullscreenExit => 'Collapse map';

  @override
  String get mapDownloadSelectionEmptyHint =>
      'Tap or click cells, use Circle, or search for a city, region, or country.';

  @override
  String mapDownloadSelectedCellsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cells selected',
      one: '1 cell selected',
    );
    return '$_temp0';
  }

  @override
  String mapDownloadNamedSelectionSummary(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cells',
      one: '1 cell',
    );
    return '$name • $_temp0';
  }

  @override
  String mapDownloadRemoveSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloaded cells to remove',
      one: '1 downloaded cell to remove',
      zero: 'No downloaded cells in selection',
    );
    return '$_temp0';
  }

  @override
  String mapDownloadApplyDownloadAction(String level, String size) {
    return 'Download $level (~$size MB)';
  }

  @override
  String mapDownloadApplyRemoveAction(int count) {
    return 'Remove ($count)';
  }

  @override
  String get mapDownloadClearSelectionAction => 'Clear';

  @override
  String get mapDownloadZonesModalTitle => 'Downloaded zones';

  @override
  String get mapDownloadZonesEmptyTitle => 'No downloaded zones';

  @override
  String get mapDownloadZonesEmptyDesc =>
      'Select an area on the world map or search for a city, region, or country to download it.';

  @override
  String get mapDownloadZonesSelectAll => 'Select all';

  @override
  String get mapDownloadZonesDeselectAll => 'Deselect all';

  @override
  String mapDownloadZonesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
      zero: 'None selected',
    );
    return '$_temp0';
  }

  @override
  String get mapDownloadZonesChangeLevelBtn => 'Change level';

  @override
  String get mapDownloadZonesChangeLevelTitle => 'Choose new detail level';

  @override
  String get mapDownloadZonesRemoveBtn => 'Remove';

  @override
  String get mapDownloadZonesRemoveConfirmTitle => 'Remove selected zones';

  @override
  String mapDownloadZonesRemoveConfirmMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Do you want to remove the $count selected zones from the device?',
      one: 'Do you want to remove the selected zone from the device?',
    );
    return '$_temp0';
  }

  @override
  String mapDownloadZoneItemSubtitle(String type, int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cells',
      one: '1 cell',
    );
    return '$type • $_temp0 • ~$size MB';
  }

  @override
  String commonMegabytesValue(String size) {
    return '$size MB';
  }

  @override
  String commonApproximateMegabytesValue(String size) {
    return '~$size MB';
  }

  @override
  String commonPercentValue(int percent) {
    return '$percent%';
  }
}
