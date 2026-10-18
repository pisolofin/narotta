import 'package:nanna/nanna.dart';
import 'package:flutter/material.dart';

/// Service managing global application settings and persisting user preferences locally.
class SettingsService extends ChangeNotifier {
  static const String _languageCodePreferenceKey = 'settings_language_code';
  static const String _themeModePreferenceKey    = 'settings_theme_mode';
  static const String _lightThemeValue           = 'light';
  static const String _darkThemeValue            = 'dark';

  static final SettingsService _instance = SettingsService._internal();

  /// Returns the singleton instance of [SettingsService].
  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  String?   _languageCode;
  ThemeMode _themeMode = ThemeMode.system;

  /// Returns the currently selected language code (`'it'`, `'en'`), or `null` for system default.
  String? get languageCode => _languageCode;

  /// Returns the currently selected [ThemeMode].
  ThemeMode get themeMode => _themeMode;

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
    }catch (_) {
      _languageCode = null;
      _themeMode    = ThemeMode.system;
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
      // Ignore persistence errors when NaPreferences is not initialized (e.g. in widget tests)
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
      // Ignore persistence errors when NaPreferences is not initialized (e.g. in widget tests)
    }

    notifyListeners();
  }
}
