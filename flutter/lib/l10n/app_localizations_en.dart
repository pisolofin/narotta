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
