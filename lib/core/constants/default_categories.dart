import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    'restaurant': LucideIcons.utensils,
    'shopping_cart': LucideIcons.shoppingCart,
    'shopping_bag': LucideIcons.shoppingBag,
    'directions_car': LucideIcons.car,
    'home': LucideIcons.house,
    'bolt': LucideIcons.zap,
    'movie': LucideIcons.film,
    'local_hospital': LucideIcons.heartPulse,
    'school': LucideIcons.graduationCap,
    'face': LucideIcons.smile,
    'flight': LucideIcons.plane,
    'category': LucideIcons.shapes,
    'account_balance_wallet': LucideIcons.wallet,
    'laptop_mac': LucideIcons.laptop,
    'trending_up': LucideIcons.trendingUp,
    'card_giftcard': LucideIcons.gift,
    'apartment': LucideIcons.building2,
    'attach_money': LucideIcons.dollarSign,
    'payments': LucideIcons.banknote,
    'account_balance': LucideIcons.landmark,
    'phone_android': LucideIcons.smartphone,
    'credit_card': LucideIcons.creditCard,
    'savings': LucideIcons.piggyBank,
    'pets': LucideIcons.dog,
    'fitness_center': LucideIcons.dumbbell,
    'receipt_long': LucideIcons.receipt,
    'coffee': LucideIcons.coffee,
    'local_bar': LucideIcons.wine,
    'local_gas_station': LucideIcons.fuel,
    'card_travel': LucideIcons.briefcase,
    'redeem': LucideIcons.sparkles,
    'work': LucideIcons.briefcase,
    'spa': LucideIcons.flower,
    'sports_esports': LucideIcons.gamepad2,
    'medical_services': LucideIcons.stethoscope,
  };

  static IconData getIcon(String? iconName) {
    if (iconName == null) return LucideIcons.shapes;
    return iconMap[iconName] ?? LucideIcons.shapes;
  }
}

