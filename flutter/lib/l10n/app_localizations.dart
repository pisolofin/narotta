import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @commonAppTitle.
  ///
  /// In it, this message translates to:
  /// **'NaRotta'**
  String get commonAppTitle;

  /// No description provided for @commonCancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get commonCancel;

  /// No description provided for @commonPause.
  ///
  /// In it, this message translates to:
  /// **'Pausa'**
  String get commonPause;

  /// No description provided for @commonResume.
  ///
  /// In it, this message translates to:
  /// **'Riprendi'**
  String get commonResume;

  /// No description provided for @commonSave.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get commonClose;

  /// No description provided for @commonSystemDefault.
  ///
  /// In it, this message translates to:
  /// **'Predefinito di sistema'**
  String get commonSystemDefault;

  /// No description provided for @mapTab.
  ///
  /// In it, this message translates to:
  /// **'Mappa'**
  String get mapTab;

  /// No description provided for @settingsTab.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get settingsTab;

  /// No description provided for @mapEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun dato cartografico'**
  String get mapEmptyTitle;

  /// No description provided for @mapEmptySubtitle.
  ///
  /// In it, this message translates to:
  /// **'I dati cartografici offline non sono ancora stati caricati.'**
  String get mapEmptySubtitle;

  /// No description provided for @locationCurrentPositionTitle.
  ///
  /// In it, this message translates to:
  /// **'Posizione corrente'**
  String get locationCurrentPositionTitle;

  /// No description provided for @locationSearching.
  ///
  /// In it, this message translates to:
  /// **'Rilevamento posizione GPS in corso...'**
  String get locationSearching;

  /// No description provided for @locationServiceDisabled.
  ///
  /// In it, this message translates to:
  /// **'Servizi di localizzazione disattivati sul dispositivo.'**
  String get locationServiceDisabled;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In it, this message translates to:
  /// **'Permesso di localizzazione negato.'**
  String get locationPermissionDenied;

  /// No description provided for @locationError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile rilevare la posizione corrente.'**
  String get locationError;

  /// No description provided for @locationRefresh.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna posizione'**
  String get locationRefresh;

  /// No description provided for @locationCoordinates.
  ///
  /// In it, this message translates to:
  /// **'{latitude}, {longitude}'**
  String locationCoordinates(String latitude, String longitude);

  /// No description provided for @locationAccuracyValue.
  ///
  /// In it, this message translates to:
  /// **'Precisione: +/-{meters} m'**
  String locationAccuracyValue(String meters);

  /// No description provided for @locationAltitudeValue.
  ///
  /// In it, this message translates to:
  /// **'Altitudine: {meters} m'**
  String locationAltitudeValue(String meters);

  /// No description provided for @locationSpeedValue.
  ///
  /// In it, this message translates to:
  /// **'Velocità: {kmh} km/h'**
  String locationSpeedValue(String kmh);

  /// No description provided for @mapVoidGridBadge.
  ///
  /// In it, this message translates to:
  /// **'Reticolo cartografico - In attesa della mappa'**
  String get mapVoidGridBadge;

  /// No description provided for @mapStatusOfflineReady.
  ///
  /// In it, this message translates to:
  /// **'Mappa offline attiva'**
  String get mapStatusOfflineReady;

  /// No description provided for @mapStatusWorldOverview.
  ///
  /// In it, this message translates to:
  /// **'Mappa base globale'**
  String get mapStatusWorldOverview;

  /// No description provided for @mapZoomIn.
  ///
  /// In it, this message translates to:
  /// **'Ingrandisci'**
  String get mapZoomIn;

  /// No description provided for @mapZoomOut.
  ///
  /// In it, this message translates to:
  /// **'Rimpicciolisci'**
  String get mapZoomOut;

  /// No description provided for @mapRecenter.
  ///
  /// In it, this message translates to:
  /// **'Ricentra sulla posizione'**
  String get mapRecenter;

  /// No description provided for @mapFollowingUser.
  ///
  /// In it, this message translates to:
  /// **'Centrato'**
  String get mapFollowingUser;

  /// No description provided for @mapFreeExploration.
  ///
  /// In it, this message translates to:
  /// **'Esplorazione libera'**
  String get mapFreeExploration;

  /// No description provided for @mapScaleMeters.
  ///
  /// In it, this message translates to:
  /// **'{meters} m'**
  String mapScaleMeters(String meters);

  /// No description provided for @mapScaleKilometers.
  ///
  /// In it, this message translates to:
  /// **'{kilometers} km'**
  String mapScaleKilometers(String kilometers);

  /// No description provided for @mapHeadingValue.
  ///
  /// In it, this message translates to:
  /// **'Direzione: {degrees} gradi'**
  String mapHeadingValue(String degrees);

  /// No description provided for @mapTelemetryToggle.
  ///
  /// In it, this message translates to:
  /// **'Dettagli telemetria'**
  String get mapTelemetryToggle;

  /// No description provided for @mapMainStreetLabel.
  ///
  /// In it, this message translates to:
  /// **'Corso Principale'**
  String get mapMainStreetLabel;

  /// No description provided for @settingsTitle.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get settingsTitle;

  /// No description provided for @settingsGeneralSection.
  ///
  /// In it, this message translates to:
  /// **'Generali'**
  String get settingsGeneralSection;

  /// No description provided for @settingsLanguage.
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSelect.
  ///
  /// In it, this message translates to:
  /// **'Seleziona lingua'**
  String get settingsLanguageSelect;

  /// No description provided for @settingsLanguageItalian.
  ///
  /// In it, this message translates to:
  /// **'Italiano'**
  String get settingsLanguageItalian;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In it, this message translates to:
  /// **'Inglese'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsTheme.
  ///
  /// In it, this message translates to:
  /// **'Tema'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSelect.
  ///
  /// In it, this message translates to:
  /// **'Seleziona tema'**
  String get settingsThemeSelect;

  /// No description provided for @settingsLightTheme.
  ///
  /// In it, this message translates to:
  /// **'Chiaro'**
  String get settingsLightTheme;

  /// No description provided for @settingsDarkTheme.
  ///
  /// In it, this message translates to:
  /// **'Scuro'**
  String get settingsDarkTheme;

  /// No description provided for @settingsMapsSection.
  ///
  /// In it, this message translates to:
  /// **'Mappe e download'**
  String get settingsMapsSection;

  /// No description provided for @settingsDownloadMapsTitle.
  ///
  /// In it, this message translates to:
  /// **'Scarica mappe'**
  String get settingsDownloadMapsTitle;

  /// No description provided for @settingsMapStorageFolderTitle.
  ///
  /// In it, this message translates to:
  /// **'Cartella di salvataggio mappe'**
  String get settingsMapStorageFolderTitle;

  /// No description provided for @settingsMapStorageFolderReset.
  ///
  /// In it, this message translates to:
  /// **'Ripristina predefinita'**
  String get settingsMapStorageFolderReset;

  /// No description provided for @settingsMapStorageFolderChange.
  ///
  /// In it, this message translates to:
  /// **'Cambia cartella'**
  String get settingsMapStorageFolderChange;

  /// No description provided for @settingsMapStorageFolderDefaultBadge.
  ///
  /// In it, this message translates to:
  /// **'Predefinita'**
  String get settingsMapStorageFolderDefaultBadge;

  /// No description provided for @settingsMapStyleTitle.
  ///
  /// In it, this message translates to:
  /// **'Stile mappa'**
  String get settingsMapStyleTitle;

  /// No description provided for @settingsMapStyleSelect.
  ///
  /// In it, this message translates to:
  /// **'Seleziona stile mappa'**
  String get settingsMapStyleSelect;

  /// No description provided for @mapStyleTacticalTitle.
  ///
  /// In it, this message translates to:
  /// **'Cartografico Tattico'**
  String get mapStyleTacticalTitle;

  /// No description provided for @mapStyleTacticalDesc.
  ///
  /// In it, this message translates to:
  /// **'Vettori ad alto contrasto con reticolo di precisione, città e dorsali principali.'**
  String get mapStyleTacticalDesc;

  /// No description provided for @settingsMapWifiOnlyTitle.
  ///
  /// In it, this message translates to:
  /// **'Scarica solo Wi-Fi'**
  String get settingsMapWifiOnlyTitle;

  /// No description provided for @settingsMapWifiOnlyDesc.
  ///
  /// In it, this message translates to:
  /// **'Evita il consumo della connessione dati cellulare'**
  String get settingsMapWifiOnlyDesc;

  /// No description provided for @settingsMapServerUrlDialogTitle.
  ///
  /// In it, this message translates to:
  /// **'Configura Server Mappe'**
  String get settingsMapServerUrlDialogTitle;

  /// No description provided for @settingsMapServerLocalhost.
  ///
  /// In it, this message translates to:
  /// **'Server Locale (localhost:5001)'**
  String get settingsMapServerLocalhost;

  /// No description provided for @settingsMapServerLocalhostDesc.
  ///
  /// In it, this message translates to:
  /// **'Per sviluppo e test su Windows o Mac'**
  String get settingsMapServerLocalhostDesc;

  /// No description provided for @settingsMapServerAndroidEmulator.
  ///
  /// In it, this message translates to:
  /// **'Emulatore Android (10.0.2.2:5001)'**
  String get settingsMapServerAndroidEmulator;

  /// No description provided for @settingsMapServerAndroidEmulatorDesc.
  ///
  /// In it, this message translates to:
  /// **'Alias di rete predefinito per emulatore Android'**
  String get settingsMapServerAndroidEmulatorDesc;

  /// No description provided for @settingsMapServerLan.
  ///
  /// In it, this message translates to:
  /// **'Rete Locale (192.168.8.53:5001)'**
  String get settingsMapServerLan;

  /// No description provided for @settingsMapServerLanDesc.
  ///
  /// In it, this message translates to:
  /// **'Server storage MapBuilder su rete LAN locale'**
  String get settingsMapServerLanDesc;

  /// No description provided for @settingsMapServerProduction.
  ///
  /// In it, this message translates to:
  /// **'Produzione (maps.narotta.app)'**
  String get settingsMapServerProduction;

  /// No description provided for @settingsMapServerProductionDesc.
  ///
  /// In it, this message translates to:
  /// **'Server cloud ufficiale di distribuzione mappe'**
  String get settingsMapServerProductionDesc;

  /// No description provided for @settingsMapServerCustom.
  ///
  /// In it, this message translates to:
  /// **'URL Personalizzato...'**
  String get settingsMapServerCustom;

  /// No description provided for @settingsMapServerCustomDesc.
  ///
  /// In it, this message translates to:
  /// **'Inserisci manualmente l\'indirizzo IP e la porta'**
  String get settingsMapServerCustomDesc;

  /// No description provided for @settingsMapServerCustomHint.
  ///
  /// In it, this message translates to:
  /// **'http://192.168.x.x:5001'**
  String get settingsMapServerCustomHint;

  /// No description provided for @mapDownloadTitle.
  ///
  /// In it, this message translates to:
  /// **'Scarica mappe'**
  String get mapDownloadTitle;

  /// No description provided for @mapDownloadServerSection.
  ///
  /// In it, this message translates to:
  /// **'Server'**
  String get mapDownloadServerSection;

  /// No description provided for @mapDownloadServerChecking.
  ///
  /// In it, this message translates to:
  /// **'Verifica...'**
  String get mapDownloadServerChecking;

  /// No description provided for @mapDownloadServerStatusOnline.
  ///
  /// In it, this message translates to:
  /// **'Online'**
  String get mapDownloadServerStatusOnline;

  /// No description provided for @mapDownloadServerStatusOffline.
  ///
  /// In it, this message translates to:
  /// **'Offline'**
  String get mapDownloadServerStatusOffline;

  /// No description provided for @mapDownloadServerOnline.
  ///
  /// In it, this message translates to:
  /// **'Server Mappe online ({url})'**
  String mapDownloadServerOnline(String url);

  /// No description provided for @mapDownloadServerOffline.
  ///
  /// In it, this message translates to:
  /// **'Server Mappe non raggiungibile ({url})'**
  String mapDownloadServerOffline(String url);

  /// No description provided for @mapDownloadServerOfflineError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile scaricare: il Server Mappe ({url}) non è raggiungibile. Verifica che sia avviato.'**
  String mapDownloadServerOfflineError(String url);

  /// No description provided for @mapDownloadBaseMapSection.
  ///
  /// In it, this message translates to:
  /// **'Mappa base'**
  String get mapDownloadBaseMapSection;

  /// No description provided for @mapDownloadBaseMapTitle.
  ///
  /// In it, this message translates to:
  /// **'Mappa mondiale panoramica'**
  String get mapDownloadBaseMapTitle;

  /// No description provided for @mapDownloadBaseMapSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Zoom 0-7 • ~{size} MB'**
  String mapDownloadBaseMapSubtitle(String size);

  /// No description provided for @mapDownloadBaseMapDownloadAction.
  ///
  /// In it, this message translates to:
  /// **'Scarica'**
  String get mapDownloadBaseMapDownloadAction;

  /// No description provided for @mapDownloadWorldDownloaded.
  ///
  /// In it, this message translates to:
  /// **'Scaricata'**
  String get mapDownloadWorldDownloaded;

  /// No description provided for @mapDownloadStatusDownloading.
  ///
  /// In it, this message translates to:
  /// **'Download in corso ({percent}%)'**
  String mapDownloadStatusDownloading(int percent);

  /// No description provided for @mapDownloadStatusPaused.
  ///
  /// In it, this message translates to:
  /// **'In pausa ({percent}%)'**
  String mapDownloadStatusPaused(int percent);

  /// No description provided for @mapDownloadActionDeleteConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Elimina mappa'**
  String get mapDownloadActionDeleteConfirmTitle;

  /// No description provided for @mapDownloadActionDeleteConfirmMsg.
  ///
  /// In it, this message translates to:
  /// **'Sei sicuro di voler eliminare i dati offline per {name}?'**
  String mapDownloadActionDeleteConfirmMsg(String name);

  /// No description provided for @mapDownloadSelectionSection.
  ///
  /// In it, this message translates to:
  /// **'Selezione'**
  String get mapDownloadSelectionSection;

  /// No description provided for @mapDownloadDownloadedZonesBtn.
  ///
  /// In it, this message translates to:
  /// **'Zone scaricate ({count})'**
  String mapDownloadDownloadedZonesBtn(int count);

  /// No description provided for @mapDownloadSearchPlaceholder.
  ///
  /// In it, this message translates to:
  /// **'Cerca città, regione o stato...'**
  String get mapDownloadSearchPlaceholder;

  /// No description provided for @mapDownloadSearchNoResults.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato trovato'**
  String get mapDownloadSearchNoResults;

  /// No description provided for @mapDownloadPlaceTypeCountry.
  ///
  /// In it, this message translates to:
  /// **'Stato'**
  String get mapDownloadPlaceTypeCountry;

  /// No description provided for @mapDownloadPlaceTypeRegion.
  ///
  /// In it, this message translates to:
  /// **'Regione'**
  String get mapDownloadPlaceTypeRegion;

  /// No description provided for @mapDownloadPlaceTypeCity.
  ///
  /// In it, this message translates to:
  /// **'Città'**
  String get mapDownloadPlaceTypeCity;

  /// No description provided for @mapDownloadPlaceTypeCustom.
  ///
  /// In it, this message translates to:
  /// **'Area personalizzata'**
  String get mapDownloadPlaceTypeCustom;

  /// No description provided for @mapDownloadCustomZoneLabel.
  ///
  /// In it, this message translates to:
  /// **'Area {coordinates} ({count} celle)'**
  String mapDownloadCustomZoneLabel(String coordinates, int count);

  /// No description provided for @mapDownloadLegendLabel.
  ///
  /// In it, this message translates to:
  /// **'Scaricate:'**
  String get mapDownloadLegendLabel;

  /// No description provided for @mapDownloadDetailBaseTitle.
  ///
  /// In it, this message translates to:
  /// **'Base (Stradale & Navigazione)'**
  String get mapDownloadDetailBaseTitle;

  /// No description provided for @mapDownloadDetailBaseDesc.
  ///
  /// In it, this message translates to:
  /// **'Rete stradale completa, città e routing (Z8-14)'**
  String get mapDownloadDetailBaseDesc;

  /// No description provided for @mapDownloadDetailDetailedTitle.
  ///
  /// In it, this message translates to:
  /// **'Dettagliato (+ Sentieri & Pedonale)'**
  String get mapDownloadDetailDetailedTitle;

  /// No description provided for @mapDownloadDetailDetailedDesc.
  ///
  /// In it, this message translates to:
  /// **'Stradale + sentieri escursionistici, percorsi a piedi e piste ciclabili (Z8-16)'**
  String get mapDownloadDetailDetailedDesc;

  /// No description provided for @mapDownloadDetailCompleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Completo (+ 3D e Terreno HD)'**
  String get mapDownloadDetailCompleteTitle;

  /// No description provided for @mapDownloadDetailCompleteDesc.
  ///
  /// In it, this message translates to:
  /// **'Stradale + sentieri + edifici volumetrici 3D e curve di livello DEM (Z8-16)'**
  String get mapDownloadDetailCompleteDesc;

  /// No description provided for @mapDownloadDetailLevelsInfoTitle.
  ///
  /// In it, this message translates to:
  /// **'Livelli di dettaglio della mappa'**
  String get mapDownloadDetailLevelsInfoTitle;

  /// No description provided for @mapDownloadDetailLevelsInfoSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli il livello di dati da scaricare per la navigazione offline:'**
  String get mapDownloadDetailLevelsInfoSubtitle;

  /// No description provided for @mapDownloadDetailBaseBadge.
  ///
  /// In it, this message translates to:
  /// **'Base'**
  String get mapDownloadDetailBaseBadge;

  /// No description provided for @mapDownloadDetailDetailedBadge.
  ///
  /// In it, this message translates to:
  /// **'Dettagliato'**
  String get mapDownloadDetailDetailedBadge;

  /// No description provided for @mapDownloadDetailCompleteBadge.
  ///
  /// In it, this message translates to:
  /// **'Completo'**
  String get mapDownloadDetailCompleteBadge;

  /// No description provided for @mapDownloadModeRemoveBadge.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get mapDownloadModeRemoveBadge;

  /// No description provided for @mapDownloadToolPan.
  ///
  /// In it, this message translates to:
  /// **'Sposta'**
  String get mapDownloadToolPan;

  /// No description provided for @mapDownloadToolLasso.
  ///
  /// In it, this message translates to:
  /// **'Cerchia'**
  String get mapDownloadToolLasso;

  /// No description provided for @mapDownloadWorldView.
  ///
  /// In it, this message translates to:
  /// **'Vista mondo'**
  String get mapDownloadWorldView;

  /// No description provided for @mapDownloadFullscreenEnter.
  ///
  /// In it, this message translates to:
  /// **'Espandi mappa'**
  String get mapDownloadFullscreenEnter;

  /// No description provided for @mapDownloadFullscreenExit.
  ///
  /// In it, this message translates to:
  /// **'Riduci mappa'**
  String get mapDownloadFullscreenExit;

  /// No description provided for @mapDownloadSelectionEmptyHint.
  ///
  /// In it, this message translates to:
  /// **'Tocca o clicca sulle celle, usa Cerchia o cerca città, regione o stato.'**
  String get mapDownloadSelectionEmptyHint;

  /// No description provided for @mapDownloadSelectedCellsSummary.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 cella selezionata} other{{count} celle selezionate}}'**
  String mapDownloadSelectedCellsSummary(int count);

  /// No description provided for @mapDownloadNamedSelectionSummary.
  ///
  /// In it, this message translates to:
  /// **'{name} • {count, plural, =1{1 cella} other{{count} celle}}'**
  String mapDownloadNamedSelectionSummary(String name, int count);

  /// No description provided for @mapDownloadRemoveSummary.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Nessuna cella scaricata nella selezione} =1{1 cella scaricata da rimuovere} other{{count} celle scaricate da rimuovere}}'**
  String mapDownloadRemoveSummary(int count);

  /// No description provided for @mapDownloadApplyDownloadAction.
  ///
  /// In it, this message translates to:
  /// **'Scarica {level} (~{size} MB)'**
  String mapDownloadApplyDownloadAction(String level, String size);

  /// No description provided for @mapDownloadApplyRemoveAction.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi ({count})'**
  String mapDownloadApplyRemoveAction(int count);

  /// No description provided for @mapDownloadClearSelectionAction.
  ///
  /// In it, this message translates to:
  /// **'Deseleziona'**
  String get mapDownloadClearSelectionAction;

  /// No description provided for @mapDownloadZonesModalTitle.
  ///
  /// In it, this message translates to:
  /// **'Zone scaricate'**
  String get mapDownloadZonesModalTitle;

  /// No description provided for @mapDownloadZonesEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessuna zona scaricata'**
  String get mapDownloadZonesEmptyTitle;

  /// No description provided for @mapDownloadZonesEmptyDesc.
  ///
  /// In it, this message translates to:
  /// **'Seleziona un\'area sulla mappa mondiale o cerca una città, regione o stato per scaricarla.'**
  String get mapDownloadZonesEmptyDesc;

  /// No description provided for @mapDownloadZonesSelectAll.
  ///
  /// In it, this message translates to:
  /// **'Seleziona tutte'**
  String get mapDownloadZonesSelectAll;

  /// No description provided for @mapDownloadZonesDeselectAll.
  ///
  /// In it, this message translates to:
  /// **'Deseleziona tutte'**
  String get mapDownloadZonesDeselectAll;

  /// No description provided for @mapDownloadZonesSelectedCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Nessuna selezionata} =1{1 selezionata} other{{count} selezionate}}'**
  String mapDownloadZonesSelectedCount(int count);

  /// No description provided for @mapDownloadZonesChangeLevelBtn.
  ///
  /// In it, this message translates to:
  /// **'Cambia livello'**
  String get mapDownloadZonesChangeLevelBtn;

  /// No description provided for @mapDownloadZonesChangeLevelTitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli nuovo livello di dettaglio'**
  String get mapDownloadZonesChangeLevelTitle;

  /// No description provided for @mapDownloadZonesRemoveBtn.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get mapDownloadZonesRemoveBtn;

  /// No description provided for @mapDownloadZonesRemoveConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi zone selezionate'**
  String get mapDownloadZonesRemoveConfirmTitle;

  /// No description provided for @mapDownloadZonesRemoveConfirmMsg.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Vuoi rimuovere la zona selezionata dal dispositivo?} other{Vuoi rimuovere le {count} zone selezionate dal dispositivo?}}'**
  String mapDownloadZonesRemoveConfirmMsg(int count);

  /// No description provided for @mapDownloadZoneItemSubtitle.
  ///
  /// In it, this message translates to:
  /// **'{type} • {count, plural, =1{1 cella} other{{count} celle}} • ~{size} MB'**
  String mapDownloadZoneItemSubtitle(String type, int count, String size);

  /// No description provided for @commonMegabytesValue.
  ///
  /// In it, this message translates to:
  /// **'{size} MB'**
  String commonMegabytesValue(String size);

  /// No description provided for @commonApproximateMegabytesValue.
  ///
  /// In it, this message translates to:
  /// **'~{size} MB'**
  String commonApproximateMegabytesValue(String size);

  /// No description provided for @commonPercentValue.
  ///
  /// In it, this message translates to:
  /// **'{percent}%'**
  String commonPercentValue(int percent);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
