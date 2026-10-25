import 'package:nanna/nanna.dart';
import 'package:flutter/material.dart';

/// Represents the user's selected map download mode based on system documentation.
enum MapDownloadMode {
  /// Mode 1: Download by entire Country or Administrative Region.
  byRegion,

  /// Mode 2: Freehand circle / lasso area drawn with the finger on the map.
  circleArea,

  /// Mode 3: Route corridor only (±15 km driving corridor + ±10 km HD destination).
  routeCorridor,
}

/// Service managing global application settings and persisting user preferences locally.
class SettingsService extends ChangeNotifier {
  static const String _languageCodePreferenceKey     = 'settings_language_code';
  static const String _themeModePreferenceKey        = 'settings_theme_mode';
  static const String _mapDownloadModePreferenceKey  = 'settings_map_download_mode';
  static const String _downloadWifiOnlyPreferenceKey = 'settings_download_wifi_only';
  static const String _includeBuildings3dPreferenceKey = 'settings_include_buildings_3d';
  static const String _includePedestrianPreferenceKey = 'settings_include_pedestrian';
  static const String _includeTerrainHdPreferenceKey = 'settings_include_terrain_hd';
  static const String _mapServerUrlPreferenceKey     = 'settings_map_server_url';

  static const String _lightThemeValue               = 'light';
  static const String _darkThemeValue                = 'dark';

  static const String _modeByRegionValue             = 'by_region';
  static const String _modeCircleAreaValue           = 'circle_area';
  static const String _modeRouteCorridorValue         = 'route_corridor';

  static const String defaultMapServerUrl            = 'http://10.0.2.2:5001';

  static final SettingsService _instance = SettingsService._internal();

  /// Returns the singleton instance of [SettingsService].
  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  String?         _languageCode;
  ThemeMode       _themeMode          = ThemeMode.system;
  MapDownloadMode _mapDownloadMode    = MapDownloadMode.byRegion;
  bool            _downloadWifiOnly   = true;
  bool            _includeBuildings3d = true;
  bool            _includePedestrian  = false;
  bool            _includeTerrainHd   = false;
  String          _mapServerUrl       = defaultMapServerUrl;

  /// Returns the currently selected language code (`'it'`, `'en'`), or `null` for system default.
  String? get languageCode => _languageCode;

  /// Returns the currently selected [ThemeMode].
  ThemeMode get themeMode => _themeMode;

  /// Returns the selected map download mode.
  MapDownloadMode get mapDownloadMode => _mapDownloadMode;

  /// Whether map downloads should only be performed over Wi-Fi.
  bool get downloadWifiOnly => _downloadWifiOnly;

  /// Whether 3D buildings layer should be included by default.
  bool get includeBuildings3d => _includeBuildings3d;

  /// Whether pedestrian / soft mobility layer should be included by default.
  bool get includePedestrian => _includePedestrian;

  /// Whether high-definition terrain elevation layer should be included by default.
  bool get includeTerrainHd => _includeTerrainHd;

  /// Map distribution Web API server URL.
  String get mapServerUrl => _mapServerUrl;

  /// Returns the forced [Brightness] if light or dark mode is explicitly selected, or `null` for system default.
  Brightness? get forcedBrightness {
    if (_themeMode == ThemeMode.light) {
      return Brightness.light;
    }
    if (_themeMode == ThemeMode.dark) {
      return Brightness.dark;
    }
    return null;
  }

  /// Returns the forced [Locale] if a specific language is selected, or `null` for system default.
  Locale? get locale {
    if (_languageCode == null) {
      return null;
    }
    return Locale(_languageCode!);
  }

  /// Loads persisted settings from local storage.
  Future initAsync() async {
    try {
      final String? savedCode = NaPreferences.getString(_languageCodePreferenceKey);
      if ((savedCode != null) && savedCode.isNotEmpty) {
        _languageCode = savedCode;
      }else {
        _languageCode = null;
      }

      final String? savedTheme = NaPreferences.getString(_themeModePreferenceKey);
      if (savedTheme == _lightThemeValue) {
        _themeMode = ThemeMode.light;
      }else if (savedTheme == _darkThemeValue) {
        _themeMode = ThemeMode.dark;
      }else {
        _themeMode = ThemeMode.system;
      }

      final String? savedDownloadMode = NaPreferences.getString(_mapDownloadModePreferenceKey);
      if (savedDownloadMode == _modeCircleAreaValue) {
        _mapDownloadMode = MapDownloadMode.circleArea;
      }else if (savedDownloadMode == _modeRouteCorridorValue) {
        _mapDownloadMode = MapDownloadMode.routeCorridor;
      }else {
        _mapDownloadMode = MapDownloadMode.byRegion;
      }

      _downloadWifiOnly   = NaPreferences.getBool(_downloadWifiOnlyPreferenceKey) ?? true;
      _includeBuildings3d = NaPreferences.getBool(_includeBuildings3dPreferenceKey) ?? true;
      _includePedestrian  = NaPreferences.getBool(_includePedestrianPreferenceKey) ?? false;
      _includeTerrainHd   = NaPreferences.getBool(_includeTerrainHdPreferenceKey) ?? false;

      final String? savedServerUrl = NaPreferences.getString(_mapServerUrlPreferenceKey);
      if ((savedServerUrl != null) && savedServerUrl.isNotEmpty) {
        _mapServerUrl = savedServerUrl;
      }else {
        _mapServerUrl = defaultMapServerUrl;
      }
    }catch (_) {
      _languageCode       = null;
      _themeMode          = ThemeMode.system;
      _mapDownloadMode    = MapDownloadMode.byRegion;
      _downloadWifiOnly   = true;
      _includeBuildings3d = true;
      _includePedestrian  = false;
      _includeTerrainHd   = false;
      _mapServerUrl       = defaultMapServerUrl;
    }
    notifyListeners();
  }

