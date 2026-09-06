import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

class CurrencyNotifier extends StateNotifier<CurrencyInfo> {
  CurrencyNotifier()
      : super(const CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar')) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(AppConstants.prefCurrencyCode) ?? 'USD';
    final currency = AppConstants.supportedCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => AppConstants.supportedCurrencies.first,
    );
    state = currency;
  }

  Future<void> setCurrency(CurrencyInfo currency) async {
    state = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefCurrencyCode, currency.code);
    await prefs.setString(AppConstants.prefCurrencySymbol, currency.symbol);
  }
}

final currencyProvider = StateNotifierProvider<CurrencyNotifier, CurrencyInfo>((ref) {
  return CurrencyNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(AppConstants.prefThemeMode) ?? 'dark';
    if (modeStr == 'light') {
      state = ThemeMode.light;
    } else if (modeStr == 'system') {
      state = ThemeMode.system;
    } else {
      state = ThemeMode.dark;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final modeStr = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.system
            ? 'system'
            : 'dark';
    await prefs.setString(AppConstants.prefThemeMode, modeStr);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

final budgetAlertThresholdProvider = StateProvider<double>((ref) => 0.80);

