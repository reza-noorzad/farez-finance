import 'package:flutter/material.dart';

import '../../shared/models/app_settings_model.dart';

class AppSettingsMockData {
  static final ValueNotifier<AppSettingsModel> settingsNotifier =
      ValueNotifier<AppSettingsModel>(
    const AppSettingsModel(
      language: AppLanguage.german,
      currencyCode: 'EUR',
    ),
  );

  static AppSettingsModel get settings {
    return settingsNotifier.value;
  }

  static void updateSettings(AppSettingsModel newSettings) {
    settingsNotifier.value = newSettings;
  }
}