  /// Updates the application language code (`'it'`, `'en'`, or `null` for system default) and persists it.
  Future updateLanguageCodeAsync(String? languageCode) async {
    final String? normalizedCode = ((languageCode == null) || languageCode.isEmpty) ? null : languageCode;
    if (_languageCode == normalizedCode) {
      return;
    }

    _languageCode = normalizedCode;

    try {
      if (_languageCode == null) {
        await NaPreferences.remove(_languageCodePreferenceKey);
      }else {
        await NaPreferences.setString(_languageCodePreferenceKey, _languageCode!);
      }
    }catch (_) {
      // Ignore persistence errors when NaPreferences is not initialized
    }

    notifyListeners();
  }

  /// Updates the application [ThemeMode] and persists the preference.
  Future updateThemeModeAsync(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }

    _themeMode = mode;

    try {
      if (_themeMode == ThemeMode.light) {
        await NaPreferences.setString(_themeModePreferenceKey, _lightThemeValue);
      }else if (_themeMode == ThemeMode.dark) {
        await NaPreferences.setString(_themeModePreferenceKey, _darkThemeValue);
      }else {
        await NaPreferences.remove(_themeModePreferenceKey);
      }
    }catch (_) {
      // Ignore persistence errors when NaPreferences is not initialized
    }

    notifyListeners();
  }

  /// Updates the map download mode and persists it.
  Future updateMapDownloadModeAsync(MapDownloadMode mode) async {
    if (_mapDownloadMode == mode) {
      return;
    }

    _mapDownloadMode = mode;

    try {
      String serializedValue = _modeByRegionValue;
      if (mode == MapDownloadMode.circleArea) {
        serializedValue = _modeCircleAreaValue;
      }else if (mode == MapDownloadMode.routeCorridor) {
        serializedValue = _modeRouteCorridorValue;
      }
      await NaPreferences.setString(_mapDownloadModePreferenceKey, serializedValue);
    }catch (_) {
      // Ignore persistence errors
    }

    notifyListeners();
  }

  /// Updates the Wi-Fi only download preference and persists it.
  Future updateDownloadWifiOnlyAsync(bool value) async {
    if (_downloadWifiOnly == value) {
      return;
    }

    _downloadWifiOnly = value;

    try {
      await NaPreferences.setBool(_downloadWifiOnlyPreferenceKey, value);
    }catch (_) {
      // Ignore persistence errors
    }

    notifyListeners();
  }

  /// Updates whether 3D buildings are included by default.
  Future updateIncludeBuildings3dAsync(bool value) async {
    if (_includeBuildings3d == value) {
      return;
    }

    _includeBuildings3d = value;

    try {
      await NaPreferences.setBool(_includeBuildings3dPreferenceKey, value);
    }catch (_) {
      // Ignore persistence errors
    }

    notifyListeners();
  }

  /// Updates whether pedestrian navigation data is included by default.
  Future updateIncludePedestrianAsync(bool value) async {
    if (_includePedestrian == value) {
      return;
    }

    _includePedestrian = value;

    try {
      await NaPreferences.setBool(_includePedestrianPreferenceKey, value);
    }catch (_) {
      // Ignore persistence errors
    }

    notifyListeners();
  }

  /// Updates whether high-definition terrain is included by default.
  Future updateIncludeTerrainHdAsync(bool value) async {
    if (_includeTerrainHd == value) {
      return;
    }

    _includeTerrainHd = value;

    try {
      await NaPreferences.setBool(_includeTerrainHdPreferenceKey, value);
    }catch (_) {
      // Ignore persistence errors
    }

    notifyListeners();
  }

  /// Updates the Map Server Web API URL and persists it.
  Future updateMapServerUrlAsync(String url) async {
    final String trimmedUrl = url.trim();
    if (_mapServerUrl == trimmedUrl) {
      return;
    }

    _mapServerUrl = trimmedUrl;

    try {
      await NaPreferences.setString(_mapServerUrlPreferenceKey, trimmedUrl);
    }catch (_) {
      // Ignore persistence errors
    }

    notifyListeners();
  }
}
