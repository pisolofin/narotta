import 'package:flutter/material.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings-service.dart';
import '../../map-download/map-download.page.dart';
import '../../circle-download/circle-download.page.dart';

/// Displays the application settings view with language, theme, and map download configuration.
class Settings extends StatelessWidget {
  static const String _systemLanguageValue  = 'system';
  static const String _italianLanguageValue = 'it';
  static const String _englishLanguageValue = 'en';

  static const String _serverLocalhost       = 'http://localhost:5001';
  static const String _serverAndroidEmulator = 'http://10.0.2.2:5001';
  static const String _serverLan             = 'http://192.168.8.53:5001';
  static const String _serverProduction      = 'https://maps.narotta.app';
  static const String _serverCustomChoice    = 'custom';

  const Settings({ super.key });

  /// Returns the localized label for the given [languageCode].
  String _getLanguageLabel(String? languageCode, AppLocalizations l10n) {
    if (languageCode == _italianLanguageValue) {
      return l10n.settingsLanguageItalian;
    }
    if (languageCode == _englishLanguageValue) {
      return l10n.settingsLanguageEnglish;
    }
    return l10n.commonSystemDefault;
  }

  /// Returns the localized label for the given [themeMode].
  String _getThemeModeLabel(ThemeMode themeMode, AppLocalizations l10n) {
    if (themeMode == ThemeMode.light) {
      return l10n.settingsLightTheme;
    }
    if (themeMode == ThemeMode.dark) {
      return l10n.settingsDarkTheme;
    }
    return l10n.commonSystemDefault;
  }

  /// Returns the localized label for the given [MapDownloadMode].
  String _getMapDownloadModeTitle(MapDownloadMode mode, AppLocalizations l10n) {
    if (mode == MapDownloadMode.byRegion) {
      return l10n.settingsMapModeByRegionTitle;
    }
    if (mode == MapDownloadMode.circleArea) {
      return l10n.settingsMapModeCircleAreaTitle;
    }
    return l10n.settingsMapModeRouteCorridorTitle;
  }

  /// Returns the concise display label for the current Map Server URL.
  String _getMapServerLabel(String url) {
    if (url == _serverLocalhost) {
      return 'localhost:5001';
    }
    if (url == _serverAndroidEmulator) {
      return '10.0.2.2:5001';
    }
    if (url == _serverLan) {
      return '192.168.8.53:5001';
    }
    if (url == _serverProduction) {
      return 'maps.narotta.app';
    }
    return url;
  }

  /// Opens the platform-adaptive selection modal to choose the application language.
  Future _openLanguageSelectorAsync(
    BuildContext context,
    String? currentLanguageCode,
    AppLocalizations l10n,
  ) async {
    final List<NaSelectionItem<String>> languageItemList = [
      NaSelectionItem<String>(
        value     : _systemLanguageValue,
        title     : Text(l10n.commonSystemDefault),
        isSelected: currentLanguageCode == null,
      ),
      NaSelectionItem<String>(
        value     : _italianLanguageValue,
        title     : Text(l10n.settingsLanguageItalian),
        isSelected: currentLanguageCode == _italianLanguageValue,
      ),
      NaSelectionItem<String>(
        value     : _englishLanguageValue,
        title     : Text(l10n.settingsLanguageEnglish),
        isSelected: currentLanguageCode == _englishLanguageValue,
      ),
    ];

    final String? selectedValue = await naShowSelectionModalAsync<String>(
      context     : context,
      title       : Text(l10n.settingsLanguageSelect),
      cancelButton: Text(l10n.commonCancel),
      itemList    : languageItemList,
    );

    if (selectedValue != null) {
      final String? newLanguageCode = (selectedValue == _systemLanguageValue) ? null : selectedValue;
      await SettingsService().updateLanguageCodeAsync(newLanguageCode);
    }
  }

