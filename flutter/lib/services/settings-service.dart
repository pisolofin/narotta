import 'package:flutter/material.dart';

import 'package:nanna/nanna.dart';

import '../models/map-display-style.model.dart';

/// Service managing global application settings and persisting user preferences locally.
class SettingsService extends ChangeNotifier {
  static const String _languageCodePreferenceKey        = 'settings_language_code';
  static const String _themeModePreferenceKey           = 'settings_theme_mode';
  static const String _downloadWifiOnlyPreferenceKey    = 'settings_download_wifi_only';
  static const String _mapServerUrlPreferenceKey        = 'settings_map_server_url';
  static const String _mapDisplayStylePreferenceKey     = 'settings_map_display_style';
  static const String _customMapsDirectoryPreferenceKey = 'settings_custom_maps_directory';

  static const String _lightThemeValue = 'light';
  static const String _darkThemeValue  = 'dark';

  static const String serverLocalhost       = 'http://localhost:5001';
  static const String serverAndroidEmulator = 'http://10.0.2.2:5001';
  static const String serverLan             = 'http://192.168.8.53:5001';
  static const String serverProduction      = 'https://maps.narotta.app';
  static const String defaultMapServerUrl   = serverAndroidEmulator;

  static final SettingsService _instance = SettingsService._internal();

  /// Returns the singleton instance of [SettingsService].
  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  String?         _languageCode;
  ThemeMode       _themeMode        = ThemeMode.system;
  bool            _downloadWifiOnly = true;
  String          _mapServerUrl     = defaultMapServerUrl;
  MapDisplayStyle _mapDisplayStyle  = MapDisplayStyle.tactical;
  String?         _customMapsDirectory;

  /// Returns the currently selected language code (`'it'`, `'en'`), or `null` for system default.
  String? get languageCode => _languageCode;

  /// Returns the currently selected [ThemeMode].
  ThemeMode get themeMode => _themeMode;

  /// Whether map downloads should only be performed over Wi-Fi.
  bool get downloadWifiOnly => _downloadWifiOnly;

  /// Map distribution Web API server URL.
  String get mapServerUrl => _mapServerUrl;

  /// Currently selected map visualization style.
  MapDisplayStyle get mapDisplayStyle => _mapDisplayStyle;

  /// Custom directory path for map downloads, or null for default path.
  String? get customMapsDirectory => _customMapsDirectory;

  /// Returns a concise display hostname/address for [url].
  static String getServerShortLabel(String url) {
    if (url == serverLocalhost) {
      return 'localhost:5001';
    }
    if (url == serverAndroidEmulator) {
      return '10.0.2.2:5001';
    }
    if (url == serverLan) {
      return '192.168.8.53:5001';
    }
    if (url == serverProduction) {
      return 'maps.narotta.app';
    }
    return url;
  }

  /// Returns whether [url] is a user-defined custom address rather than a built-in preset.
  static bool isCustomServerUrl(String url) {
    return (url != serverLocalhost) &&
        (url != serverAndroidEmulator) &&
        (url != serverLan) &&
        (url != serverProduction);
  }

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

      _downloadWifiOnly = NaPreferences.getBool(_downloadWifiOnlyPreferenceKey) ?? true;

      final String? savedServerUrl = NaPreferences.getString(_mapServerUrlPreferenceKey);
      if ((savedServerUrl != null) && savedServerUrl.isNotEmpty) {
        _mapServerUrl = savedServerUrl;
      }else {
        _mapServerUrl = defaultMapServerUrl;
      }

      final String? savedStyle = NaPreferences.getString(_mapDisplayStylePreferenceKey);
      _mapDisplayStyle         = MapDisplayStyle.fromName(savedStyle);

      final String? savedCustomDir = NaPreferences.getString(_customMapsDirectoryPreferenceKey);
      _customMapsDirectory         = ((savedCustomDir != null) && savedCustomDir.trim().isNotEmpty)
        ? savedCustomDir.trim()
        : null
      ;
    }catch (_) {
      _languageCode        = null;
      _themeMode           = ThemeMode.system;
      _downloadWifiOnly    = true;
      _mapServerUrl        = defaultMapServerUrl;
      _mapDisplayStyle     = MapDisplayStyle.tactical;
      _customMapsDirectory = null;
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

  /// Updates the map display style and persists the preference.
  Future updateMapDisplayStyleAsync(MapDisplayStyle style) async {
    if (_mapDisplayStyle == style) {
      return;
    }

    _mapDisplayStyle = style;

    try {
      await NaPreferences.setString(_mapDisplayStylePreferenceKey, style.name);
    }catch (_) {
      // Ignore persistence errors in test environments
    }

    notifyListeners();
  }

  /// Updates the custom maps download directory and persists the preference.
  Future updateCustomMapsDirectoryAsync(String? directoryPath) async {
    final String? normalizedPath = ((directoryPath == null) || directoryPath.trim().isEmpty)
      ? null
      : directoryPath.trim()
    ;
    if (_customMapsDirectory == normalizedPath) {
      return;
    }

    _customMapsDirectory = normalizedPath;

    try {
      if (_customMapsDirectory == null) {
        await NaPreferences.remove(_customMapsDirectoryPreferenceKey);
      }else {
        await NaPreferences.setString(_customMapsDirectoryPreferenceKey, _customMapsDirectory!);
      }
    }catch (_) {
      // Ignore persistence errors
    }

    notifyListeners();
  }
}
