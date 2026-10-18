import 'package:nanna/nanna.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import 'app.dart';
import 'services/settings-service.dart';

/// Application entry point.
Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NaPreferences.initAsync();
  await SettingsService().initAsync();

  const String envUiStyle = String.fromEnvironment('UI_STYLE');
  if ((envUiStyle == 'cupertino') || (envUiStyle == 'ios')) {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  }else if ((envUiStyle == 'material') || (envUiStyle == 'android')) {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  }

  runApp(const NaRottaApp());
}
