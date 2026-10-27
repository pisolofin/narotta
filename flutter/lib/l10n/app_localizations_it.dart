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
    return 'Precisione: +/-$meters m';
  }

  @override
  String locationAltitudeValue(String meters) {
    return 'Altitudine: $meters m';
  }

  @override
  String locationSpeedValue(String kmh) {
    return 'Velocita\': $kmh km/h';
  }

  @override
  String get mapVoidGridBadge =>
      'Reticolo cartografico - In attesa della mappa';

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
  String get settingsMapDownloadMode => 'Modalita\' di download';

  @override
  String get settingsMapDownloadModeSelect =>
      'Seleziona modalita\' di download';

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
      'Dettaglio nel corridoio +/-15 km e destinazione HD, mappa base altrove';

  @override
  String get settingsMapCircleDownloadAction => 'Cerchia e scarica';

  @override
  String get settingsMapCircleDownloadDesc =>
      'Seleziona e scarica celle 0.5 x 0.5 col dito';

  @override
  String get settingsMapWifiOnlyTitle => 'Scarica solo con Wi-Fi';

  @override
  String get settingsMapWifiOnlyDesc =>
      'Evita il consumo della connessione dati cellulare';

  @override
  String get settingsMapLayersSection => 'Livelli di dettaglio aggiuntivi';

  @override
  String get settingsMapLayerBuildingsTitle => 'Edifici 3D (Z13-15)';

  @override
  String get settingsMapLayerBuildingsDesc =>
      'Estrusioni volumetriche degli isolati urbani';

  @override
  String get settingsMapLayerPedestrianTitle =>
      'Pedonale e Mobilita\' Dolce (Z13-15)';

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
  String get commonDelete => 'Elimina';

  @override
  String get commonClose => 'Chiudi';

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
      other : '$count celle (0.5 x 0.5)',
      one   : '1 cella (0.5 x 0.5)',
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

  @override
  String get settingsMapDownloadManagerTitle => 'Scarica mappe offline';

  @override
  String get settingsMapDownloadManagerDesc =>
      'Mappa del mondo, stati e regioni con selezione dettaglio';

  @override
  String get mapDownloadTitle => 'Download Mappe Offline';

  @override
  String get mapDownloadWorldSection => 'Mappa del Mondo (Base)';

  @override
  String get mapDownloadWorldDesc =>
      'Panoramica globale (Zoom 0-7) - Indispensabile per navigare e orientarsi offline tra nazioni e continenti';

  @override
  String mapDownloadWorldDownloadBtn(String size) {
    return 'Scarica Mappa Base ($size MB)';
  }

  @override
  String get mapDownloadWorldDownloaded => 'Mappa del Mondo scaricata';

  @override
  String get mapDownloadRegionsSection => 'Stati e Regioni';

  @override
  String get mapDownloadRegionsDesc =>
      'Seleziona uno stato o una regione per scegliere il livello di dettaglio da scaricare';

  @override
  String get mapDownloadRegionsSearchHint => 'Cerca stato o regione...';

  @override
  String get mapDownloadDetailLevelTitle => 'Livello di dettaglio';

  @override
  String mapDownloadDetailSelectFor(String name) {
    return 'Seleziona dettaglio per $name';
  }

  @override
  String get mapDownloadDetailBaseTitle => 'Base (Stradale & Navigazione)';

  @override
  String get mapDownloadDetailBaseDesc =>
      'Rete stradale completa, citta\' e routing (Z8-14)';

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
  String get mapDownloadDetailBaseBadge => 'Base';

  @override
  String get mapDownloadDetailDetailedBadge => 'Dettagliato';

  @override
  String get mapDownloadDetailCompleteBadge => 'Completo';

  @override
  String get mapDownloadStatusDownloaded => 'Scaricata';

  @override
  String get mapDownloadStatusNotDownloaded => 'Non scaricata';

  @override
  String mapDownloadStatusDownloading(int percent) {
    return 'Download in corso ($percent%)';
  }

  @override
  String mapDownloadActionDownload(String size) {
    return 'Scarica ($size MB)';
  }

  @override
  String get mapDownloadActionUpdate => 'Aggiorna livello di dettaglio';

  @override
  String get mapDownloadActionDelete => 'Elimina mappa scaricata';

  @override
  String get mapDownloadActionDeleteConfirmTitle => 'Elimina mappa';

  @override
  String mapDownloadActionDeleteConfirmMsg(String name) {
    return 'Sei sicuro di voler eliminare i dati offline per $name?';
  }

  @override
  String get mapDownloadCircleActionTitle => 'Cerchia e scarica su mappa';

  @override
  String get mapDownloadCircleActionDesc =>
      'Disegna a mano libera sulla mappa mondiale per scaricare solo le celle desiderate';

  @override
  String get circleDownloadDetailModalTitle =>
      'Dettaglio download per l\'area selezionata';

  @override
  String get circleDownloadLegendTitle => 'Livelli scaricati:';

  @override
  String get circleDownloadLegendBase => 'Base';

  @override
  String get circleDownloadLegendDetailed => 'Dettagliato';

  @override
  String get circleDownloadLegendComplete => 'Completo';

  @override
  String circleDownloadCellsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other : '$count celle selezionate',
      one   : '1 cella selezionata',
    );
    return '$_temp0';
  }

  @override
  String get circleDownloadActionChooseDetail => 'Scegli dettaglio e scarica';

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
    return 'Impossibile scaricare: il Server Mappe ($url) non e\' raggiungibile. Verifica che sia avviato.';
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