  /// Opens the platform-adaptive selection modal to choose the application theme mode.
  Future _openThemeSelectorAsync(
    BuildContext context,
    ThemeMode currentThemeMode,
    AppLocalizations l10n,
  ) async {
    final List<NaSelectionItem<ThemeMode>> themeItemList = [
      NaSelectionItem<ThemeMode>(
        value     : ThemeMode.system,
        title     : Text(l10n.commonSystemDefault),
        isSelected: currentThemeMode == ThemeMode.system,
      ),
      NaSelectionItem<ThemeMode>(
        value     : ThemeMode.light,
        title     : Text(l10n.settingsLightTheme),
        isSelected: currentThemeMode == ThemeMode.light,
      ),
      NaSelectionItem<ThemeMode>(
        value     : ThemeMode.dark,
        title     : Text(l10n.settingsDarkTheme),
        isSelected: currentThemeMode == ThemeMode.dark,
      ),
    ];

    final ThemeMode? selectedThemeMode = await naShowSelectionModalAsync<ThemeMode>(
      context     : context,
      title       : Text(l10n.settingsThemeSelect),
      cancelButton: Text(l10n.commonCancel),
      itemList    : themeItemList,
    );

    if (selectedThemeMode != null) {
      await SettingsService().updateThemeModeAsync(selectedThemeMode);
    }
  }

  /// Opens the platform-adaptive selection modal to choose the map download mode.
  Future _openMapDownloadModeSelectorAsync(
    BuildContext context,
    MapDownloadMode currentMode,
    AppLocalizations l10n,
  ) async {
    final List<NaSelectionItem<MapDownloadMode>> modeItemList = [
      NaSelectionItem<MapDownloadMode>(
        value     : MapDownloadMode.byRegion,
        title     : Text(l10n.settingsMapModeByRegionTitle),
        subtitle  : Text(l10n.settingsMapModeByRegionDesc),
        isSelected: currentMode == MapDownloadMode.byRegion,
      ),
      NaSelectionItem<MapDownloadMode>(
        value     : MapDownloadMode.circleArea,
        title     : Text(l10n.settingsMapModeCircleAreaTitle),
        subtitle  : Text(l10n.settingsMapModeCircleAreaDesc),
        isSelected: currentMode == MapDownloadMode.circleArea,
      ),
      NaSelectionItem<MapDownloadMode>(
        value     : MapDownloadMode.routeCorridor,
        title     : Text(l10n.settingsMapModeRouteCorridorTitle),
        subtitle  : Text(l10n.settingsMapModeRouteCorridorDesc),
        isSelected: currentMode == MapDownloadMode.routeCorridor,
      ),
    ];

    final MapDownloadMode? selectedMode = await naShowSelectionModalAsync<MapDownloadMode>(
      context     : context,
      title       : Text(l10n.settingsMapDownloadModeSelect),
      cancelButton: Text(l10n.commonCancel),
      itemList    : modeItemList,
    );

    if (selectedMode != null) {
      await SettingsService().updateMapDownloadModeAsync(selectedMode);
      if (context.mounted) {
        if (selectedMode == MapDownloadMode.byRegion) {
          Navigator.of(context).push(
            NaPageRoute.create(
              context,
              builder: (BuildContext pageContext) => const MapDownloadPage(),
            ),
          );
        }else if (selectedMode == MapDownloadMode.circleArea) {
          Navigator.of(context).push(
            NaPageRoute.create(
              context,
              builder: (BuildContext pageContext) => const CircleDownloadPage(),
            ),
          );
        }
      }
    }
  }

