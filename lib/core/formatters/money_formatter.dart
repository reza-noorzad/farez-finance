import '../../features/settings/app_settings_mock_data.dart';

class MoneyFormatter {
  static String get currencyCode {
    return AppSettingsMockData.settings.currencyCode;
  }

  static String get symbol {
    switch (currencyCode) {
      case 'USD':
        return r'$';
      case 'GBP':
        return '£';
      case 'CHF':
        return 'CHF';
      case 'TRY':
        return '₺';
      case 'IRR':
        return 'IRR';
      case 'EUR':
      default:
        return '€';
    }
  }

  static String format(double amount) {
    final value = amount.toStringAsFixed(2);

    if (currencyCode == 'CHF' || currencyCode == 'IRR') {
      return '$value $symbol';
    }

    return '$symbol$value';
  }
}
