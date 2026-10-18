import 'package:flutter/material.dart';
import 'package:nanna_platform/nanna_platform.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/settings-service.dart';

/// Displays the application settings view with language and theme configuration.
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
            ],
          ),
        );
      },
    );
  }
}
