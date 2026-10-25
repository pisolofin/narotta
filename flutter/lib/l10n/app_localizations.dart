import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
  /// **'{ latitude }, { longitude }'**
  String locationCoordinates(String latitude, String longitude);

  /// No description provided for @locationAccuracyValue.
  ///
  /// In it, this message translates to:
  /// **'Precisione: ±{ meters } m'**
  String locationAccuracyValue(String meters);

  /// No description provided for @locationAltitudeValue.
  ///
  /// In it, this message translates to:
  /// **'Altitudine: { meters } m'**
  String locationAltitudeValue(String meters);

  /// No description provided for @locationSpeedValue.
  ///
  /// In it, this message translates to:
  /// **'Velocità: { kmh } km/h'**
  String locationSpeedValue(String kmh);

  /// No description provided for @mapVoidGridBadge.
  ///
  /// In it, this message translates to:
  /// **'Reticolo cartografico • In attesa della mappa'**
  String get mapVoidGridBadge;

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
  /// **'{ meters } m'**
  String mapScaleMeters(String meters);

  /// No description provided for @mapScaleKilometers.
  ///
  /// In it, this message translates to:
  /// **'{ kilometers } km'**
  String mapScaleKilometers(String kilometers);

  /// No description provided for @mapHeadingValue.
  ///
  /// In it, this message translates to:
  /// **'Direzione: { degrees }°'**
  String mapHeadingValue(String degrees);

  /// No description provided for @mapTelemetryToggle.
  ///
  /// In it, this message translates to:
  /// **'Dettagli telemetria'**
  String get mapTelemetryToggle;

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
  /// **'Mappe e Download Offline'**
  String get settingsMapsSection;

  /// No description provided for @settingsMapDownloadMode.
  ///
  /// In it, this message translates to:
  /// **'Modalità di download'**
  String get settingsMapDownloadMode;

  /// No description provided for @settingsMapDownloadModeSelect.
  ///
  /// In it, this message translates to:
  /// **'Seleziona modalità di download'**
  String get settingsMapDownloadModeSelect;

  /// No description provided for @settingsMapModeByRegionTitle.
  ///
  /// In it, this message translates to:
  /// **'Per Stato o Regione'**
  String get settingsMapModeByRegionTitle;

  /// No description provided for @settingsMapModeByRegionDesc.
  ///
  /// In it, this message translates to:
  /// **'Scarica intere nazioni o regioni amministrative dal catalogo'**
  String get settingsMapModeByRegionDesc;

  /// No description provided for @settingsMapModeCircleAreaTitle.
  ///
  /// In it, this message translates to:
  /// **'Cerchia con il dito'**
  String get settingsMapModeCircleAreaTitle;

  /// No description provided for @settingsMapModeCircleAreaDesc.
  ///
  /// In it, this message translates to:
  /// **'Disegna a mano libera sulla mappa e scarica solo l\'area desiderata'**
  String get settingsMapModeCircleAreaDesc;

  /// No description provided for @settingsMapModeRouteCorridorTitle.
  ///
  /// In it, this message translates to:
  /// **'Solo lungo la rotta'**
  String get settingsMapModeRouteCorridorTitle;

  /// No description provided for @settingsMapModeRouteCorridorDesc.
  ///
  /// In it, this message translates to:
  /// **'Dettaglio nel corridoio ±15 km e destinazione HD, mappa base altrove'**
  String get settingsMapModeRouteCorridorDesc;

  /// No description provided for @settingsMapCircleDownloadAction.
  ///
  /// In it, this message translates to:
  /// **'Cerchia e scarica'**
  String get settingsMapCircleDownloadAction;

  /// No description provided for @settingsMapCircleDownloadDesc.
  ///
  /// In it, this message translates to:
  /// **'Seleziona e scarica celle 0.5° × 0.5° col dito'**
  String get settingsMapCircleDownloadDesc;

  /// No description provided for @settingsMapWifiOnlyTitle.
  ///
  /// In it, this message translates to:
  /// **'Scarica solo con Wi-Fi'**
  String get settingsMapWifiOnlyTitle;

  /// No description provided for @settingsMapWifiOnlyDesc.
  ///
  /// In it, this message translates to:
  /// **'Evita il consumo della connessione dati cellulare'**
  String get settingsMapWifiOnlyDesc;

  /// No description provided for @settingsMapLayersSection.
  ///
  /// In it, this message translates to:
  /// **'Livelli di dettaglio aggiuntivi'**
  String get settingsMapLayersSection;

  /// No description provided for @settingsMapLayerBuildingsTitle.
  ///
  /// In it, this message translates to:
  /// **'Edifici 3D (Z13–15)'**
  String get settingsMapLayerBuildingsTitle;

  /// No description provided for @settingsMapLayerBuildingsDesc.
  ///
  /// In it, this message translates to:
  /// **'Estrusioni volumetriche degli isolati urbani'**
  String get settingsMapLayerBuildingsDesc;

  /// No description provided for @settingsMapLayerPedestrianTitle.
  ///
  /// In it, this message translates to:
  /// **'Pedonale e Mobilità Dolce (Z13–15)'**
  String get settingsMapLayerPedestrianTitle;

  /// No description provided for @settingsMapLayerPedestrianDesc.
  ///
  /// In it, this message translates to:
  /// **'Sentieri, marciapiedi e percorsi a piedi Park & Walk'**
  String get settingsMapLayerPedestrianDesc;

  /// No description provided for @settingsMapLayerTerrainTitle.
  ///
  /// In it, this message translates to:
  /// **'Rilievi altimetrici HD'**
  String get settingsMapLayerTerrainTitle;

  /// No description provided for @settingsMapLayerTerrainDesc.
  ///
  /// In it, this message translates to:
  /// **'Modelli DEM e curve di livello montane'**
  String get settingsMapLayerTerrainDesc;

  /// No description provided for @settingsMapServerUrlTitle.
  ///
  /// In it, this message translates to:
  /// **'Server Mappe Web API'**
  String get settingsMapServerUrlTitle;

  /// No description provided for @settingsMapServerUrlDesc.
  ///
  /// In it, this message translates to:
  /// **'Indirizzo del servizio di distribuzione mappe'**
  String get settingsMapServerUrlDesc;

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

  /// No description provided for @commonSave.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get commonSave;

  /// No description provided for @circleDownloadTitle.
  ///
  /// In it, this message translates to:
  /// **'Cerchia e Scarica'**
  String get circleDownloadTitle;

  /// No description provided for @circleDownloadDrawInstruction.
  ///
  /// In it, this message translates to:
  /// **'Disegna un cerchio o poligono col dito per delimitare l\'area'**
  String get circleDownloadDrawInstruction;

  /// No description provided for @circleDownloadModeDraw.
  ///
  /// In it, this message translates to:
  /// **'Disegna'**
  String get circleDownloadModeDraw;

  /// No description provided for @circleDownloadModePan.
  ///
  /// In it, this message translates to:
  /// **'Sposta'**
  String get circleDownloadModePan;

  /// No description provided for @circleDownloadActionClear.
  ///
  /// In it, this message translates to:
  /// **'Cancella'**
  String get circleDownloadActionClear;

  /// No description provided for @circleDownloadActionRecenter.
  ///
  /// In it, this message translates to:
  /// **'Centra'**
  String get circleDownloadActionRecenter;

  /// No description provided for @circleDownloadSelectedCellsCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{ 1 cella (0.5° × 0.5°) } other{{ count } celle (0.5° × 0.5°)}}'**
  String circleDownloadSelectedCellsCount(int count);

  /// No description provided for @circleDownloadEstimatedSize.
  ///
  /// In it, this message translates to:
  /// **'Dimensione stimata: { size } MB'**
  String circleDownloadEstimatedSize(String size);

  /// No description provided for @circleDownloadActionDownload.
  ///
  /// In it, this message translates to:
  /// **'Scarica area selezionata'**
  String get circleDownloadActionDownload;

  /// No description provided for @circleDownloadProgressPercent.
  ///
  /// In it, this message translates to:
  /// **'Download in corso: { percent }%'**
  String circleDownloadProgressPercent(int percent);

  /// No description provided for @circleDownloadCompleted.
  ///
  /// In it, this message translates to:
  /// **'Download completato con successo!'**
  String get circleDownloadCompleted;

  /// No description provided for @circleDownloadNoSelectionHint.
  ///
  /// In it, this message translates to:
  /// **'Nessuna area selezionata. Tocca \'Disegna\' e traccia col dito sulla mappa.'**
  String get circleDownloadNoSelectionHint;

  /// No description provided for @circleDownloadLayerBase.
  ///
  /// In it, this message translates to:
  /// **'Base Guida'**
  String get circleDownloadLayerBase;

  /// No description provided for @circleDownloadLayerBuildings.
  ///
  /// In it, this message translates to:
  /// **'Edifici 3D'**
  String get circleDownloadLayerBuildings;

  /// No description provided for @circleDownloadLayerPedestrian.
  ///
  /// In it, this message translates to:
  /// **'Pedonale'**
  String get circleDownloadLayerPedestrian;
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
