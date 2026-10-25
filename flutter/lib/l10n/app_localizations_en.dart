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
  String get commonSystemDefault => 'System default';

  @override
  String get mapTab => 'Map';

  @override
  String get settingsTab => 'Settings';

  @override
  String get mapEmptyTitle => 'No map data';

  @override
  String get mapEmptySubtitle => 'Offline map data has not been loaded yet.';

  @override
  String get locationCurrentPositionTitle => 'Current position';

  @override
  String get locationSearching => 'Acquiring GPS position...';

  @override
  String get locationServiceDisabled =>
      'Location services are disabled on this device.';

  @override
  String get locationPermissionDenied => 'Location permission denied.';

  @override
  String get locationError => 'Unable to read current position.';

  @override
  String get locationRefresh => 'Refresh position';

  @override
  String locationCoordinates(String latitude, String longitude) {
    return '$latitude, $longitude';
  }

  @override
  String locationAccuracyValue(String meters) {
    return 'Accuracy: ±$meters m';
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
  String get mapVoidGridBadge => 'Cartographic grid • Waiting for offline map';

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

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
    return 'Heading: $degrees°';
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
  String get settingsMapsSection => 'Maps & Offline Download';

  @override
  String get settingsMapDownloadMode => 'Download mode';

  @override
  String get settingsMapDownloadModeSelect => 'Select download mode';

  @override
  String get settingsMapModeByRegionTitle => 'By Country or Region';

  @override
  String get settingsMapModeByRegionDesc =>
      'Download entire countries or administrative regions from catalog';

  @override
  String get settingsMapModeCircleAreaTitle => 'Circle with finger';

  @override
  String get settingsMapModeCircleAreaDesc =>
      'Draw freehand on the map and download only the desired area';

  @override
  String get settingsMapModeRouteCorridorTitle => 'Route corridor only';

  @override
  String get settingsMapModeRouteCorridorDesc =>
      'Detail within ±15 km corridor and HD destination, base map elsewhere';

  @override
  String get settingsMapCircleDownloadAction => 'Circle & download';

  @override
  String get settingsMapCircleDownloadDesc =>
      'Select and download 0.5° × 0.5° cells with finger';

  @override
  String get settingsMapWifiOnlyTitle => 'Download via Wi-Fi only';

  @override
  String get settingsMapWifiOnlyDesc =>
      'Avoid cellular mobile data consumption';

  @override
  String get settingsMapLayersSection => 'Additional detail layers';

  @override
  String get settingsMapLayerBuildingsTitle => '3D Buildings (Z13–15)';

  @override
  String get settingsMapLayerBuildingsDesc =>
      'Volumetric building extrusions in urban areas';

  @override
  String get settingsMapLayerPedestrianTitle =>
      'Pedestrian & Soft Mobility (Z13–15)';

  @override
  String get settingsMapLayerPedestrianDesc =>
      'Footpaths, sidewalks and Park & Walk navigation';

  @override
  String get settingsMapLayerTerrainTitle => 'High-definition terrain';

  @override
  String get settingsMapLayerTerrainDesc =>
      'DEM elevation models and mountain contour lines';

  @override
  String get settingsMapServerUrlTitle => 'Map Server Web API';

  @override
  String get settingsMapServerUrlDesc =>
      'Address of the map distribution service';

  @override
  String get settingsMapServerUrlDialogTitle => 'Configure Map Server';

  @override
  String get settingsMapServerLocalhost => 'Local Server (localhost:5001)';

  @override
  String get settingsMapServerLocalhostDesc =>
      'For local development on Windows or Mac';

  @override
  String get settingsMapServerAndroidEmulator =>
      'Android Emulator (10.0.2.2:5001)';

  @override
  String get settingsMapServerAndroidEmulatorDesc =>
      'Standard host alias for Android emulator';

  @override
  String get settingsMapServerLan => 'Local LAN (192.168.8.53:5001)';

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
  String get circleDownloadTitle => 'Circle & Download';

  @override
  String get circleDownloadDrawInstruction =>
      'Draw a circle or polygon with your finger to select the area';

  @override
  String get circleDownloadModeDraw => 'Draw';

  @override
  String get circleDownloadModePan => 'Pan';

  @override
  String get circleDownloadActionClear => 'Clear';

  @override
  String get circleDownloadActionRecenter => 'Center';

  @override
  String circleDownloadSelectedCellsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other : '$count cells (0.5° × 0.5°)',
      one   : '1 cell (0.5° × 0.5°)',
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
}
