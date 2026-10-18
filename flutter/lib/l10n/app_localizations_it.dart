// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get commonAppTitle => 'NaRotta';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonSystemDefault => 'Predefinito di sistema';

  @override
  String get mapTab => 'Mappa';

  @override
  String get settingsTab => 'Impostazioni';

  @override
  String get mapEmptyTitle => 'Nessun dato cartografico';

  @override
  String get mapEmptySubtitle =>
      'I dati cartografici offline non sono ancora stati caricati.';

  @override
  String get locationCurrentPositionTitle => 'Posizione corrente';

  @override
  String get locationSearching => 'Rilevamento posizione GPS in corso...';

  @override
  String get locationServiceDisabled =>
      'Servizi di localizzazione disattivati sul dispositivo.';

  @override
  String get locationPermissionDenied => 'Permesso di localizzazione negato.';

  @override
  String get locationError => 'Impossibile rilevare la posizione corrente.';

  @override
  String get locationRefresh => 'Aggiorna posizione';

  @override
  String locationCoordinates(String latitude, String longitude) {
    return '$latitude, $longitude';
  }

  @override
  String locationAccuracyValue(String meters) {
    return 'Precisione: ±$meters m';
  }

  @override
  String locationAltitudeValue(String meters) {
    return 'Altitudine: $meters m';
  }

  @override
  String locationSpeedValue(String kmh) {
    return 'Velocità: $kmh km/h';
  }

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsGeneralSection => 'Generali';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get settingsLanguageSelect => 'Seleziona lingua';

  @override
  String get settingsLanguageItalian => 'Italiano';

  @override
  String get settingsLanguageEnglish => 'Inglese';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSelect => 'Seleziona tema';

  @override
  String get settingsLightTheme => 'Chiaro';

  @override
  String get settingsDarkTheme => 'Scuro';
}
