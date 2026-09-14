enum AppLanguage {
  english,
  german,
}

class AppSettingsModel {
  final AppLanguage language;
  final String currencyCode;

  const AppSettingsModel({
    required this.language,
    required this.currencyCode,
  });

  AppSettingsModel copyWith({
    AppLanguage? language,
    String? currencyCode,
  }) {
    return AppSettingsModel(
      language: language ?? this.language,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}
