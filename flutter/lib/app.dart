import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:nanna_platform/nanna_platform.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'constants/app-theme.dart';
import 'pages/home/home.page.dart';
import 'l10n/app_localizations.dart';
import 'services/settings-service.dart';

/// Root widget of the NaRotta application.
///
/// Automatically configures the Nanna UI style (`NaUiType.cupertino` on iOS/macOS,
/// `NaUiType.material` on Android and other platforms) and listens to [SettingsService]
/// for dynamic language and theme changes.
class NaRottaApp extends StatelessWidget {
  const NaRottaApp({ super.key });

  /// Resolves the appropriate [NaUiType] for the current operating system.
  NaUiType _resolvePlatformUiType() {
    const String envUiStyle = String.fromEnvironment('UI_STYLE');
    if ((envUiStyle == 'cupertino') || (envUiStyle == 'ios')) {
      return NaUiType.cupertino;
    }
    if ((envUiStyle == 'material') || (envUiStyle == 'android')) {
      return NaUiType.material;
    }

    if ((defaultTargetPlatform == TargetPlatform.iOS) || (defaultTargetPlatform == TargetPlatform.macOS)) {
      return NaUiType.cupertino;
    }
    return NaUiType.material;
  }

  @override
  Widget build(BuildContext context) {
    final NaUiType currentUiType          = _resolvePlatformUiType();
    final SettingsService settingsService = SettingsService();

    return ListenableBuilder(
      listenable: settingsService,
      builder   : (BuildContext context, Widget? child) {
        final Brightness? forcedBrightness = settingsService.forcedBrightness;

        return NaUiTypeScope(
          uiTypes: [currentUiType],
          child  : NaApp(
            locale                : settingsService.locale,
            onGenerateTitle       : (BuildContext context) => AppLocalizations.of(context)!.commonAppTitle,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('it'),
              Locale('en'),
            ],
            optionsBuilder: (BuildContext context, NaUiType uiType) {
              if (uiType == NaUiType.cupertino) {
                return NaAppOptionsCupertino(
                  theme: AppTheme.cupertinoTheme(context, brightness: forcedBrightness),
                );
              }
              return NaAppOptionsMaterial(
                theme    : AppTheme.materialTheme(context, brightness: Brightness.light),
                darkTheme: AppTheme.materialTheme(context, brightness: Brightness.dark),
                themeMode: settingsService.themeMode,
              );
            },
            home: const HomePage(),
          ),
        );
      },
    );
  }
}
