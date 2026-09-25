import 'package:flutter/material.dart';

class CategorySeedData {
  final String name;
  final String type; // 'income' | 'expense'
  final String icon;
  final int colorValue;
  final bool isDefault;

  const CategorySeedData({
    required this.name,
    required this.type,
    required this.icon,
    required this.colorValue,
    this.isDefault = true,
  });
}

class DefaultCategories {
  static const List<CategorySeedData> expenseCategories = [
    CategorySeedData(
      name: 'Food & Dining',
      type: 'expense',
      icon: 'restaurant',
      colorValue: 0xFFDE5B6D, // Matte Terracotta Rose
    ),
    CategorySeedData(
      name: 'Groceries',
      type: 'expense',
      icon: 'shopping_cart',
      colorValue: 0xFFF97316, // Orange
    ),
    CategorySeedData(
      name: 'Shopping',
      type: 'expense',
      icon: 'shopping_bag',
      colorValue: 0xFFF59E0B, // Amber
    ),
    CategorySeedData(
      name: 'Transportation',
      type: 'expense',
      icon: 'directions_car',
      colorValue: 0xFF06B6D4, // Cyan
    ),
    CategorySeedData(
      name: 'Housing & Rent',
      type: 'expense',
      icon: 'home',
      colorValue: 0xFF6366F1, // Indigo
    ),
    CategorySeedData(
      name: 'Bills & Utilities',
      type: 'expense',
      icon: 'bolt',
      colorValue: 0xFF3B82F6, // Blue
    ),
    CategorySeedData(
      name: 'Entertainment',
      type: 'expense',
      icon: 'movie',
      colorValue: 0xFF8B5CF6, // Purple
    ),
    CategorySeedData(
      name: 'Health & Medical',
      type: 'expense',
      icon: 'local_hospital',
      colorValue: 0xFFEC4899, // Pink
    ),
    CategorySeedData(
      name: 'Education',
      type: 'expense',
      icon: 'school',
      colorValue: 0xFF14B8A6, // Teal
    ),
    CategorySeedData(
      name: 'Personal Care',
      type: 'expense',
      icon: 'face',
      colorValue: 0xFFA855F7, // Violet
    ),
    CategorySeedData(
      name: 'Travel & Vacation',
      type: 'expense',
      icon: 'flight',
      colorValue: 0xFF38BDF8, // Light Blue
    ),
    CategorySeedData(
      name: 'Other Expense',
      type: 'expense',
      icon: 'category',
      colorValue: 0xFF64748B, // Slate
    ),
  ];

  static const List<CategorySeedData> incomeCategories = [
    CategorySeedData(
      name: 'Salary',
      type: 'income',
      icon: 'account_balance_wallet',
      colorValue: 0xFF10B981, // Emerald Green
    ),
    CategorySeedData(
      name: 'Freelance & Projects',
      type: 'income',
      icon: 'laptop_mac',
      colorValue: 0xFF059669, // Dark Green
    ),
    CategorySeedData(
      name: 'Investments & Dividends',
      type: 'income',
      icon: 'trending_up',
      colorValue: 0xFF84CC16, // Lime
    ),
    CategorySeedData(
      name: 'Gifts & Grants',
      type: 'income',
      icon: 'card_giftcard',
      colorValue: 0xFFF59E0B, // Amber
    ),
    CategorySeedData(
      name: 'Rental Income',
      type: 'income',
      icon: 'apartment',
      colorValue: 0xFF6366F1, // Indigo
    ),
    CategorySeedData(
      name: 'Other Income',
      type: 'income',
      icon: 'attach_money',
      colorValue: 0xFF34D399, // Light Green
    ),
  ];

  // Default accounts to pre-seed
  static const List<Map<String, dynamic>> defaultAccounts = [
    {
      'name': 'Cash',
      'type': 'cash',
      'initial_balance_cents': 0,
      'currency': 'USD',
      'icon': 'payments',
    },
    {
      'name': 'Main Checking Bank',
      'type': 'bank',
      'initial_balance_cents': 0,
      'currency': 'USD',
      'icon': 'account_balance',
    },
    {
      'name': 'Mobile Banking / Wallet',
      'type': 'mobile_banking',
      'initial_balance_cents': 0,
      'currency': 'USD',
      'icon': 'phone_android',
    },
    {
      'name': 'Credit Card',
      'type': 'card',
      'initial_balance_cents': 0,
      'currency': 'USD',
      'icon': 'credit_card',
    },
  ];

