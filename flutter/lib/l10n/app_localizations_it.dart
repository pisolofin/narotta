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
  String get mapVoidGridBadge =>
      'Reticolo cartografico • In attesa della mappa';

  @override
  String get mapZoomIn => 'Ingrandisci';

  @override
  String get mapZoomOut => 'Rimpicciolisci';

  @override
  String get mapRecenter => 'Ricentra sulla posizione';

  @override
  String get mapFollowingUser => 'Centrato';

  @override
  String get mapFreeExploration => 'Esplorazione libera';

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
    return 'Direzione: $degrees°';
  }

  @override
  String get mapTelemetryToggle => 'Dettagli telemetria';

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

  @override
  String get settingsMapsSection => 'Mappe e Download Offline';

  @override
  String get settingsMapDownloadMode => 'Modalità di download';

  @override
  String get settingsMapDownloadModeSelect => 'Seleziona modalità di download';

  @override
  String get settingsMapModeByRegionTitle => 'Per Stato o Regione';

  @override
  String get settingsMapModeByRegionDesc =>
      'Scarica intere nazioni o regioni amministrative dal catalogo';

  @override
  String get settingsMapModeCircleAreaTitle => 'Cerchia con il dito';

  @override
  String get settingsMapModeCircleAreaDesc =>
      'Disegna a mano libera sulla mappa e scarica solo l\'area desiderata';

  @override
  String get settingsMapModeRouteCorridorTitle => 'Solo lungo la rotta';

  @override
  String get settingsMapModeRouteCorridorDesc =>
      'Dettaglio nel corridoio ±15 km e destinazione HD, mappa base altrove';

  @override
  String get settingsMapCircleDownloadAction => 'Cerchia e scarica';

  @override
  String get settingsMapCircleDownloadDesc =>
      'Seleziona e scarica celle 0.5° × 0.5° col dito';

  @override
  String get settingsMapWifiOnlyTitle => 'Scarica solo con Wi-Fi';

  @override
  String get settingsMapWifiOnlyDesc =>
      'Evita il consumo della connessione dati cellulare';

  @override
  String get settingsMapLayersSection => 'Livelli di dettaglio aggiuntivi';

  @override
  String get settingsMapLayerBuildingsTitle => 'Edifici 3D (Z13–15)';

  @override
  String get settingsMapLayerBuildingsDesc =>
      'Estrusioni volumetriche degli isolati urbani';

  @override
  String get settingsMapLayerPedestrianTitle =>
      'Pedonale e Mobilità Dolce (Z13–15)';

  @override
  String get settingsMapLayerPedestrianDesc =>
      'Sentieri, marciapiedi e percorsi a piedi Park & Walk';

  @override
  String get settingsMapLayerTerrainTitle => 'Rilievi altimetrici HD';

  @override
  String get settingsMapLayerTerrainDesc =>
      'Modelli DEM e curve di livello montane';

  @override
  String get settingsMapServerUrlTitle => 'Server Mappe Web API';

  @override
  String get settingsMapServerUrlDesc =>
      'Indirizzo del servizio di distribuzione mappe';

  @override
  String get settingsMapServerUrlDialogTitle => 'Configura Server Mappe';

  @override
  String get settingsMapServerLocalhost => 'Server Locale (localhost:5001)';

  @override
  String get settingsMapServerLocalhostDesc =>
      'Per sviluppo e test su Windows o Mac';

  @override
  String get settingsMapServerAndroidEmulator =>
      'Emulatore Android (10.0.2.2:5001)';

  @override
  String get settingsMapServerAndroidEmulatorDesc =>
      'Alias di rete predefinito per emulatore Android';

  @override
  String get settingsMapServerLan => 'Rete Locale (192.168.8.53:5001)';

  @override
  String get settingsMapServerLanDesc =>
      'Server storage MapBuilder su rete LAN locale';

  @override
  String get settingsMapServerProduction => 'Produzione (maps.narotta.app)';

  @override
  String get settingsMapServerProductionDesc =>
      'Server cloud ufficiale di distribuzione mappe';

  @override
  String get settingsMapServerCustom => 'URL Personalizzato...';

  @override
  String get settingsMapServerCustomDesc =>
      'Inserisci manualmente l\'indirizzo IP e la porta';

  @override
  String get settingsMapServerCustomHint => 'http://192.168.x.x:5001';

  @override
  String get commonSave => 'Salva';

  @override
  String get circleDownloadTitle => 'Cerchia e Scarica';

  @override
  String get circleDownloadDrawInstruction =>
      'Disegna un cerchio o poligono col dito per delimitare l\'area';

  @override
  String get circleDownloadModeDraw => 'Disegna';

  @override
  String get circleDownloadModePan => 'Sposta';

  @override
  String get circleDownloadActionClear => 'Cancella';

  @override
  String get circleDownloadActionRecenter => 'Centra';

  @override
  String circleDownloadSelectedCellsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other : '$count celle (0.5° × 0.5°)',
      one   : '1 cella (0.5° × 0.5°)',
    );
    return '$_temp0';
  }

  @override
  String circleDownloadEstimatedSize(String size) {
    return 'Dimensione stimata: $size MB';
  }

  @override
  String get circleDownloadActionDownload => 'Scarica area selezionata';

  @override
  String circleDownloadProgressPercent(int percent) {
    return 'Download in corso: $percent%';
  }

  @override
  String get circleDownloadCompleted => 'Download completato con successo!';

  @override
  String get circleDownloadNoSelectionHint =>
      'Nessuna area selezionata. Tocca \'Disegna\' e traccia col dito sulla mappa.';

  @override
  String get circleDownloadLayerBase => 'Base Guida';

  @override
  String get circleDownloadLayerBuildings => 'Edifici 3D';

  @override
  String get circleDownloadLayerPedestrian => 'Pedonale';
}