  /// Opens the selection modal to pick a Map Server preset or enter a custom URL.
  Future _openMapServerUrlSelectorAsync(
    BuildContext context,
    String currentUrl,
    AppLocalizations l10n,
  ) async {
    final bool isCustom = (currentUrl != _serverLocalhost) &&
        (currentUrl != _serverAndroidEmulator) &&
        (currentUrl != _serverLan) &&
        (currentUrl != _serverProduction);

    final List<NaSelectionItem<String>> serverItemList = [
      NaSelectionItem<String>(
        value     : _serverLocalhost,
        title     : Text(l10n.settingsMapServerLocalhost),
        subtitle  : Text(l10n.settingsMapServerLocalhostDesc),
        isSelected: currentUrl == _serverLocalhost,
      ),
      NaSelectionItem<String>(
        value     : _serverAndroidEmulator,
        title     : Text(l10n.settingsMapServerAndroidEmulator),
        subtitle  : Text(l10n.settingsMapServerAndroidEmulatorDesc),
        isSelected: currentUrl == _serverAndroidEmulator,
      ),
      NaSelectionItem<String>(
        value     : _serverLan,
        title     : Text(l10n.settingsMapServerLan),
        subtitle  : Text(l10n.settingsMapServerLanDesc),
        isSelected: currentUrl == _serverLan,
      ),
      NaSelectionItem<String>(
        value     : _serverProduction,
        title     : Text(l10n.settingsMapServerProduction),
        subtitle  : Text(l10n.settingsMapServerProductionDesc),
        isSelected: currentUrl == _serverProduction,
      ),
      NaSelectionItem<String>(
        value     : _serverCustomChoice,
        title     : Text(l10n.settingsMapServerCustom),
        subtitle  : Text(isCustom ? currentUrl : l10n.settingsMapServerCustomDesc),
        isSelected: isCustom,
      ),
    ];

    final String? selectedValue = await naShowSelectionModalAsync<String>(
      context     : context,
      title       : Text(l10n.settingsMapServerUrlDialogTitle),
      cancelButton: Text(l10n.commonCancel),
      itemList    : serverItemList,
    );

    if (selectedValue == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    if (selectedValue == _serverCustomChoice) {
      await _openCustomServerUrlInputDialogAsync(context, currentUrl, l10n);
    }else {
      await SettingsService().updateMapServerUrlAsync(selectedValue);
    }
  }

  /// Opens the dialog to manually enter a custom Map Server Web API URL.
  Future _openCustomServerUrlInputDialogAsync(
    BuildContext context,
    String currentUrl,
    AppLocalizations l10n,
  ) async {
    final TextEditingController urlController = TextEditingController(text: currentUrl)
      ..selection = TextSelection(baseOffset: 0, extentOffset: currentUrl.length)
    ;

    final bool? confirmed = await naShowDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return NaAlertDialog(
          title  : Text(l10n.settingsMapServerUrlDialogTitle),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.p8),
              child  : Column(
                mainAxisSize      : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children          : [
                  // Description
                  Text(
                    l10n.settingsMapServerCustomDesc,
                    style: TextStyle(
                      fontSize: AppSizes.font12,
                      color   : AppColors.textSecondary(dialogContext),
                    ),
                  ),
                  const SizedBox(height: AppSizes.p12),

                  // Server URL text field
                  NaTextField(
                    controller     : urlController,
                    keyboardType   : TextInputType.url,
                    textInputAction: TextInputAction.done,
                    autofocus      : true,
                    onSubmitted    : (String _) => Navigator.of(dialogContext).pop(true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            NaDialogAction(
              child    : Text(l10n.commonCancel),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            NaDialogAction(
              child    : Text(l10n.commonSave),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if ((confirmed == true) && urlController.text.trim().isNotEmpty) {
      await SettingsService().updateMapServerUrlAsync(urlController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n           = AppLocalizations.of(context)!;
    final SettingsService settingsService = SettingsService();

    return ListenableBuilder(
      listenable: settingsService,
      builder   : (BuildContext context, Widget? child) {
        final String? currentLanguageCode         = settingsService.languageCode;
        final ThemeMode currentThemeMode          = settingsService.themeMode;
        final MapDownloadMode currentDownloadMode = settingsService.mapDownloadMode;
        final NaIconData themeIcon                = (currentThemeMode == ThemeMode.dark) ? NaIcons.nightlightRound : NaIcons.wbSunny;

        return Container(
          width : double.infinity,
          height: double.infinity,
          color : AppColors.background(context),
          child : ListView(
            padding : const EdgeInsets.all(AppSizes.p16),
            children: [
              // -------------------------------------------------------------
              // General section header
              // -------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.only(
                  left  : AppSizes.p8,
                  bottom: AppSizes.p8,
                ),
                child: Text(
                  l10n.settingsGeneralSection,
                  style: TextStyle(
                    fontSize  : AppSizes.font14,
                    fontWeight: FontWeight.bold,
                    color     : AppColors.textSecondary(context),
                  ),
                ),
              ),

              // General settings card
              NaCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children    : [
                    // Language selector tile
                    NaListTile(
                      leading : const NaIcon(NaIcons.public),
                      title   : Text(l10n.settingsLanguage),
                      trailing: Text(
                        _getLanguageLabel(currentLanguageCode, l10n),
                        style: TextStyle(
                          fontSize: AppSizes.font14,
                          color   : AppColors.textSecondary(context),
                        ),
                      ),
                      hasChevron: true,
                      onTap     : () => _openLanguageSelectorAsync(
                        context,
                        currentLanguageCode,
                        l10n,
                      ),
                    ),

                    // Theme selector tile
                    NaListTile(
                      leading : NaIcon(themeIcon),
                      title   : Text(l10n.settingsTheme),
                      trailing: Text(
                        _getThemeModeLabel(currentThemeMode, l10n),
                        style: TextStyle(
                          fontSize: AppSizes.font14,
                          color   : AppColors.textSecondary(context),
                        ),
                      ),
                      hasChevron: true,
                      onTap     : () => _openThemeSelectorAsync(
                        context,
                        currentThemeMode,
                        l10n,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.p20),

              // -------------------------------------------------------------
              // Maps & Offline Downloads section header
              // -------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.only(
                  left  : AppSizes.p8,
                  bottom: AppSizes.p8,
                ),
                child: Text(
                  l10n.settingsMapsSection,
                  style: TextStyle(
                    fontSize  : AppSizes.font14,
                    fontWeight: FontWeight.bold,
                    color     : AppColors.textSecondary(context),
                  ),
                ),
              ),

              // Maps configuration card
              NaCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children    : [
                    // Offline Maps Download Hub navigation tile
                    NaListTile(
                      leading : const NaIcon(NaIcons.cloudDownload),
                      title   : Text(l10n.settingsMapDownloadManagerTitle),
                      subtitle: Text(
                        l10n.settingsMapDownloadManagerDesc,
                        style: TextStyle(
                          fontSize: AppSizes.font12,
                          color   : AppColors.textSecondary(context),
                        ),
                      ),
                      hasChevron: true,
                      onTap     : () {
                        Navigator.of(context).push(
                          NaPageRoute.create(
                            context,
                            builder: (BuildContext pageContext) => const MapDownloadPage(),
                          ),
                        );
                      },
                    ),

                    // Download mode selector tile
                    NaListTile(
                      leading : const NaIcon(NaIcons.tune),
                      title   : Text(l10n.settingsMapDownloadMode),
                      trailing: Text(
                        _getMapDownloadModeTitle(currentDownloadMode, l10n),
                        style: TextStyle(
                          fontSize: AppSizes.font14,
                          color   : AppColors.textSecondary(context),
                        ),
                      ),
                      hasChevron: true,
                      onTap     : () => _openMapDownloadModeSelectorAsync(
                        context,
                        currentDownloadMode,
                        l10n,
                      ),
                    ),

                    // Dedicated "Cerchia e scarica" page navigation tile
                    NaListTile(
                      leading : const NaIcon(NaIcons.brush),
                      title   : Text(l10n.settingsMapCircleDownloadAction),
                      subtitle: Text(
                        l10n.settingsMapCircleDownloadDesc,
                        style: TextStyle(
                          fontSize: AppSizes.font12,
                          color   : AppColors.textSecondary(context),
                        ),
                      ),
                      hasChevron: true,
                      onTap     : () {
                        Navigator.of(context).push(
                          NaPageRoute.create(
                            context,
                            builder: (BuildContext pageContext) => const CircleDownloadPage(),
                          ),
                        );
                      },
                    ),

                    // Wi-Fi only download toggle tile
                    NaListTile(
                      leading : const NaIcon(NaIcons.wifi),
                      title   : Text(l10n.settingsMapWifiOnlyTitle),
                      subtitle: Text(
                        l10n.settingsMapWifiOnlyDesc,
                        style: TextStyle(
                          fontSize: AppSizes.font12,
                          color   : AppColors.textSecondary(context),
                        ),
                      ),
                      trailing: NaSwitch(
                        value    : settingsService.downloadWifiOnly,
                        onChanged: (bool value) => settingsService.updateDownloadWifiOnlyAsync(value),
                      ),
                    ),

                    // Map Server Web API URL configuration tile
                    NaListTile(
                      leading : const NaIcon(NaIcons.public),
                      title   : Text(l10n.settingsMapServerUrlTitle),
                      subtitle: Text(
                        l10n.settingsMapServerUrlDesc,
                        style: TextStyle(
                          fontSize: AppSizes.font12,
                          color   : AppColors.textSecondary(context),
                        ),
                      ),
                      trailing: Text(
                        _getMapServerLabel(settingsService.mapServerUrl),
                        style: TextStyle(
                          fontSize: AppSizes.font14,
                          color   : AppColors.textSecondary(context),
                        ),
                      ),
                      hasChevron: true,
                      onTap     : () => _openMapServerUrlSelectorAsync(
                        context,
                        settingsService.mapServerUrl,
                        l10n,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.p20),

              // -------------------------------------------------------------
              // Additional Detail Layers section header
              // -------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.only(
                  left  : AppSizes.p8,
                  bottom: AppSizes.p8,
                ),
                child: Text(
                  l10n.settingsMapLayersSection,
                  style: TextStyle(
                    fontSize  : AppSizes.font14,
                    fontWeight: FontWeight.bold,
                    color     : AppColors.textSecondary(context),
                  ),
                ),
              ),

              // Additional Detail Layers card
              NaCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children    : [
                    // 3D Buildings layer toggle tile
                    NaListTile(
                      leading : const NaIcon(NaIcons.layers),
                      title   : Text(l10n.settingsMapLayerBuildingsTitle),
                      subtitle: Text(
                        l10n.settingsMapLayerBuildingsDesc,
                        style: TextStyle(
                          fontSize: AppSizes.font12,
                          color   : AppColors.textSecondary(context),
                        ),
                      ),
                      trailing: NaSwitch(
                        value    : settingsService.includeBuildings3d,
                        onChanged: (bool value) => settingsService.updateIncludeBuildings3dAsync(value),
                      ),
                    ),

                    // Pedestrian / Soft Mobility layer toggle tile
                    NaListTile(
                      leading : const NaIcon(NaIcons.directionsWalk),
                      title   : Text(l10n.settingsMapLayerPedestrianTitle),
                      subtitle: Text(
                        l10n.settingsMapLayerPedestrianDesc,
                        style: TextStyle(
                          fontSize: AppSizes.font12,
                          color   : AppColors.textSecondary(context),
                        ),
                      ),
                      trailing: NaSwitch(
                        value    : settingsService.includePedestrian,
                        onChanged: (bool value) => settingsService.updateIncludePedestrianAsync(value),
                      ),
                    ),

                    // HD Terrain elevation layer toggle tile
                    NaListTile(
                      leading : const NaIcon(NaIcons.terrain),
                      title   : Text(l10n.settingsMapLayerTerrainTitle),
                      subtitle: Text(
                        l10n.settingsMapLayerTerrainDesc,
                        style: TextStyle(
                          fontSize: AppSizes.font12,
                          color   : AppColors.textSecondary(context),
                        ),
                      ),
                      trailing: NaSwitch(
                        value    : settingsService.includeTerrainHd,
                        onChanged: (bool value) => settingsService.updateIncludeTerrainHdAsync(value),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