  // Default merchant / keyword auto-categorization rules
  static const Map<String, String> defaultMerchantKeywordMapping = {
    // Food & Dining
    'starbucks': 'Food & Dining',
    'coffee': 'Food & Dining',
    'cafe': 'Food & Dining',
    'kfc': 'Food & Dining',
    'mcdonald': 'Food & Dining',
    'burger': 'Food & Dining',
    'pizza': 'Food & Dining',
    'restaurant': 'Food & Dining',
    'lunch': 'Food & Dining',
    'dinner': 'Food & Dining',
    'breakfast': 'Food & Dining',
    'subway': 'Food & Dining',
    'ubereats': 'Food & Dining',
    'foodpanda': 'Food & Dining',
    'doordash': 'Food & Dining',
    'swiggy': 'Food & Dining',
    'zomato': 'Food & Dining',

    // Groceries
    'walmart': 'Groceries',
    'supermarket': 'Groceries',
    'grocery': 'Groceries',
    'market': 'Groceries',
    'target': 'Groceries',
    'costco': 'Groceries',
    'trader joe': 'Groceries',
    'shwapno': 'Groceries',
    'agora': 'Groceries',
    'meenaclick': 'Groceries',

    // Transport
    'uber': 'Transportation',
    'pathao': 'Transportation',
    'lyft': 'Transportation',
    'taxi': 'Transportation',
    'gas': 'Transportation',
    'fuel': 'Transportation',
    'petrol': 'Transportation',
    'subway pass': 'Transportation',
    'bus ticket': 'Transportation',
    'train': 'Transportation',
    'parking': 'Transportation',

    // Housing & Rent
    'rent': 'Housing & Rent',
    'landlord': 'Housing & Rent',
    'mortgage': 'Housing & Rent',

    // Bills & Utilities
    'electric': 'Bills & Utilities',
    'electricity': 'Bills & Utilities',
    'water bill': 'Bills & Utilities',
    'internet': 'Bills & Utilities',
    'wifi': 'Bills & Utilities',
    'phone bill': 'Bills & Utilities',
    'desco': 'Bills & Utilities',
    'wasa': 'Bills & Utilities',

    // Entertainment & Subscriptions
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'youtube': 'Entertainment',
    'cinema': 'Entertainment',
    'movie': 'Entertainment',
    'steam': 'Entertainment',
    'playstation': 'Entertainment',
    'disney': 'Entertainment',

    // Shopping
    'amazon': 'Shopping',
    'ebay': 'Shopping',
    'aliexpress': 'Shopping',
    'daraz': 'Shopping',
    'clothes': 'Shopping',
    'shoes': 'Shopping',
    'zara': 'Shopping',
    'h&m': 'Shopping',

    // Health
    'pharmacy': 'Health & Medical',
    'medicine': 'Health & Medical',
    'doctor': 'Health & Medical',
    'hospital': 'Health & Medical',
    'dentist': 'Health & Medical',
    'cvs': 'Health & Medical',

    // Income
    'salary': 'Salary',
    'payroll': 'Salary',
    'upwork': 'Freelance & Projects',
    'fiverr': 'Freelance & Projects',
    'freelance': 'Freelance & Projects',
    'dividend': 'Investments & Dividends',
  };
}

class IconHelper {
  static const Map<String, IconData> iconMap = {
    'restaurant': Icons.restaurant_outlined,
    'shopping_cart': Icons.shopping_cart_outlined,
    'shopping_bag': Icons.shopping_bag_outlined,
    'directions_car': Icons.directions_car_outlined,
    'home': Icons.home_outlined,
    'bolt': Icons.bolt_rounded,
    'movie': Icons.movie_outlined,
    'local_hospital': Icons.local_hospital_outlined,
    'school': Icons.school_outlined,
    'face': Icons.face_outlined,
    'flight': Icons.flight_outlined,
    'category': Icons.category_outlined,
    'account_balance_wallet': Icons.account_balance_wallet_outlined,
    'laptop_mac': Icons.laptop_mac_outlined,
    'trending_up': Icons.trending_up_rounded,
    'card_giftcard': Icons.card_giftcard_outlined,
    'apartment': Icons.apartment_outlined,
    'attach_money': Icons.attach_money_rounded,
    'payments': Icons.payments_outlined,
    'account_balance': Icons.account_balance_outlined,
    'phone_android': Icons.phone_android_outlined,
    'credit_card': Icons.credit_card_outlined,
    'savings': Icons.savings_outlined,
    'pets': Icons.pets_outlined,
    'fitness_center': Icons.fitness_center_rounded,
    'receipt_long': Icons.receipt_long_outlined,
    'coffee': Icons.coffee_outlined,
    'local_bar': Icons.local_bar_outlined,
    'local_gas_station': Icons.local_gas_station_outlined,
    'card_travel': Icons.card_travel_outlined,
    'redeem': Icons.auto_awesome_outlined,
    'work': Icons.work_outline_rounded,
    'spa': Icons.spa_outlined,
    'sports_esports': Icons.sports_esports_outlined,
    'medical_services': Icons.medical_services_outlined,
    'repeat': Icons.repeat_rounded,
  };

  static IconData getIcon(String? iconName) {
    if (iconName == null) return Icons.category_outlined;
    return iconMap[iconName] ?? Icons.category_outlined;
  }
}

