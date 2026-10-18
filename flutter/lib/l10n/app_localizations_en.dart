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
}
