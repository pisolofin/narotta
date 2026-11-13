import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings-service.dart';
import '../../../widgets/app-divider.widget.dart';
import '../../../services/map-download-service.dart';
import '../../../models/map-display-style.model.dart';

import '../../map-download/map-download.page.dart';

/// Displays the application settings view with general preferences and streamlined map download options.
class Settings extends StatelessWidget {
  static const String _systemLanguageValue  = 'system';
  static const String _italianLanguageValue = 'it';
  static const String _englishLanguageValue = 'en';

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

  /// Opens the platform-adaptive selection modal to choose the map visualization style.
  Future _openMapStyleSelectorAsync(
    BuildContext context,
    MapDisplayStyle currentStyle,
    AppLocalizations l10n,
  ) async {
    final List<NaSelectionItem<MapDisplayStyle>> styleItemList = [
      NaSelectionItem<MapDisplayStyle>(
        value     : MapDisplayStyle.tactical,
        title     : Text(MapDisplayStyle.tactical.getTitle(l10n)),
        subtitle  : Text(MapDisplayStyle.tactical.getDescription(l10n)),
        isSelected: currentStyle == MapDisplayStyle.tactical,
      ),
    ];

    final MapDisplayStyle? selectedStyle = await naShowSelectionModalAsync<MapDisplayStyle>(
      context     : context,
      title       : Text(l10n.settingsMapStyleSelect),
      cancelButton: Text(l10n.commonCancel),
      itemList    : styleItemList,
    );

    if (selectedStyle != null) {
      await SettingsService().updateMapDisplayStyleAsync(selectedStyle);
    }
  }

  /// Opens file picker to select a custom directory for offline map storage.
  Future _selectCustomMapsFolderAsync(BuildContext context) async {
    final String? selectedDirectory = await FilePicker.getDirectoryPath();
    if ((selectedDirectory != null) && selectedDirectory.trim().isNotEmpty) {
      await SettingsService().updateCustomMapsDirectoryAsync(selectedDirectory.trim());
      await MapDownloadService().initAsync();
    }
  }

  /// Resets the custom maps directory to the platform default storage directory.
  Future _resetMapsFolderAsync(BuildContext context) async {
    await SettingsService().updateCustomMapsDirectoryAsync(null);
    await MapDownloadService().initAsync();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n           = AppLocalizations.of(context)!;
    final SettingsService settingsService = SettingsService();

    return ListenableBuilder(
      listenable: settingsService,
      builder   : (BuildContext context, Widget? child) {
        final String? currentLanguageCode = settingsService.languageCode;
        final ThemeMode currentThemeMode  = settingsService.themeMode;
        final NaIconData themeIcon        = (currentThemeMode == ThemeMode.dark) ? NaIcons.nightlightRound : NaIcons.wbSunny;

        return Container(
          width : double.infinity,
          height: double.infinity,
          color : AppColors.background(context),
          child : ListView(
            padding : const EdgeInsets.all(AppSizes.p16),
            children: [
              // General section header
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

                    // Hairline divider between Language and Theme
                    const AppDivider(),

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

              // Section vertical spacing
              const SizedBox(height: AppSizes.p20),

              // Maps and downloads section header
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

              // Maps and downloads card (only Download maps & Wi-Fi only)
              NaCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children    : [
                    // Download maps navigation tile
                    NaListTile(
                      leading   : const NaIcon(NaIcons.cloudDownload),
                      title     : Text(l10n.settingsDownloadMapsTitle),
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

                    // Hairline divider between Download maps and Map style
                    const AppDivider(),

                    // Map visualization style selector tile
                    NaListTile(
                      leading : const NaIcon(NaIcons.layers),
                      title   : Text(l10n.settingsMapStyleTitle),
                      trailing: Text(
                        settingsService.mapDisplayStyle.getTitle(l10n),
                        style: TextStyle(
                          fontSize: AppSizes.font14,
                          color   : AppColors.textSecondary(context),
                        ),
                      ),
                      hasChevron: true,
                      onTap     : () => _openMapStyleSelectorAsync(
                        context,
                        settingsService.mapDisplayStyle,
                        l10n,
                      ),
                    ),

                    if (defaultTargetPlatform == TargetPlatform.windows) ...[
                      // Hairline divider between Map style and Windows storage folder
                      const AppDivider(),

                      // Windows map storage folder tile
                      FutureBuilder(
                        future : MapDownloadService.getMapsDirectoryAsync(),
                        builder: (BuildContext tileContext, AsyncSnapshot snapshot) {
                          final String currentFolderPath = snapshot.hasData
                            ? snapshot.data!.path
                            : (settingsService.customMapsDirectory ?? '...')
                          ;
                          final bool isCustom = settingsService.customMapsDirectory != null;

                          return NaListTile(
                            leading : const NaIcon(NaIcons.folder),
                            title   : Text(l10n.settingsMapStorageFolderTitle),
                            subtitle: Text(
                              currentFolderPath,
                              style: TextStyle(
                                fontSize: AppSizes.font12,
                                color   : AppColors.textSecondary(tileContext),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children    : [
                                if (isCustom) ...[
                                  // Button to reset to default folder
                                  NaIconButton(
                                    icon: const NaIcon(
                                      NaIcons.refresh,
                                      size: AppSizes.icon18,
                                    ),
                                    onPressed: () => _resetMapsFolderAsync(context),
                                  ),
                                  // Spacing
                                  const SizedBox(width: AppSizes.p4),
                                ],
                                // Button to choose a folder via picker
                                NaButtonFilled(
                                  onPressed: () => _selectCustomMapsFolderAsync(context),
                                  child    : Text(l10n.settingsMapStorageFolderChange),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    // Hairline divider between Map style and Wi-Fi only
                    const AppDivider(),

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
