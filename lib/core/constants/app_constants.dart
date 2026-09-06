class AppConstants {
  static const String appName = 'FinTrack';
  static const String appTagline = 'Fast input, maximum insight';
  static const String appVersion = '1.0.0';

  // Default Preferences Keys
  static const String prefCurrencyCode = 'pref_currency_code';
  static const String prefCurrencySymbol = 'pref_currency_symbol';
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefBudgetAlertThreshold = 'pref_budget_alert_threshold';
  static const String prefInitialSeedDone = 'pref_initial_seed_done';

  // Currencies
  static const List<CurrencyInfo> supportedCurrencies = [
    CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar'),
    CurrencyInfo(code: 'BDT', symbol: '৳', name: 'Bangladeshi Taka'),
    CurrencyInfo(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    CurrencyInfo(code: 'EUR', symbol: '€', name: 'Euro'),
    CurrencyInfo(code: 'GBP', symbol: '£', name: 'British Pound'),
    CurrencyInfo(code: 'CAD', symbol: 'CA\$', name: 'Canadian Dollar'),
    CurrencyInfo(code: 'AUD', symbol: 'AU\$', name: 'Australian Dollar'),
    CurrencyInfo(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
    CurrencyInfo(code: 'AED', symbol: 'AED', name: 'UAE Dirham'),
    CurrencyInfo(code: 'SAR', symbol: 'SAR', name: 'Saudi Riyal'),
    CurrencyInfo(code: 'SGD', symbol: 'SG\$', name: 'Singapore Dollar'),
  ];
}

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
  });
}

