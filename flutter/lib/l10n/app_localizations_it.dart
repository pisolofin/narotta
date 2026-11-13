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
  String get commonPause => 'Pausa';

  @override
  String get commonResume => 'Riprendi';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonClose => 'Chiudi';

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
    return 'Precisione: +/-$meters m';
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
      'Reticolo cartografico - In attesa della mappa';

  @override
  String get mapStatusOfflineReady => 'Mappa offline attiva';

  @override
  String get mapStatusWorldOverview => 'Mappa base globale';

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
    return 'Direzione: $degrees gradi';
  }

  @override
  String get mapTelemetryToggle => 'Dettagli telemetria';

  @override
  String get mapMainStreetLabel => 'Corso Principale';

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
  String get settingsMapsSection => 'Mappe e download';

  @override
  String get settingsDownloadMapsTitle => 'Scarica mappe';

  @override
  String get settingsMapStorageFolderTitle => 'Cartella di salvataggio mappe';

  @override
  String get settingsMapStorageFolderReset => 'Ripristina predefinita';

  @override
  String get settingsMapStorageFolderChange => 'Cambia cartella';

  @override
  String get settingsMapStorageFolderDefaultBadge => 'Predefinita';

  @override
  String get settingsMapStyleTitle => 'Stile mappa';

  @override
  String get settingsMapStyleSelect => 'Seleziona stile mappa';

  @override
  String get mapStyleTacticalTitle => 'Cartografico Tattico';

  @override
  String get mapStyleTacticalDesc =>
      'Vettori ad alto contrasto con reticolo di precisione, città e dorsali principali.';

  @override
  String get settingsMapWifiOnlyTitle => 'Scarica solo Wi-Fi';

  @override
  String get settingsMapWifiOnlyDesc =>
      'Evita il consumo della connessione dati cellulare';

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
  String get mapDownloadTitle => 'Scarica mappe';

  @override
  String get mapDownloadServerSection => 'Server';

  @override
  String get mapDownloadServerChecking => 'Verifica...';

  @override
  String get mapDownloadServerStatusOnline => 'Online';

  @override
  String get mapDownloadServerStatusOffline => 'Offline';

  @override
  String mapDownloadServerOnline(String url) {
    return 'Server Mappe online ($url)';
  }

  @override
  String mapDownloadServerOffline(String url) {
    return 'Server Mappe non raggiungibile ($url)';
  }

  @override
  String mapDownloadServerOfflineError(String url) {
    return 'Impossibile scaricare: il Server Mappe ($url) non è raggiungibile. Verifica che sia avviato.';
  }

  @override
  String get mapDownloadBaseMapSection => 'Mappa base';

  @override
  String get mapDownloadBaseMapTitle => 'Mappa mondiale panoramica';

  @override
  String mapDownloadBaseMapSubtitle(String size) {
    return 'Zoom 0-7 • ~$size MB';
  }

  @override
  String get mapDownloadBaseMapDownloadAction => 'Scarica';

  @override
  String get mapDownloadWorldDownloaded => 'Scaricata';

  @override
  String mapDownloadStatusDownloading(int percent) {
    return 'Download in corso ($percent%)';
  }

  @override
  String mapDownloadStatusPaused(int percent) {
    return 'In pausa ($percent%)';
  }

  @override
  String get mapDownloadActionDeleteConfirmTitle => 'Elimina mappa';

  @override
  String mapDownloadActionDeleteConfirmMsg(String name) {
    return 'Sei sicuro di voler eliminare i dati offline per $name?';
  }

  @override
  String get mapDownloadSelectionSection => 'Selezione';

  @override
  String mapDownloadDownloadedZonesBtn(int count) {
    return 'Zone scaricate ($count)';
  }

  @override
  String get mapDownloadSearchPlaceholder => 'Cerca città, regione o stato...';

  @override
  String get mapDownloadSearchNoResults => 'Nessun risultato trovato';

  @override
  String get mapDownloadPlaceTypeCountry => 'Stato';

  @override
  String get mapDownloadPlaceTypeRegion => 'Regione';

  @override
  String get mapDownloadPlaceTypeCity => 'Città';

  @override
  String get mapDownloadPlaceTypeCustom => 'Area personalizzata';

  @override
  String mapDownloadCustomZoneLabel(String coordinates, int count) {
    return 'Area $coordinates ($count celle)';
  }

  @override
  String get mapDownloadLegendLabel => 'Scaricate:';

  @override
  String get mapDownloadDetailBaseTitle => 'Base (Stradale & Navigazione)';

  @override
  String get mapDownloadDetailBaseDesc =>
      'Rete stradale completa, città e routing (Z8-14)';

  @override
  String get mapDownloadDetailDetailedTitle =>
      'Dettagliato (+ Sentieri & Pedonale)';

  @override
  String get mapDownloadDetailDetailedDesc =>
      'Stradale + sentieri escursionistici, percorsi a piedi e piste ciclabili (Z8-16)';

  @override
  String get mapDownloadDetailCompleteTitle => 'Completo (+ 3D e Terreno HD)';

  @override
  String get mapDownloadDetailCompleteDesc =>
      'Stradale + sentieri + edifici volumetrici 3D e curve di livello DEM (Z8-16)';

  @override
  String get mapDownloadDetailLevelsInfoTitle =>
      'Livelli di dettaglio della mappa';

  @override
  String get mapDownloadDetailLevelsInfoSubtitle =>
      'Scegli il livello di dati da scaricare per la navigazione offline:';

  @override
  String get mapDownloadDetailBaseBadge => 'Base';

  @override
  String get mapDownloadDetailDetailedBadge => 'Dettagliato';

  @override
  String get mapDownloadDetailCompleteBadge => 'Completo';

  @override
  String get mapDownloadModeRemoveBadge => 'Rimuovi';

  @override
  String get mapDownloadToolPan => 'Sposta';

  @override
  String get mapDownloadToolLasso => 'Cerchia';

  @override
  String get mapDownloadWorldView => 'Vista mondo';

  @override
  String get mapDownloadFullscreenEnter => 'Espandi mappa';

  @override
  String get mapDownloadFullscreenExit => 'Riduci mappa';

  @override
  String get mapDownloadSelectionEmptyHint =>
      'Tocca o clicca sulle celle, usa Cerchia o cerca città, regione o stato.';

  @override
  String mapDownloadSelectedCellsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count celle selezionate',
      one: '1 cella selezionata',
    );
    return '$_temp0';
  }

  @override
  String mapDownloadNamedSelectionSummary(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count celle',
      one: '1 cella',
    );
    return '$name • $_temp0';
  }

  @override
  String mapDownloadRemoveSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count celle scaricate da rimuovere',
      one: '1 cella scaricata da rimuovere',
      zero: 'Nessuna cella scaricata nella selezione',
    );
    return '$_temp0';
  }

  @override
  String mapDownloadApplyDownloadAction(String level, String size) {
    return 'Scarica $level (~$size MB)';
  }

  @override
  String mapDownloadApplyRemoveAction(int count) {
    return 'Rimuovi ($count)';
  }

  @override
  String get mapDownloadClearSelectionAction => 'Deseleziona';

  @override
  String get mapDownloadZonesModalTitle => 'Zone scaricate';

  @override
  String get mapDownloadZonesEmptyTitle => 'Nessuna zona scaricata';

  @override
  String get mapDownloadZonesEmptyDesc =>
      'Seleziona un\'area sulla mappa mondiale o cerca una città, regione o stato per scaricarla.';

  @override
  String get mapDownloadZonesSelectAll => 'Seleziona tutte';

  @override
  String get mapDownloadZonesDeselectAll => 'Deseleziona tutte';

  @override
  String mapDownloadZonesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selezionate',
      one: '1 selezionata',
      zero: 'Nessuna selezionata',
    );
    return '$_temp0';
  }

  @override
  String get mapDownloadZonesChangeLevelBtn => 'Cambia livello';

  @override
  String get mapDownloadZonesChangeLevelTitle =>
      'Scegli nuovo livello di dettaglio';

  @override
  String get mapDownloadZonesRemoveBtn => 'Rimuovi';

  @override
  String get mapDownloadZonesRemoveConfirmTitle => 'Rimuovi zone selezionate';

  @override
  String mapDownloadZonesRemoveConfirmMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vuoi rimuovere le $count zone selezionate dal dispositivo?',
      one: 'Vuoi rimuovere la zona selezionata dal dispositivo?',
    );
    return '$_temp0';
  }

  @override
  String mapDownloadZoneItemSubtitle(String type, int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count celle',
      one: '1 cella',
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
