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
  String get settingsMapsSection => 'Maps & Offline Downloads';

  @override
  String get settingsMapDownloadMode => 'Download mode';

  @override
  String get settingsMapDownloadModeSelect => 'Select download mode';

  @override
  String get settingsMapModeByRegionTitle => 'By Country or Region';

  @override
  String get settingsMapModeByRegionDesc =>
      'Download full countries or administrative regions from catalog';

  @override
  String get settingsMapModeCircleAreaTitle => 'Circle with finger';

  @override
  String get settingsMapModeCircleAreaDesc =>
      'Draw freehand on the map to download only the desired area';

  @override
  String get settingsMapModeRouteCorridorTitle => 'Along route only';

  @override
  String get settingsMapModeRouteCorridorDesc =>
      'Detail in +/-15 km corridor and HD destination, base map elsewhere';

  @override
  String get settingsMapCircleDownloadAction => 'Circle and download';

  @override
  String get settingsMapCircleDownloadDesc =>
      'Select and download 0.5 x 0.5 cells with your finger';

  @override
  String get settingsMapWifiOnlyTitle => 'Download via Wi-Fi only';

  @override
  String get settingsMapWifiOnlyDesc =>
      'Prevent cellular data usage during map downloads';

  @override
  String get settingsMapLayersSection => 'Additional Detail Layers';

  @override
  String get settingsMapLayerBuildingsTitle => '3D Buildings (Z13-15)';

  @override
  String get settingsMapLayerBuildingsDesc =>
      'Volumetric extrusions of urban blocks';

  @override
  String get settingsMapLayerPedestrianTitle =>
      'Pedestrian & Soft Mobility (Z13-15)';

  @override
  String get settingsMapLayerPedestrianDesc =>
      'Walking paths, hiking trails and Park & Walk';

  @override
  String get settingsMapLayerTerrainTitle => 'HD Elevation Contours';

  @override
  String get settingsMapLayerTerrainDesc =>
      'DEM elevation models and mountain contour lines';

  @override
  String get settingsMapServerUrlTitle => 'Map Server Web API';

  @override
  String get settingsMapServerUrlDesc => 'Map distribution service address';

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
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get circleDownloadTitle => 'Circle & Download';

  @override
  String get circleDownloadDrawInstruction =>
      'Draw a circle or polygon with your finger to select an area';

  @override
  String get circleDownloadModeDraw => 'Draw';

  @override
  String get circleDownloadModePan => 'Pan';

  @override
  String get circleDownloadActionClear => 'Clear';

  @override
  String get circleDownloadActionRecenter => 'Recenter';

  @override
  String circleDownloadSelectedCellsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cells (0.5 x 0.5)',
      one: '1 cell (0.5 x 0.5)',
    );
    return '$_temp0';
  }

  @override
  String circleDownloadEstimatedSize(String size) {
    return 'Estimated size: $size MB';
  }

  @override
  String get circleDownloadActionDownload => 'Download selected area';

  @override
  String circleDownloadProgressPercent(int percent) {
    return 'Downloading: $percent%';
  }

  @override
  String get circleDownloadCompleted => 'Download successfully completed!';

  @override
  String get circleDownloadNoSelectionHint =>
      'No area selected. Tap \'Draw\' and trace with your finger on the map.';

  @override
  String get circleDownloadLayerBase => 'Base Driving';

  @override
  String get circleDownloadLayerBuildings => '3D Buildings';

  @override
  String get circleDownloadLayerPedestrian => 'Pedestrian';

  @override
  String get settingsMapDownloadManagerTitle => 'Download offline maps';

  @override
  String get settingsMapDownloadManagerDesc =>
      'World map, countries and regions with detail selection';

  @override
  String get mapDownloadTitle => 'Offline Maps Download';

  @override
  String get mapDownloadWorldSection => 'World Base Map';

  @override
  String get mapDownloadWorldDesc =>
      'Global overview (Zoom 0-7) - Essential for offline orientation across countries and continents';

  @override
  String mapDownloadWorldDownloadBtn(String size) {
    return 'Download World Base Map ($size MB)';
  }

  @override
  String get mapDownloadWorldDownloaded => 'World Map downloaded';

  @override
  String get mapDownloadRegionsSection => 'Countries and Regions';

  @override
  String get mapDownloadRegionsDesc =>
      'Select a country or region to choose detail level and download';

  @override
  String get mapDownloadRegionsSearchHint => 'Search country or region...';

  @override
  String get mapDownloadDetailLevelTitle => 'Detail level';

  @override
  String mapDownloadDetailSelectFor(String name) {
    return 'Select detail for $name';
  }

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
  String get mapDownloadDetailBaseBadge => 'Base';

  @override
  String get mapDownloadDetailDetailedBadge => 'Detailed';

  @override
  String get mapDownloadDetailCompleteBadge => 'Complete';

  @override
  String get mapDownloadStatusDownloaded => 'Downloaded';

  @override
  String get mapDownloadStatusNotDownloaded => 'Not downloaded';

  @override
  String mapDownloadStatusDownloading(int percent) {
    return 'Downloading ($percent%)';
  }

  @override
  String mapDownloadActionDownload(String size) {
    return 'Download ($size MB)';
  }

  @override
  String get mapDownloadActionUpdate => 'Update detail level';

  @override
  String get mapDownloadActionDelete => 'Delete downloaded map';

  @override
  String get mapDownloadActionDeleteConfirmTitle => 'Delete map';

  @override
  String mapDownloadActionDeleteConfirmMsg(String name) {
    return 'Are you sure you want to delete offline data for $name?';
  }

  @override
  String get mapDownloadCircleActionTitle => 'Circle and download on map';

  @override
  String get mapDownloadCircleActionDesc =>
      'Draw freehand on the world map to download only desired cells';

  @override
  String get circleDownloadDetailModalTitle =>
      'Download detail for selected area';

  @override
  String get circleDownloadLegendTitle => 'Downloaded levels:';

  @override
  String get circleDownloadLegendBase => 'Base';

  @override
  String get circleDownloadLegendDetailed => 'Detailed';

  @override
  String get circleDownloadLegendComplete => 'Complete';

  @override
  String circleDownloadCellsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cells selected',
      one: '1 cell selected',
    );
    return '$_temp0';
  }

  @override
  String get circleDownloadActionChooseDetail => 'Choose detail and download';

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
