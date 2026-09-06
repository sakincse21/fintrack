import 'package:intl/intl.dart';

class CurrencyFormatter {
  /// Converts integer cents to formatted currency string
  /// Example: 125000 cents -> "$1,250.00"
  static String formatCents(
    int cents, {
    String symbol = '\$',
    bool showDecimals = true,
    bool showSign = false,
  }) {
    final double amount = cents / 100.0;
    final isNegative = amount < 0;
    final absAmount = amount.abs();

    final NumberFormat format = showDecimals
        ? NumberFormat.currency(symbol: symbol, decimalDigits: 2)
        : NumberFormat.currency(symbol: symbol, decimalDigits: 0);

    final formatted = format.format(absAmount);

    if (showSign) {
      if (isNegative) {
        return '-$formatted';
      } else if (cents > 0) {
        return '+$formatted';
      }
    } else if (isNegative) {
      return '-$formatted';
    }

    return formatted;
  }

  /// Compact format for charts and small headers (e.g., $1.2K, $3.5M)
  static String formatCompact(int cents, {String symbol = '\$'}) {
    final double amount = cents / 100.0;
    final isNegative = amount < 0;
    final abs = amount.abs();

    String result;
    if (abs >= 1000000) {
      result = '$symbol${(abs / 1000000).toStringAsFixed(1)}M';
    } else if (abs >= 1000) {
      result = '$symbol${(abs / 1000).toStringAsFixed(1)}K';
    } else {
      result = '$symbol${abs.toStringAsFixed(0)}';
    }

    return isNegative ? '-$result' : result;
  }

  /// Parse user input string (e.g., "12.50", "200", "1,250.00") into integer cents
  static int? parseAmountToCents(String input) {
    if (input.trim().isEmpty) return null;
    final sanitized = input
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .trim();
    if (sanitized.isEmpty) return null;

    final doubleVal = double.tryParse(sanitized);
    if (doubleVal == null) return null;

    return (doubleVal * 100).round();
  }
}

